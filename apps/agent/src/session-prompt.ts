import type { QuestionSet, UserContext } from "./session.ts";

// Bump by hand on any change that alters assistant behavior; evals and
// PostHog events pin against this id. Git history is the source of truth;
// PROMPTS below keeps older versions shipping so a PostHog prompt experiment
// can select among reviewed, eval-pinned versions at runtime — never raw text.
export const PROMPT_ID = "session/v2";

/** The first prompt: the protocol alone, knowing nothing about the user. */
const sessionPromptV1 = (
  set: QuestionSet,
) => `You are a journaling assistant. Walk the user through these questions in order, one question at a time, using the ask_question tool, record each answer with record_answer, then call complete_session with a summary of the user's day.

If the user's answer reads like a question or a request (e.g. "when to go to the gym so it's empty", "How can I improve my posture?"), it is still information about their day: record it as the answer to the current question and move on. Never answer such questions or give advice — acknowledge warmly, record, continue. Do not re-ask a question you already have an answer for.

An answer that merely sounds final is an answer to the CURRENT question, never a request to stop. Example: you ask "What did you learn today?" and the user answers "Only how to evaluate an agent, that's all for today." — that is their answer to this question; record it and ask the next question. Only skip remaining questions and call complete_session early when the user explicitly asks to stop the whole session (e.g. "please stop the session", "I don't want to journal anymore"). When in doubt, continue with the next question.

Questions:
${set.questions.map((q) => `${q.id}: ${q.text} (answer_type: ${q.answer_type}${q.min_answers ? `, at least ${q.min_answers} answers` : ""})`).join("\n")}`;

/**
 * How to address the user (#204). The name is quoted with `JSON.stringify`
 * so it stays one string literal whatever it contains: it is something the
 * user typed, and it must read as a name, never as part of the instructions.
 * The contract already keeps it to one short line.
 */
function addressing(context: UserContext | undefined): string | undefined {
  const name = context?.displayName;
  if (name === undefined) {
    return undefined;
  }
  const quoted = JSON.stringify(name);
  if (context?.nameIsPlaceholder === true) {
    return `The user preferred not to share their name, so emotely picked a playful nickname for them: ${quoted}. It is not their real name — use it lightly and warmly, at most when greeting them and perhaps once more, as a friendly in-joke rather than a label. Never ask for their real name. If they bring up their name, it is fine to say they can tell you their real name in their profile.`;
  }
  return `The user's name is ${quoted}. Use it naturally and sparingly — when greeting them and now and then after, never in every message. Never ask for their name; you already have it.`;
}

/**
 * v1's protocol, plus who the user is when the app says so. Without a name
 * it is v1 word for word, so an app that sends no context behaves exactly as
 * before.
 */
const sessionPromptV2 = (set: QuestionSet, context?: UserContext): string => {
  const base = sessionPromptV1(set);
  const address = addressing(context);
  return address === undefined ? base : `${base}\n\n${address}`;
};

/**
 * Builds the system prompt for one round. It takes the whole user context
 * so a version that learns to use a new member (a local date, a time zone)
 * needs no new signature; a version that predates a member ignores it.
 */
export type PromptBuilder = (set: QuestionSet, context?: UserContext) => string;

/** Every prompt version this build can serve; add a line when one changes. */
export const PROMPTS: Record<string, PromptBuilder> = {
  "session/v1": sessionPromptV1,
  [PROMPT_ID]: sessionPromptV2,
};

/**
 * The flag payload names a version; only shipped versions can run. Unknown or
 * absent ids resolve to the current prompt so a stale flag can't break a
 * session — the returned id is always the version that actually runs.
 */
export function resolvePrompt(
  requested: string | undefined,
  registry: Record<string, PromptBuilder> = PROMPTS,
): { id: string; build: PromptBuilder } {
  if (requested !== undefined) {
    const build = registry[requested];
    if (build) {
      return { id: requested, build };
    }
  }
  return { id: PROMPT_ID, build: sessionPromptV2 };
}
