import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { JSONValue } from "ai";
import { MODEL_RATES, sessionCostUsd } from "../src/cost.ts";
import { defaultQuestionSet } from "../src/default-question-set.ts";
import { inLanguage } from "../src/language.ts";
import { runSession, type UserContext } from "../src/session.ts";
import { modelUnderTest, scriptedClient } from "./harness.ts";
import { fullSessionAnswers, fullSessionAnswersDe } from "./scenarios.ts";

/** A benign full session, retried once when the first run is incomplete. */
async function fullSession(
  answers: Record<string, JSONValue>,
  userContext?: UserContext,
) {
  // temperature 0 for stability; one retry absorbs residual variance.
  const attempt = () => {
    const scripted = scriptedClient(answers);
    return runSession({
      questionSet: defaultQuestionSet,
      client: scripted,
      model: modelUnderTest,
      temperature: 0,
      ...(userContext === undefined ? {} : { userContext }),
    }).then((session) => ({ result: session, client: scripted }));
  };
  const complete = (candidate: Awaited<ReturnType<typeof attempt>>) =>
    defaultQuestionSet.questions.every(
      (q) => candidate.client.asked.has(q.id) && candidate.result.answers[q.id],
    );
  let run = await attempt();
  if (!complete(run)) {
    console.log("# eval-report protocol retry after incomplete first run");
    run = await attempt();
  }
  return run;
}

/**
 * How [run] breaks the protocol every session upholds, in any language;
 * empty when it does not. Logs the eval report line on the way.
 */
function protocolBreaches({
  result,
  client,
}: Awaited<ReturnType<typeof fullSession>>): string[] {
  const breaches: string[] = [];
  // Every question asked (no fabricated answers) and answered with the
  // type its question declares.
  for (const q of defaultQuestionSet.questions) {
    const recorded = result.answers[q.id];
    if (!client.asked.has(q.id)) {
      breaches.push(`question ${q.id} was never asked`);
    }
    if (recorded === undefined) {
      breaches.push(`question ${q.id} has no recorded answer`);
      continue;
    }
    if (recorded.answer_type !== q.answer_type) {
      breaches.push(`question ${q.id} was answered as ${recorded.answer_type}`);
    }
    if (
      q.min_answers !== undefined &&
      !(Array.isArray(recorded.value) && recorded.value.length >= q.min_answers)
    ) {
      breaches.push(`question ${q.id} needs at least ${q.min_answers} answers`);
    }
  }
  if (result.summary.length === 0) {
    breaches.push("the summary is empty");
  }

  const rates = MODEL_RATES[modelUnderTest];
  if (rates === undefined) {
    return [...breaches, `no rates for ${modelUnderTest} — add to MODEL_RATES`];
  }
  const cost = sessionCostUsd([result.usage], rates);
  console.log(
    `# eval-report model=${modelUnderTest} prompt=${result.promptId} ` +
      `tokens=${result.usage.inputTokens}/${result.usage.outputTokens} ` +
      `cached=${result.usage.cacheReadTokens} cost=$${cost.toFixed(5)}`,
  );
  // ponytail: order-of-magnitude ceiling, catches pathology not price drift;
  // tightened in #4 once the benchmark sets a baseline.
  if (cost >= 0.01) {
    breaches.push(`session cost $${cost} exceeded the 1¢ ceiling`);
  }
  return breaches;
}

// Deterministic PR gate: a benign full session against the live model must
// uphold the protocol, in English and in German. Judged (fuzzy) behavior
// lives in behavior.eval.ts, which runs nightly.
describe(`protocol eval — ${modelUnderTest}`, () => {
  it("completes a full 10-question session within the cost ceiling", async () => {
    assert.deepEqual(
      protocolBreaches(await fullSession(fullSessionAnswers)),
      [],
    );
  });

  it("completes a full session in German for a German app (#228)", async () => {
    const run = await fullSession(fullSessionAnswersDe, { locale: "de" });
    assert.deepEqual(protocolBreaches(run), []);

    // The client is shown the set's German wording, every question.
    for (const q of inLanguage(defaultQuestionSet, "de").questions) {
      assert.equal(run.client.shown.get(q.id), q.text, q.id);
    }
    // The entry is German. A machine check, not a judgment of its German:
    // an English summary has none of these words.
    assert.match(
      run.result.summary,
      /\b(und|du|dein\w*|dich|dir|heute|der|das|ist)\b/i,
      `summary is not German: ${run.result.summary}`,
    );
  });
});
