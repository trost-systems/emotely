import assert from "node:assert/strict";
import { after, describe, it } from "node:test";
import { InMemorySpanExporter } from "@opentelemetry/sdk-trace-base";
import type { QuestionSet, SessionClient } from "./session.ts";
import { runSession } from "./session.ts";
import { initTelemetry } from "./telemetry.ts";
import { scriptedSessionModel } from "./test-helpers.ts";

// ADR 0005: journal content must never leave the process via telemetry.
// A scripted session runs under a real OTel pipeline with an in-memory
// exporter; no exported span attribute may contain the sentinel answers.

const SENTINEL = "SENTINEL_JOURNAL_TEXT_9f4e";

const bestQuestion = {
  id: "q-best",
  text: {
    en: "What was the best thing today?",
    de: "Was war heute das Beste?",
  },
  answer_type: "longtext",
} satisfies QuestionSet["questions"][number];
const set: QuestionSet = {
  id: "leak-set",
  name: "Leak set",
  questions: [bestQuestion],
};

const exporter = new InMemorySpanExporter();
const shutdown = initTelemetry({ testExporter: exporter });
after(async () => {
  await shutdown();
});

describe("telemetry privacy", () => {
  it("exports spans with usage but never journal content", async () => {
    const model = scriptedSessionModel([
      {
        ask: {
          questionId: bestQuestion.id,
          question: bestQuestion.text.en,
          answerType: bestQuestion.answer_type,
        },
      },
      {
        record: {
          questionId: "q-best",
          answerType: "longtext",
          value: SENTINEL,
        },
      },
      { complete: `A day: ${SENTINEL}` },
    ]);
    const client: SessionClient = { askQuestion: async () => SENTINEL };

    await runSession({ questionSet: set, client, model });

    const spans = exporter.getFinishedSpans();
    assert.ok(spans.length > 0, "no spans exported — telemetry not wired");

    const attrs = spans.flatMap((s) => Object.entries(s.attributes));
    const leaks = attrs.filter(([, v]) => JSON.stringify(v).includes(SENTINEL));
    assert.deepEqual(
      leaks.map(([k]) => k),
      [],
      "journal content leaked into span attributes",
    );

    // The observability payload we DO want must survive redaction.
    const keys = new Set(attrs.map(([k]) => k));
    assert.ok(
      [...keys].some((k) => k.includes("usage") || k.includes("token")),
      "usage attributes missing",
    );
  });
  it("sends the user's name to the model and never to telemetry", async () => {
    const NAME = "SENTINEL_NAME_71c2";
    const model = scriptedSessionModel([
      {
        ask: {
          questionId: bestQuestion.id,
          question: bestQuestion.text.en,
          answerType: bestQuestion.answer_type,
        },
      },
      {
        record: { questionId: "q-best", answerType: "longtext", value: "ok" },
      },
      { complete: "A day." },
    ]);
    let prompted = false;
    const inner = model.doGenerate.bind(model);
    model.doGenerate = async (options) => {
      prompted ||= JSON.stringify(options.prompt).includes(NAME);
      return await inner(options);
    };

    exporter.reset();
    await runSession({
      questionSet: set,
      client: { askQuestion: async () => "ok" },
      model,
      userContext: { displayName: NAME, nameIsPlaceholder: false },
    });

    assert.ok(prompted, "the name never reached the model");
    const spans = exporter.getFinishedSpans();
    const leaks = [
      ...spans.flatMap((sp) => Object.entries(sp.attributes)),
      ...spans.flatMap((sp) =>
        sp.events.flatMap((e) => Object.entries(e.attributes ?? {})),
      ),
    ]
      .filter(([, v]) => JSON.stringify(v).includes(NAME))
      .map(([k]) => k);
    assert.deepEqual(leaks, [], "the user's name leaked into telemetry");
  });

  it("does not leak journal content through tool validation errors", async () => {
    const model = scriptedSessionModel([
      { ask: { questionId: "q-best", question: "Q?", answerType: "longtext" } },
      // Type-invalid value: rating with a string — the SDK throws on parse,
      // and error messages are NOT covered by recordInputs/recordOutputs.
      {
        record: { questionId: "q-best", answerType: "rating", value: SENTINEL },
      },
      {
        record: {
          questionId: "q-best",
          answerType: "longtext",
          value: SENTINEL,
        },
      },
      { complete: "Done despite the fumble." },
    ]);
    const client: SessionClient = { askQuestion: async () => SENTINEL };

    exporter.reset();
    await runSession({ questionSet: set, client, model });

    const spans = exporter.getFinishedSpans();
    const leaks = spans
      .flatMap((s) => Object.entries(s.attributes))
      .filter(([, v]) => JSON.stringify(v).includes(SENTINEL))
      .map(([k]) => k);
    const eventLeaks = spans
      .flatMap((s) => s.events)
      .filter((e) => JSON.stringify(e.attributes ?? {}).includes(SENTINEL))
      .map((e) => e.name);
    assert.deepEqual(leaks, [], "validation error leaked journal content");
    assert.deepEqual(eventLeaks, [], "span event leaked journal content");
  });

  it("does not leak journal content when the client throws", async () => {
    const model = scriptedSessionModel([
      { ask: { questionId: "q-best", question: "Q?", answerType: "longtext" } },
    ]);
    const client: SessionClient = {
      askQuestion: async () => {
        throw new Error(`widget exploded rendering: ${SENTINEL}`);
      },
    };

    exporter.reset();
    await assert.rejects(runSession({ questionSet: set, client, model }));

    const spans = exporter.getFinishedSpans();
    const leaks = [
      ...spans.flatMap((sp) => Object.entries(sp.attributes)),
      ...spans.flatMap((sp) =>
        sp.events.flatMap((e) => Object.entries(e.attributes ?? {})),
      ),
    ]
      .filter(([, v]) => JSON.stringify(v).includes(SENTINEL))
      .map(([k]) => k);
    assert.deepEqual(leaks, [], "client error leaked journal content");
  });
});
