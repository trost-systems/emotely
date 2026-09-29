import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { QuestionSet } from "./session.ts";
import { advanceSession, SESSION_PROVIDER_OPTIONS } from "./session-core.ts";
import { PROMPT_ID } from "./session-prompt.ts";
import { scriptedSessionModel } from "./test-helpers.ts";

const set: QuestionSet = {
  id: "s",
  name: "s",
  questions: [
    { id: "q-rate", text: "Rate your day?", answer_type: "rating" },
    { id: "q-best", text: "Best thing?", answer_type: "longtext" },
  ],
};

describe("advanceSession", () => {
  it("starts a session: runs to the first question and pauses", async () => {
    const model = scriptedSessionModel([
      {
        ask: {
          questionId: "q-rate",
          question: "Rate your day?",
          answerType: "rating",
        },
      },
    ]);
    const result = await advanceSession({
      questionSet: set,
      model,
      messages: [],
    });

    assert.equal(result.status, "awaiting_answer");
    if (result.status !== "awaiting_answer") {
      return;
    }
    assert.equal(result.pending.input.question_id, "q-rate");
    assert.ok(result.messages.length > 0);
  });

  it("tells the model who the user is on every round, never in the transcript", async () => {
    const systems: string[] = [];
    const scripted = scriptedSessionModel([
      { record: { questionId: "q-rate", answerType: "rating", value: 7 } },
      {
        record: { questionId: "q-best", answerType: "longtext", value: "n/a" },
      },
      { complete: "Rated 7." },
    ]);
    const inner = scripted.doGenerate.bind(scripted);
    scripted.doGenerate = async (options) => {
      for (const message of options.prompt) {
        if (message.role === "system") {
          systems.push(message.content);
        }
      }
      return await inner(options);
    };

    const done = await advanceSession({
      questionSet: set,
      model: scripted,
      messages: [],
      userContext: { displayName: "Maya", nameIsPlaceholder: false },
    });

    assert.equal(done.status, "completed");
    assert.equal(done.promptId, PROMPT_ID);
    assert.equal(systems.length, 3);
    assert.ok(systems.every((s) => s.includes('"Maya"')));
    // The context rides on each request, not in the signed transcript the
    // app stores: a renamed user is addressed by the new name next round.
    assert.ok(!JSON.stringify(done.messages).includes("Maya"));
  });

  it("shows the client the set's wording, not the model's rendering of it", async () => {
    // Seen live from gpt-oss-120b for "How productive did you feel today?":
    // the id was right, the text was not. The reviewed wording wins.
    const model = scriptedSessionModel([
      {
        ask: {
          questionId: "q-rate",
          question: "How productive did you feel ?   ?  ... ... etc  ...",
          answerType: "longtext",
        },
      },
    ]);
    const result = await advanceSession({
      questionSet: set,
      model,
      messages: [],
    });

    assert.equal(result.status, "awaiting_answer");
    if (result.status !== "awaiting_answer") {
      return;
    }
    assert.deepEqual(result.pending.input, {
      question_id: "q-rate",
      question: "Rate your day?",
      answer_type: "rating",
    });
  });

  it("consumes the answer, records, and pauses at the next question", async () => {
    const start = await advanceSession({
      questionSet: set,
      model: scriptedSessionModel([
        {
          ask: {
            questionId: "q-rate",
            question: "Rate your day?",
            answerType: "rating",
          },
        },
      ]),
      messages: [],
    });
    assert.equal(start.status, "awaiting_answer");
    if (start.status !== "awaiting_answer") {
      return;
    }

    const next = await advanceSession({
      questionSet: set,
      model: scriptedSessionModel([
        { record: { questionId: "q-rate", answerType: "rating", value: 7 } },
        {
          ask: {
            questionId: "q-best",
            question: "Best thing?",
            answerType: "longtext",
          },
        },
      ]),
      messages: start.messages,
      answer: { toolCallId: start.pending.toolCallId, value: 7 },
    });

    assert.equal(next.status, "awaiting_answer");
    if (next.status !== "awaiting_answer") {
      return;
    }
    assert.equal(next.pending.input.question_id, "q-best");
  });

  it("returns the journal entry when the model completes", async () => {
    const start = await advanceSession({
      questionSet: set,
      model: scriptedSessionModel([
        {
          ask: {
            questionId: "q-rate",
            question: "Rate your day?",
            answerType: "rating",
          },
        },
      ]),
      messages: [],
    });
    if (start.status !== "awaiting_answer") {
      assert.fail("expected pending question");
    }

    const done = await advanceSession({
      questionSet: set,
      model: scriptedSessionModel([
        { record: { questionId: "q-rate", answerType: "rating", value: 7 } },
        {
          record: {
            questionId: "q-best",
            answerType: "longtext",
            value: "n/a",
          },
        },
        { complete: "Rated 7." },
      ]),
      messages: start.messages,
      answer: { toolCallId: start.pending.toolCallId, value: 7 },
    });

    assert.equal(done.status, "completed");
    if (done.status !== "completed") {
      return;
    }
    assert.equal(done.entry.summary, "Rated 7.");
    assert.deepEqual(done.entry.answers["q-rate"], {
      answer_type: "rating",
      value: 7,
    });
  });
});

describe("gateway privacy options", () => {
  it("sends the prompt-training and retention opt-out on every round", async () => {
    // Journal transcripts are Art. 9 data: the opt-out has to reach the wire on
    // every round, not just the first, so capture what the provider is handed.
    const seen: (Record<string, unknown> | undefined)[] = [];
    const scripted = scriptedSessionModel([
      { record: { questionId: "q-rate", answerType: "rating", value: 7 } },
      {
        record: { questionId: "q-best", answerType: "longtext", value: "n/a" },
      },
      { complete: "Rated 7." },
    ]);
    const inner = scripted.doGenerate.bind(scripted);
    scripted.doGenerate = async (options) => {
      seen.push(options.providerOptions?.["gateway"]);
      return await inner(options);
    };

    const done = await advanceSession({
      questionSet: set,
      model: scripted,
      messages: [
        { role: "user", content: "I am ready to start my journaling session." },
      ],
    });

    assert.equal(done.status, "completed");
    assert.equal(seen.length, 3);
    for (const gateway of seen) {
      assert.deepEqual(gateway, {
        disallowPromptTraining: true,
        zeroDataRetention: true,
      });
    }
  });

  it("exports the options it sends, so the opt-out cannot be dropped", () => {
    assert.deepEqual(SESSION_PROVIDER_OPTIONS, {
      gateway: { disallowPromptTraining: true, zeroDataRetention: true },
    });
  });
});
