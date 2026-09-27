import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  evalRuns,
  judgeModel,
  modelUnderTest,
  requiredPasses,
  runScenarioOnce,
} from "./harness.ts";
import { scenarios } from "./scenarios.ts";

// Judged behavioral scenarios: opening tone, question-lookalikes,
// end-of-conversation lookalikes, out-of-context prompts, and the user's name
// (given, a placeholder, or none at all).
// Nightly gate: 2-of-3 runs must pass; a scenario passes a run when the
// machine checks hold AND every rubric passes.

describe(`behavior eval — ${modelUnderTest}, judge ${judgeModel}, runs ${evalRuns}`, () => {
  for (const scenario of scenarios) {
    it(scenario.name, async () => {
      const failures: string[] = [];

      for (let run = 1; run <= evalRuns; run++) {
        const failure = await runScenarioOnce(scenario, modelUnderTest);
        if (failure !== null) {
          failures.push(`run ${run}: ${failure}`);
        }
      }
      const passes = evalRuns - failures.length;

      console.log(
        `# eval-report scenario="${scenario.name}" passes=${passes}/${evalRuns}`,
      );
      assert.ok(
        passes >= requiredPasses,
        `${passes}/${evalRuns} runs passed (need ${requiredPasses}):\n${failures.join("\n")}`,
      );
    });
  }
});
