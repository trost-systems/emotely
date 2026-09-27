import {
  type Answer,
  type AnswerType,
  type AskQuestionInput,
  askQuestionInput,
  completeSessionInput,
  recordAnswerInput,
} from "@emotely/contract";
import {
  generateText,
  isStepCount,
  type JSONValue,
  type LanguageModel,
  type LanguageModelUsage,
  type ModelMessage,
  tool,
} from "ai";
import type { TokenUsage } from "./cost.ts";
import { resolvePrompt } from "./session-prompt.ts";
import { PRIVACY_TELEMETRY } from "./telemetry.ts";
import {
  asAsked,
  type PendingQuestion,
  replayTranscript,
} from "./transcript-replay.ts";

type ListAnswerType = Extract<AnswerType, "color" | "emoji" | "text_list">;
type ScalarAnswerType = Exclude<AnswerType, ListAnswerType>;

// Union on answer_type so min_answers only exists where the value is a list.
export type Question = { id: string; text: string } & (
  | { answer_type: ScalarAnswerType; min_answers?: never }
  | { answer_type: ListAnswerType; min_answers?: number }
);

export type QuestionSet = {
  id: string;
  name: string;
  questions: Question[];
};

/**
 * What the companion may know about the person it talks to (#204), camelCase
 * here and `user_context` on the wire. Every member is optional: an app that
 * knows nothing sends nothing, and later members (a local date, a time zone,
 * a locale) arrive as more optional keys.
 */
export type UserContext = {
  /** The name the user chose, or the placeholder emotely picked for them. */
  displayName?: string;
  /** True when [displayName] is that placeholder, not a real name. */
  nameIsPlaceholder?: boolean;
};

export type SessionClient = {
  /** Answer an ask_question tool call with the raw widget value. */
  askQuestion: (input: AskQuestionInput) => Promise<JSONValue>;
};

export type SessionResult = {
  summary: string;
  answers: Record<string, Answer>;
  /** Token totals across every model round, for cost accounting. */
  usage: TokenUsage;
  /** The full conversation, for eval transcripts and debugging. */
  messages: ModelMessage[];
  /** Version id of the system prompt this session ran with. */
  promptId: string;
  /** Wall-clock ms per model round — what the user waits between widgets. */
  roundLatenciesMs: number[];
};

// ponytail: generous cap — a poweruser recording 20 gratitudes must never hit
// it; tighten with real usage data once PostHog is wired (issue #5).
const MAX_OUTPUT_TOKENS_PER_ROUND = 2000;
const MAX_ROUNDS_PER_QUESTION = 6;
const ROUND_SLACK = 20;

function buildSessionTools(
  questionSet: QuestionSet,
  answers: SessionResult["answers"],
  asked: Set<string>,
  onComplete: (summary: string) => void,
) {
  return {
    ask_question: tool({
      description:
        "Ask the user one journaling question; the client renders the widget.",
      inputSchema: askQuestionInput,
      // no execute: client-side tool — the session loop supplies the result
    }),
    record_answer: tool({
      description: "Record the validated answer for one question.",
      inputSchema: recordAnswerInput,
      execute: async ({ question_id, answer }) => {
        const question = questionSet.questions.find(
          (q) => q.id === question_id,
        );
        const min = question?.min_answers ?? 1;
        if (Array.isArray(answer.value) && answer.value.length < min) {
          return {
            recorded: false,
            error: `This question needs at least ${min} answers.`,
          };
        }
        answers[question_id] = answer;
        return { recorded: true };
      },
    }),
    complete_session: tool({
      description: "Finish the session with a summary of the journal entry.",
      inputSchema: completeSessionInput,
      execute: async ({ summary }) => {
        // Models tend to skip record_answer for the final question; an asked
        // question without a recorded answer is a lost answer, so refuse.
        const unrecorded = [...asked].filter((id) => !(id in answers));
        if (unrecorded.length > 0) {
          return {
            completed: false,
            error: `Record the answer for ${unrecorded.join(", ")} with record_answer before completing.`,
          };
        }
        onComplete(summary);
        return { completed: true };
      },
    }),
  };
}

export function emptyUsage(): TokenUsage {
  return { inputTokens: 0, cacheReadTokens: 0, outputTokens: 0 };
}

function addUsage(total: TokenUsage, step: LanguageModelUsage): void {
  total.inputTokens += step.inputTokens ?? 0;
  total.cacheReadTokens += step.inputTokenDetails.cacheReadTokens ?? 0;
  total.outputTokens += step.outputTokens ?? 0;
}

/** Generous round cap so a model that never completes cannot loop forever. */
function roundGuard(questionSet: QuestionSet): { next: () => void } {
  const maxRounds =
    questionSet.questions.length * MAX_ROUNDS_PER_QUESTION + ROUND_SLACK;
  let rounds = 0;
  return {
    next: () => {
      if (++rounds > maxRounds) {
        throw new Error(
          `Session round limit reached (${maxRounds}) without complete_session.`,
        );
      }
    },
  };
}

const SESSION_TELEMETRY = {
  ...PRIVACY_TELEMETRY,
  includeRuntimeContext: { distinctId: true, sessionId: true, promptId: true },
} as const;

/**
 * A journal transcript is special-category data (GDPR Art. 9: health, emotions,
 * relationships), so it must never become training data. The gateway does not
 * train on prompts itself, but it does not route on the providers' training
 * policies by default, and a provider whose stance is unknown is assumed to
 * train. `disallowPromptTraining` restricts routing to providers that have
 * agreed with Vercel not to train on prompts; without it the privacy notice
 * cannot name a safeguard for the transfer under Art. 13(1)(f).
 *
 * `zeroDataRetention` rides along because it costs us nothing here: measured
 * against the live gateway on 2026-09-15, all eight providers that serve
 * `openai/gpt-oss-120b` (baseten, fireworks, bedrock, togetherai, nebius,
 * parasail, groq, cerebras) satisfy both filters, so neither one narrows the
 * fallback set. It is a real added guarantee — no provider-side retention of
 * the transcript, not merely no training on it.
 *
 * Both filters fail *closed*: the gateway rejects the request outright when no
 * eligible provider exists for the model. So re-measure before changing the
 * default model — a model whose providers do not all qualify would break every
 * session rather than degrade quietly.
 *
 * The keys are typed here rather than imported: `@ai-sdk/gateway` is a
 * transitive dependency of `ai`, not one this package declares.
 *
 * **The spelling of these keys is unguarded.** `GatewayProviderOptions` carries
 * an index signature (`[key: string]: unknown`) so the Gateway can add options
 * without an SDK release — which means a typo like `disallowPromptTrainingg`
 * type-checks, is forwarded to the gateway verbatim, and is silently ignored
 * there. Neither `satisfies GatewayProviderOptions` nor the unit test below
 * would catch it: the test asserts what we send, not what the gateway
 * understood. Only a live round proves the filter was applied — the gateway
 * echoes `enabledZeroDataRetention` and `enabledDisallowPromptTraining` back on
 * `providerMetadata.gateway`. `provider-qualification.ts` reads exactly those,
 * and the monthly benchmark fails a model whose flags come back unconfirmed, so
 * that eval is the real check when editing these keys.
 */
const GATEWAY_PRIVACY_OPTIONS = {
  disallowPromptTraining: true,
  zeroDataRetention: true,
} as const;

/** Exported so a test can assert the opt-out is never silently dropped. */
export const SESSION_PROVIDER_OPTIONS = {
  gateway: GATEWAY_PRIVACY_OPTIONS,
} as const;

export type SessionAnswer = { toolCallId: string; value: JSONValue };

export type { PendingQuestion } from "./transcript-replay.ts";

export type AdvanceResult = {
  messages: ModelMessage[];
  usage: TokenUsage;
  roundLatenciesMs: number[];
  promptId: string;
} & (
  | { status: "awaiting_answer"; pending: PendingQuestion }
  | {
      status: "completed";
      entry: { summary: string; answers: Record<string, Answer> };
    }
);

/** What one call of [advanceSession] runs on. */
export type AdvanceOptions = {
  questionSet: QuestionSet;
  model: LanguageModel;
  messages: ModelMessage[];
  answer?: SessionAnswer;
  temperature?: number;
  attribution?: { distinctId: string; sessionId: string };
  promptId?: string;
  /** Who the user is, as the app said this round; absent = nothing known. */
  userContext?: UserContext;
};

function roundSettings(
  opts: AdvanceOptions,
  prompt: ReturnType<typeof resolvePrompt>,
) {
  return {
    model: opts.model,
    // The user context lives in the instructions, rebuilt each round from
    // the request, never in the transcript: the transcript is signed and
    // stored by the app, and a name typed into it would outlive a rename.
    // `recordInputs: false` keeps the instructions out of telemetry too.
    instructions: prompt.build(opts.questionSet, opts.userContext),
    stopWhen: isStepCount(1),
    maxOutputTokens: MAX_OUTPUT_TOKENS_PER_ROUND,
    providerOptions: SESSION_PROVIDER_OPTIONS,
    ...(opts.temperature === undefined
      ? {}
      : { temperature: opts.temperature }),
    ...(opts.attribution === undefined
      ? {}
      : { runtimeContext: { ...opts.attribution, promptId: prompt.id } }),
    telemetry: SESSION_TELEMETRY,
  } as const;
}

function withAnswer(
  transcript: ModelMessage[],
  pending: PendingQuestion | undefined,
  answer: SessionAnswer | undefined,
): ModelMessage[] {
  if (transcript.length === 0) {
    return [
      { role: "user", content: "I am ready to start my journaling session." },
    ];
  }
  if (!pending) {
    return [...transcript];
  }
  if (answer?.toolCallId !== pending.toolCallId) {
    throw new Error("answer does not match the pending question");
  }
  return [
    ...transcript,
    {
      role: "tool",
      content: [
        {
          type: "tool-result",
          toolCallId: pending.toolCallId,
          toolName: "ask_question",
          output: { type: "json", value: { answer: answer.value } },
        },
      ],
    },
  ];
}

/**
 * Advance a session by as many model rounds as possible: from empty (new
 * session) or from a transcript + the answer to its pending question, up to
 * either the next ask_question or completion. Stateless — everything is
 * reconstructed from the transcript, so callers (CLI loop, HTTP endpoint)
 * own persistence.
 */
export async function advanceSession(
  opts: AdvanceOptions,
): Promise<AdvanceResult> {
  const { questionSet } = opts;
  const prompt = resolvePrompt(opts.promptId);
  const { answers, asked, pending } = replayTranscript(opts.messages);
  const roundLatenciesMs: number[] = [];
  const usage = emptyUsage();
  let summary: string | undefined;

  const messages = withAnswer(opts.messages, pending, opts.answer);

  const tools = buildSessionTools(questionSet, answers, asked, (s) => {
    summary = s;
  });
  const guard = roundGuard(questionSet);
  // Stateless guard: rounds already spent live in the transcript.
  for (const m of messages) {
    if (m.role === "assistant") {
      guard.next();
    }
  }

  while (summary === undefined) {
    guard.next();
    const startedAt = performance.now();
    const result = await generateText({
      ...roundSettings(opts, prompt),
      tools,
      messages,
    });
    roundLatenciesMs.push(performance.now() - startedAt);
    messages.push(...result.response.messages);
    addUsage(usage, result.usage);

    const ask =
      result.finishReason === "tool-calls"
        ? result.toolCalls.find((c) => c.toolName === "ask_question")
        : undefined;
    if (ask) {
      const input = ask.input as AskQuestionInput;
      asked.add(input.question_id);
      return {
        status: "awaiting_answer",
        messages,
        usage,
        roundLatenciesMs,
        promptId: prompt.id,
        pending: {
          toolCallId: ask.toolCallId,
          input: asAsked(questionSet, input),
        },
      };
    }
  }

  return {
    status: "completed",
    messages,
    usage,
    roundLatenciesMs,
    promptId: prompt.id,
    entry: { summary, answers },
  };
}
