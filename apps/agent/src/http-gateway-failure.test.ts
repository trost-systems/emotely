import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { createAdvanceSessionHandler } from "./http-advance-session.ts";

// The endpoint's behavior when the model round itself is refused upstream
// (issue #99). Kept apart from http-advance-session.test.ts, which covers the
// request-validation ladder in front of the model call.

const SECRET = "handler-secret";
const signedIn = async () => ({ userId: "user-1" });

function post(body: unknown): Request {
  return new Request("http://x/api/advance-session", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

/**
 * The live shape measured against the gateway on 2026-09-15 for a model no
 * ZDR provider serves: the class says "internal server error" and the status
 * says 400, so neither alone identifies the refusal (see error-tracking.ts).
 */
function gatewayRejection(): Error {
  return Object.assign(
    new Error(
      "No ZDR (Zero Data Retention) providers or ZDR-attested BYOK credentials available for model: moonshotai/kimi-k2. Providers considered: novita",
    ),
    {
      name: "GatewayInternalServerError",
      type: "internal_server_error",
      statusCode: 400,
      isRetryable: false,
    },
  );
}

function refusing(onFailure?: (error: unknown) => void) {
  return createAdvanceSessionHandler({
    secret: SECRET,
    verifyCaller: signedIn,
    advance: async () => {
      throw gatewayRejection();
    },
    ...(onFailure === undefined ? {} : { onFailure }),
  });
}

describe("a model round the gateway refused", () => {
  it("answers 502, not a generic 500", async () => {
    const res = await refusing()(post({}));
    assert.equal(res.status, 502);
    assert.deepEqual(await res.json(), {
      code: "model_unavailable",
      error: "model unavailable",
    });
  });

  it("reports the failure as its own signal", async () => {
    let reported: unknown;
    await refusing((error) => {
      reported = error;
    })(post({}));
    assert.ok(reported instanceof Error, "the failure was not reported");
    assert.equal(reported.name, "GatewayInternalServerError");
  });

  it("still lets a non-gateway failure 500 loudly", async () => {
    // A server bug must not be absorbed as an upstream refusal — the same
    // reasoning as the transcript-shape parse in ADR 0008.
    const broken = createAdvanceSessionHandler({
      secret: SECRET,
      verifyCaller: signedIn,
      advance: async () => {
        throw new Error("a server bug");
      },
    });
    await assert.rejects(broken(post({})), /a server bug/);
  });

  it("never puts the gateway's message in the response body", async () => {
    const res = await refusing()(post({}));
    const body: unknown = await res.json();
    assert.ok(
      !JSON.stringify(body).includes("moonshotai/kimi-k2"),
      "the response echoed gateway internals to the client",
    );
  });

  it("reports even when nothing is listening, without failing the round", async () => {
    // onFailure is optional; a deployment without PostHog still gets its 502.
    const res = await refusing()(post({}));
    assert.equal(res.status, 502);
  });
});
