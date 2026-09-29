import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { inLanguage, languageOf } from "./language.ts";
import type { QuestionSet } from "./session.ts";

describe("languageOf", () => {
  it("speaks German for any German locale the app may send", () => {
    for (const locale of ["de", "de-DE", "de-AT", "DE", "de-Latn-CH"]) {
      assert.equal(languageOf(locale), "de", locale);
    }
  });

  it("speaks English for English, for no locale and for any it does not know", () => {
    for (const locale of [undefined, "en", "en-GB", "fr", "pt-BR", "zz"]) {
      assert.equal(languageOf(locale), "en", String(locale));
    }
  });

  it("never mistakes a property of every object for a language", () => {
    for (const locale of ["constructor", "__proto__", "toString"]) {
      assert.equal(languageOf(locale), "en", locale);
    }
  });
});

describe("inLanguage", () => {
  const set: QuestionSet = {
    id: "s",
    name: "s",
    questions: [
      {
        id: "q-learn",
        text: "What did you learn today?",
        translations: { de: "Was hast du heute gelernt?" },
        answer_type: "text_list",
        min_answers: 2,
      },
      { id: "q-best", text: "Best thing?", answer_type: "longtext" },
    ],
  };

  it("words each question in the language, keeping its id and type", () => {
    const german = inLanguage(set, "de");

    assert.equal(german.id, "s");
    assert.deepEqual(german.questions[0], {
      id: "q-learn",
      text: "Was hast du heute gelernt?",
      answer_type: "text_list",
      min_answers: 2,
    });
  });

  it("keeps the English text of a question that has no translation", () => {
    assert.equal(inLanguage(set, "de").questions[1]?.text, "Best thing?");
  });

  it("is the English set in English", () => {
    assert.deepEqual(
      inLanguage(set, "en").questions.map((q) => q.text),
      ["What did you learn today?", "Best thing?"],
    );
  });
});
