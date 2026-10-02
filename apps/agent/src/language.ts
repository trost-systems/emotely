import type { QuestionSet, WordedQuestionSet } from "./session-core.ts";

/**
 * The languages the companion speaks, by BCP 47 language subtag, with the
 * English name a prompt calls each by. They are the app's own (ADR 0020):
 * a language the app does not show is one the companion does not speak.
 */
export const languageNames = { en: "English", de: "German" } as const;

export type Language = keyof typeof languageNames;

/**
 * One text in every language the companion speaks (#228). Every language is
 * required: adding one to [languageNames] makes each text missing it a type
 * error, never a silent fallback to English.
 */
export type Wording = Record<Language, string>;

function isLanguage(subtag: string): subtag is Language {
  return Object.hasOwn(languageNames, subtag);
}

/**
 * The language to speak for the locale the app sent: its language subtag
 * when the companion speaks it, English for any other and for none. This is
 * the only fallback to English there is.
 */
export function languageOf(locale: string | undefined): Language {
  const subtag = locale?.split("-")[0]?.toLowerCase();
  return subtag !== undefined && isLanguage(subtag) ? subtag : "en";
}

/**
 * [set] worded in [language], the only bridge from an authored set to the
 * one a session runs on. Ids, answer types and counts stay as they are —
 * they are what stored sessions and PostHog events name, in any language.
 */
export function inLanguage(
  set: QuestionSet,
  language: Language,
): WordedQuestionSet {
  return {
    ...set,
    questions: set.questions.map((question) => ({
      ...question,
      text: question.text[language],
    })),
  };
}
