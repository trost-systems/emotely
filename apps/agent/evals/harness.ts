import process from "node:process";
import type { JSONValue, LanguageModel, ModelMessage } from "ai";
import { judgeSession } from "../src/judge.ts";
import { inLanguage, languageNames, languageOf } from "../src/language.ts";
import type {
  SessionClient,
  UserContext,
  WordedQuestionSet,
} from "../src/session.ts";
import { runSession } from "../src/session.ts";
import { miniSet, type Scenario } from "./scenarios.ts";

try {
  process.loadEnvFile(new URL("../.env.local", import.meta.url).pathname);
} catch {
  // fine — CI provides the key via the environment
}

export const modelUnderTest =
  process.env["EMOTELY_MODEL"] ?? "openai/gpt-oss-120b";
// Judge: open source, cheap, and from a different family than the candidates
// it grades (avoids same-family self-preference). Benched 2026-08-21 for
// schema reliability + verdict quality: qwen3.7-plus 5/5 on both; deepseek
// v4-flash and gpt-oss-120b could not hold the verdict schema, qwen3.7-flash
// misjudged 4/5. $0.40/M in, $1.20/M out.
export const judgeModel =
  process.env["EMOTELY_JUDGE_MODEL"] ?? "alibaba/qwen3.7-plus";

/**
 * Scripted user: answers each question from a canned map and remembers what
 * was asked, and the wording it was shown for each question id.
 */
export function scriptedClient(
  answers: Record<string, JSONValue>,
): SessionClient & { asked: Set<string>; shown: Map<string, string> } {
  const asked = new Set<string>();
  const shown = new Map<string, string>();
  return {
    asked,
    shown,
    askQuestion: async (input) => {
      asked.add(input.question_id);
      shown.set(input.question_id, input.question);
      const answer = answers[input.question_id];
      if (answer === undefined) {
        throw new Error(`fixture has no answer for ${input.question_id}`);
      }
      return answer;
    },
  };
}

/** Renders the session messages as plain text for the judge. */
export function formatTranscript(messages: ModelMessage[]): string {
  const lines: string[] = [];
  for (const m of messages) {
    if (typeof m.content === "string") {
      lines.push(`${m.role}: ${m.content}`);
      continue;
    }
    for (const part of m.content) {
      if (part.type === "text") {
        lines.push(`${m.role}: ${part.text}`);
      } else if (part.type === "tool-call") {
        lines.push(
          `${m.role} [${part.toolName}]: ${JSON.stringify(part.input)}`,
        );
      } else if (part.type === "tool-result") {
        lines.push(
          `${m.role} [${part.toolName} result]: ${JSON.stringify(part.output)}`,
        );
      }
    }
  }
  return lines.join("\n");
}

/** N runs with a 2/3 pass-rate gate (single runs must pass outright). */
export const evalRuns = Number(process.env["EVAL_RUNS"] ?? "1");
export const requiredPasses = Math.ceil((evalRuns * 2) / 3);

/** Tells the judge what "complete" means for this session. */
export function describeQuestionSet(set: WordedQuestionSet): string {
  return `The question set has exactly ${set.questions.length} question(s); the session is complete once each has an answer and complete_session was called:\n${set.questions.map((q, i) => `${i + 1}. ${q.id}: "${q.text}" (${q.answer_type})`).join("\n")}`;
}

/** Tells the judge what the assistant was told about the user, if anything. */
export function describeUserContext(context: UserContext | undefined): string {
  const language =
    context?.locale === undefined
      ? ""
      : ` The user's app is in ${languageNames[languageOf(context.locale)]}, and the assistant was told so.`;
  const name = context?.displayName;
  if (name === undefined) {
    return language === ""
      ? "The assistant was told nothing about the user, not even a name."
      : `The assistant was told no name for the user.${language}`;
  }
  return context?.nameIsPlaceholder === true
    ? `The user preferred not to share a name, so emotely picked the playful stand-in name "${name}" for them; the assistant was told so.${language}`
    : `The assistant was told the user's name: "${name}".${language}`;
}

/** One scenario run; returns null on pass, a failure description otherwise. */
export async function runScenarioOnce(
  scenario: Scenario,
  model: LanguageModel,
): Promise<string | null> {
  // A crashed run (model emitted malformed tool input, gateway error)
  // counts as a failed run instead of aborting the scenario.
  let result: Awaited<ReturnType<typeof runSession>>;
  const client = scriptedClient(scenario.answers);
  try {
    result = await runSession({
      questionSet: miniSet,
      client,
      model,
      ...(scenario.userContext === undefined
        ? {}
        : { userContext: scenario.userContext }),
    });
  } catch (err) {
    return `session crashed — ${String(err)}`;
  }

  // Every question must be asked AND answered: an answer recorded without
  // asking is a fabricated answer, which the judge may or may not notice.
  const machineOk =
    result.summary.length > 0 &&
    miniSet.questions.every(
      (q) => client.asked.has(q.id) && result.answers[q.id],
    );

  const verdicts = await judgeSession({
    model: judgeModel,
    transcript: formatTranscript(result.messages),
    rubrics: scenario.rubrics,
    context: [
      // The wording the session ran in, so the judge knows what it saw.
      describeQuestionSet(
        inLanguage(miniSet, languageOf(scenario.userContext?.locale)),
      ),
      describeUserContext(scenario.userContext),
    ].join("\n"),
  });
  const failed = verdicts.filter((v) => !v.pass);

  if (machineOk && failed.length === 0) {
    return null;
  }
  const unasked = miniSet.questions
    .filter((q) => !client.asked.has(q.id))
    .map((q) => q.id);
  const machineNote = machineOk
    ? ""
    : `incomplete session${unasked.length > 0 ? ` (never asked: ${unasked.join(", ")})` : ""}; `;
  return `${machineNote}${failed
    .map((v) => `"${v.rubric}" — ${v.reason}`)
    .join("; ")}`;
}
