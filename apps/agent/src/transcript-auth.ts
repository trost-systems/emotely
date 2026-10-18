import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * The transcript is client-held but server-authoritative: every response is
 * signed, and only transcripts carrying a valid signature advance. This is
 * what keeps an open, unauthenticated endpoint from being a generic LLM
 * proxy — the only client-authored content in a session is the widget
 * answer, which enters as a tool result (data, never instructions).
 *
 * What is signed is the transcript's canonical JSON, not the JSON it happened
 * to be sent as: the app keeps an unfinished session in a Postgres `jsonb`
 * column (ADR 0010), which does not preserve the order of object keys, so a
 * resumed transcript comes back with the same values in a different order.
 */
export function signTranscript(transcript: unknown, secret: string): string {
  return createHmac("sha256", secret)
    .update(canonicalJson(transcript))
    .digest("base64url");
}

/**
 * [value] as JSON with every object's keys sorted, so two encodings of the
 * same data serialize alike. Normalized through `JSON.stringify` first, so a
 * key holding `undefined` is dropped here exactly as it is on the wire.
 */
function canonicalJson(value: unknown): string {
  // TypeScript's lib types the result as `string`, but `undefined`, a
  // function or a symbol stringify to `undefined`, which `JSON.parse` throws on.
  const json: string | undefined = JSON.stringify(value);
  return JSON.stringify(sortedKeys(JSON.parse(json ?? "null")));
}

function sortedKeys(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortedKeys);
  }
  if (value === null || typeof value !== "object") {
    return value;
  }
  const entries = Object.entries(value).sort(([a], [b]) => (a < b ? -1 : 1));
  return Object.fromEntries(entries.map(([key, v]) => [key, sortedKeys(v)]));
}

/** Constant-time comparison against one secret; malformed signatures are false. */
function matchesSecret(
  transcript: unknown,
  signature: string,
  secret: string,
): boolean {
  const expected = Buffer.from(signTranscript(transcript, secret));
  const provided = Buffer.from(signature);
  return (
    expected.length === provided.length && timingSafeEqual(expected, provided)
  );
}

/**
 * Constant-time verification against the current secret and, during a
 * rotation, the previous one (ADR 0009 rule 5). Signing always uses the
 * current secret, so a transcript accepted under the previous one migrates
 * on its next round. Never throws.
 *
 * Both comparisons always run, and only then are the results combined: an
 * `||` between the two calls would stop after a current-secret match, so the
 * response time would reveal which secret a signature was made with (one
 * HMAC + compare versus two). With both evaluated unconditionally the work
 * is the same for every input that reaches this function. An empty
 * previous secret counts as unset, so an env var left as "" cannot open the
 * endpoint to signatures under the empty key.
 */
export function verifyTranscript(
  transcript: unknown,
  signature: string,
  secret: string,
  previousSecret?: string,
): boolean {
  const current = matchesSecret(transcript, signature, secret);
  const previous =
    previousSecret === undefined || previousSecret === ""
      ? false
      : matchesSecret(transcript, signature, previousSecret);
  return current || previous;
}
