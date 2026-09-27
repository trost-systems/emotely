import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";

// The in-app privacy notice (apps/web/lib/pages/app_privacy.dart) tells users
// the agent runs in Frankfurt. `regions` in vercel.json overrides the
// dashboard's Function Region, so this file is the one place that decides it;
// if it goes, Vercel falls back to the project setting, which may be iad1
// (Washington, D.C.). Moving the region is a notice change, not a config
// tweak (ADR 0010, amendment 2026-09-27).
describe("function region", () => {
  it("pins every function to Frankfurt (fra1) and nowhere else", () => {
    const config: unknown = JSON.parse(
      readFileSync(new URL("../vercel.json", import.meta.url), "utf8"),
    );
    assert.ok(typeof config === "object" && config !== null);
    assert.deepEqual(Reflect.get(config, "regions"), ["fra1"]);
    // Failover regions and per-function overrides could run a round outside
    // the EU without the notice saying so.
    assert.equal(Reflect.get(config, "functionFailoverRegions"), undefined);
    assert.equal(Reflect.get(config, "functions"), undefined);
  });
});
