import { type Language, languageNames, languageOf } from "./language.ts";
import type { QuestionSet, UserContext } from "./session.ts";

// Bump by hand on any change that alters assistant behavior; evals and
// PostHog events pin against this id. Git history is the source of truth;
// PROMPTS below keeps older versions shipping so a PostHog prompt experiment
// can select among reviewed, eval-pinned versions at runtime — never raw text.
export const PROMPT_ID = "session/v4";

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
function addressing(
  context: UserContext | undefined,
  placeholder: (quoted: string) => string,
): string | undefined {
  const name = context?.displayName;
  if (name === undefined) {
    return undefined;
  }
  const quoted = JSON.stringify(name);
  if (context?.nameIsPlaceholder === true) {
    return placeholder(quoted);
  }
  return `The user's name is ${quoted}. Use it naturally and sparingly — when greeting them and now and then after, never in every message. Never ask for their name; you already have it.`;
}

/** v2's words for a placeholder, which call it a nickname. */
const placeholderV2 = (quoted: string): string =>
  `The user preferred not to share their name, so emotely picked a playful nickname for them: ${quoted}. It is not their real name — use it lightly and warmly, at most when greeting them and perhaps once more, as a friendly in-joke rather than a label. Never ask for their real name. If they bring up their name, it is fine to say they can tell you their real name in their profile.`;

/**
 * v3's words for a placeholder: the name emotely picked (CONTEXT.md,
 * "Placeholder name"). The name step asks for "a first name or a nickname",
 * so a nickname is a name the user gives themselves, never emotely's pick.
 */
const placeholderV3 = (quoted: string): string =>
  `The user preferred not to share their name, so emotely picked a playful stand-in name for them: ${quoted}. It is not their real name — use it lightly and warmly, at most when greeting them and perhaps once more, as a friendly in-joke rather than a label. If it comes up, call it the name emotely picked for them. Never ask for their real name. If they bring up their name, it is fine to say they can tell you their real name in their profile.`;

/** The protocol, then how to address the user when the app says who they are. */
const withAddressing = (
  set: QuestionSet,
  context: UserContext | undefined,
  placeholder: (quoted: string) => string,
): string => {
  const base = sessionPromptV1(set);
  const address = addressing(context, placeholder);
  return address === undefined ? base : `${base}\n\n${address}`;
};

/**
 * v1's protocol, plus who the user is when the app says so. Without a name
 * it is v1 word for word, so an app that sends no context behaves exactly as
 * before.
 */
const sessionPromptV2 = (set: QuestionSet, context?: UserContext): string =>
  withAddressing(set, context, placeholderV2);

/** v2, except that a placeholder is the name emotely picked, not a nickname. */
const sessionPromptV3 = (set: QuestionSet, context?: UserContext): string =>
  withAddressing(set, context, placeholderV3);

/**
 * How v4 speaks each language but English, beyond its name: the words
 * CONTEXT.md gives that language, which the model would otherwise pick for
 * itself ("Sitzung", "Sie", "Assistent").
 */
const conventions: Record<Exclude<Language, "en">, string> = {
  de: `Address the user informally with "du", never "Sie", as a friend would. In German, a session is "die Session" (never "Sitzung"), the journal entry is "der Eintrag" and the journal is "das Tagebuch". Should you ever name yourself, you are emotely, in lower case — never an "Assistent".`,
};

/**
 * v3, spoken in the user's language (#228). The questions are already in
 * it — the session hands the prompt the set's reviewed translation — so the
 * model only has to pass them along and write the entry in that language.
 * Answers stay the user's own words, in whatever language they wrote them.
 * In English it is v3 word for word.
 */
const sessionPromptV4 = (set: QuestionSet, context?: UserContext): string => {
  const base = sessionPromptV3(set, context);
  const language = languageOf(context?.locale);
  if (language === "en") {
    return base;
  }
  const name = languageNames[language];
  return `${base}

Speak ${name} with the user. The questions above are already in ${name}: pass each to ask_question exactly as written. Write the summary for complete_session in ${name}. Record every answer exactly as the user gave it, in whatever language they wrote it — never translate what the user wrote. ${conventions[language]}`;
};

/**
 * Builds the system prompt for one round. It takes the whole user context
 * so a version that learns to use a new member (a local date, a time zone)
 * needs no new signature; a version that predates a member ignores it.
 */
export type PromptBuilder = (set: QuestionSet, context?: UserContext) => string;

/**
 * One shipped prompt version: its words, and the language its sessions run
 * in, which picks the wording of the questions the client is shown too.
 */
export type PromptVersion = {
  build: PromptBuilder;
  language: (context?: UserContext) => Language;
};

/** Every version before v4 speaks English, whatever the app's locale. */
const english = (): Language => "en";

const current: PromptVersion = {
  build: sessionPromptV4,
  language: (context) => languageOf(context?.locale),
};

/** Every prompt version this build can serve; add a line when one changes. */
export const PROMPTS: Record<string, PromptVersion> = {
  "session/v1": { build: sessionPromptV1, language: english },
  "session/v2": { build: sessionPromptV2, language: english },
  "session/v3": { build: sessionPromptV3, language: english },
  [PROMPT_ID]: current,
};

/**
 * The flag payload names a version; only shipped versions can run. Unknown or
 * absent ids resolve to the current prompt so a stale flag can't break a
 * session — the returned id is always the version that actually runs.
 */
export function resolvePrompt(
  requested: string | undefined,
  registry: Record<string, PromptVersion> = PROMPTS,
): { id: string } & PromptVersion {
  if (requested !== undefined) {
    const version = registry[requested];
    if (version) {
      return { id: requested, ...version };
    }
  }
  return { id: PROMPT_ID, ...current };
}
