import type { QuestionSet } from "./session-core.ts";

/**
 * The languages the companion speaks, by BCP 47 language subtag, with the
 * English name a prompt calls each by. They are the app's own (ADR 0020):
 * a language the app does not show is one the companion does not speak.
 * English is the source every other text is translated from.
 */
export const languageNames = { en: "English", de: "German" } as const;

export type Language = keyof typeof languageNames;

/** A text's translations, one per language other than English (#228). */
export type Translations = Partial<Record<Exclude<Language, "en">, string>>;

function isLanguage(subtag: string): subtag is Language {
  return Object.hasOwn(languageNames, subtag);
}

/**
 * The language to speak for the locale the app sent: its language subtag
 * when the companion speaks it, English for any other and for none.
 */
export function languageOf(locale: string | undefined): Language {
  const subtag = locale?.split("-")[0]?.toLowerCase();
  return subtag !== undefined && isLanguage(subtag) ? subtag : "en";
}

/**
 * [set] worded in [language]: each question's translation, or its English
 * text where it has none. Ids, answer types and counts stay as they are —
 * they are what stored sessions and PostHog events name, in any language.
 */
export function inLanguage(set: QuestionSet, language: Language): QuestionSet {
  return {
    ...set,
    questions: set.questions.map(({ translations, ...question }) => ({
      ...question,
      text:
        language === "en"
          ? question.text
          : (translations?.[language] ?? question.text),
    })),
  };
}
