import type { AskQuestionInput } from "@emotely/contract";
import type { JSONValue, LanguageModel } from "ai";
import type {
  QuestionSet,
  SessionResult,
  UserContext,
} from "./session-core.ts";
import { advanceSession, emptyUsage } from "./session-core.ts";

export type {
  AdvanceResult,
  PendingQuestion,
  Question,
  QuestionSet,
  SessionAnswer,
  SessionResult,
  UserContext,
  WordedQuestion,
  WordedQuestionSet,
} from "./session-core.ts";
export { advanceSession } from "./session-core.ts";

export type SessionClient = {
  /** Answer an ask_question tool call with the raw widget value. */
  askQuestion: (input: AskQuestionInput) => Promise<JSONValue>;
};

/** Run a whole session in-process by looping advanceSession over a client. */
export async function runSession(opts: {
  questionSet: QuestionSet;
  client: SessionClient;
  model: LanguageModel;
  /** Sampling temperature; evals pin 0 for stability, product uses default. */
  temperature?: number;
  /** Joins spans to a person + session in PostHog; absent = anonymous. */
  attribution?: { distinctId: string; sessionId: string };
  /** Prompt version to run (flag payload); unknown ids fall back to current. */
  promptId?: string;
  /** Who the user is, sent with every round as the app does; absent = none. */
  userContext?: UserContext;
}): Promise<SessionResult> {
  const { questionSet, client, model, temperature, attribution } = opts;
  const usage = emptyUsage();
  const roundLatenciesMs: number[] = [];
  let messages: SessionResult["messages"] = [];
  let answer: { toolCallId: string; value: JSONValue } | undefined;

  for (;;) {
    const step = await advanceSession({
      questionSet,
      model,
      messages,
      ...(answer === undefined ? {} : { answer }),
      ...(temperature === undefined ? {} : { temperature }),
      ...(attribution === undefined ? {} : { attribution }),
      ...(opts.promptId === undefined ? {} : { promptId: opts.promptId }),
      ...(opts.userContext === undefined
        ? {}
        : { userContext: opts.userContext }),
    });
    ({ messages } = step);
    usage.inputTokens += step.usage.inputTokens;
    usage.cacheReadTokens += step.usage.cacheReadTokens;
    usage.outputTokens += step.usage.outputTokens;
    roundLatenciesMs.push(...step.roundLatenciesMs);

    if (step.status === "completed") {
      return {
        summary: step.entry.summary,
        answers: step.entry.answers,
        usage,
        messages,
        promptId: step.promptId,
        roundLatenciesMs,
      };
    }
    answer = {
      toolCallId: step.pending.toolCallId,
      value: await client.askQuestion(step.pending.input),
    };
  }
}
