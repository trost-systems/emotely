import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { defaultQuestionSet } from "./default-question-set.ts";
import { inLanguage } from "./language.ts";

describe("defaultQuestionSet", () => {
  it("keeps its question ids: stored sessions and PostHog events name them", () => {
    assert.deepEqual(
      defaultQuestionSet.questions.map((q) => q.id),
      [
        "learned-today",
        "best-thing",
        "day-colors",
        "mood-emojis",
        "productivity",
        "satisfaction",
        "appreciation",
        "gratitude-list",
        "goal-alignment",
        "gratitude-person",
      ],
    );
  });

  it("words every question in German too", () => {
    const german = inLanguage(defaultQuestionSet, "de");

    for (const [i, q] of german.questions.entries()) {
      const english = defaultQuestionSet.questions[i];
      assert.ok(english, q.id);
      assert.notEqual(q.text, english.text, `${q.id} has no German text`);
      assert.equal(q.answer_type, english.answer_type, q.id);
    }
  });

  it("addresses the user as du, never Sie, as CONTEXT.md does", () => {
    // The copy spell check holds the spelling and the words to avoid; the
    // form of address is grammar, which it cannot see.
    const texts = inLanguage(defaultQuestionSet, "de").questions.map(
      (q) => q.text,
    );

    for (const text of texts) {
      assert.doesNotMatch(text, /\b(Sie|Ihnen|Ihr|Ihre[mnrs]?)\b/, text);
    }
    assert.ok(
      texts.some((text) => /\b(du|dir|dich|dein\w*)\b/.test(text)),
      "the questions address the user as du",
    );
  });

  it("asks for the same number of answers in every language", () => {
    const german = inLanguage(defaultQuestionSet, "de");
    const list = german.questions.find((q) => q.id === "gratitude-list");

    assert.equal(list?.min_answers, 3);
    assert.match(list?.text ?? "", /3/);
  });
});
