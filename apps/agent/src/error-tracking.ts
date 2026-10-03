import type { PostHog } from "posthog-node";

/**
 * Server-side error tracking (ADR 0004: PostHog, no second vendor), held to
 * the same content-free rule as the client (ADR 0005).
 *
 * **Why the rule is applied here and not on the wire.** The Flutter side can
 * scrub in a `beforeSend` hook (`apps/mobile/app/lib/analytics/error_tracking.dart`).
 * `posthog-node` has no such seam — its options type is
 * `Omit<PostHogCoreOptions, 'before_send' | …>`, so `before_send` is removed
 * on purpose — and it walks `error.cause` into `$exception_list` when it
 * builds the event. The only place left to hold the line is the call site, so
 * an exception is converted to something content-free *before* it is handed
 * to the SDK, never handed over and filtered afterwards.
 *
 * **The leak this closes, measured live 2026-09-15.** A gateway rejection
 * arrives as a `GatewayError` whose `cause` is an `APICallError` carrying
 * `requestBodyValues.prompt[0].content[0].text` — the journal transcript,
 * verbatim. Reporting that error as it stands hands PostHog the cause chain;
 * `responseBody` on the same object is whatever the upstream chose to echo.
 * So the cause chain is dropped and only an allowlisted `message` survives.
 *
 * **Stack traces are kept**, including the source context PostHog attaches to
 * each frame by reading the file the frame names. That context is this
 * repository's own source, and it is what makes a report actionable. The
 * transcript never appears in a frame — it travels in the cause, which is
 * exactly what is dropped above.
 */

/**
 * Error types whose `message` is the gateway's own words about routing and
 * can never quote the prompt: the abstract base's subclasses, as measured
 * against the live gateway. Everything else — `APICallError` above all,
 * whose text is a raw upstream response body — is withheld.
 */
export const FORWARDED_ERROR_TYPES: ReadonlySet<string> = new Set([
  "GatewayAuthenticationError",
  "GatewayFailedDependencyError",
  "GatewayForbiddenError",
  "GatewayInternalServerError",
  // The next line is a class name from @ai-sdk/gateway, flagged only for its
  // length and mixed case. There is no secret here: the entropy heuristic
  // cannot tell a CamelCase identifier from a token.
  // biome-ignore lint/security/noSecrets: a gateway error class name, not a secret
  "GatewayInvalidRequestError",
  "GatewayModelNotFoundError",
  "GatewayNotFoundError",
  "GatewayRateLimitError",
  "GatewayResponseError",
]);

/**
 * This service's own error types whose message is built from a fixed
 * vocabulary — a step, a status and an upstream's closed error code — and so
 * can never hold content: Apple's refusals and Supabase's (#193). Forwarded
 * like the gateway's, but never classified as a gateway failure.
 */
const OWN_FORWARDED_ERROR_TYPES: ReadonlySet<string> = new Set([
  "AppleRequestError",
  "IdentityLookupError",
]);

/** The gateway's marker symbol; `GatewayError.isInstance` tests exactly this. */
const GATEWAY_ERROR_MARKER = Symbol.for("vercel.ai.gateway.error");

/**
 * The gateway's own words for "no provider satisfies the privacy filters".
 * Measured live 2026-09-15 against `moonshotai/kimi-k2`, which only novita
 * serves: `No ZDR (Zero Data Retention) providers or ZDR-attested BYOK
 * credentials available for model: … Providers considered: novita`, with
 * `cause.responseBody.error.type === "no_zdr_providers_available"`.
 *
 * The class is no help — that rejection arrives as
 * `GatewayInternalServerError` with `statusCode` 400 — so the discriminator
 * is the response type where it is available, and the message otherwise.
 * Both are the gateway's text, never the prompt's.
 */
const INELIGIBLE_RESPONSE_TYPES: ReadonlySet<string> = new Set([
  "no_zdr_providers_available",
  "no_prompt_training_providers_available",
]);
const INELIGIBLE_MESSAGE = /\bno\b[^.]*\bproviders?\b[^.]*\bavailable\b/i;

const HTTP_BAD_GATEWAY = 502;

/** What the session round failed on, in terms safe to put in a property. */
export type ModelFailure = {
  /**
   * `provider_ineligible` is the fail-closed privacy filter refusing to route
   * (ADR 0003 amendment): no provider for this model satisfies ZDR or the
   * training opt-out, so *every* session dies until the model or the plan
   * changes. `gateway_error` is any other gateway refusal.
   */
  kind: "provider_ineligible" | "gateway_error";
  /** The gateway's own status, for the report only — never the response. */
  upstreamStatus?: number;
  /** What the endpoint answers: upstream refused, so 502, not 500. */
  status: number;
};

function isGatewayError(error: unknown): error is Error {
  if (!(error instanceof Error)) {
    return false;
  }
  return GATEWAY_ERROR_MARKER in error || FORWARDED_ERROR_TYPES.has(error.name);
}

function responseErrorType(error: Error): string | undefined {
  const cause: unknown = (error as { cause?: unknown }).cause;
  if (!(cause instanceof Object)) {
    return;
  }
  const body: unknown = (cause as { responseBody?: unknown }).responseBody;
  if (typeof body !== "string") {
    return;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    // Not JSON — the gateway's shape is unknown, so fall back to the message.
    return;
  }
  const inner: unknown = (parsed as { error?: unknown }).error;
  const type: unknown = (inner as { type?: unknown } | undefined)?.type;
  return typeof type === "string" ? type : undefined;
}

/**
 * Classify a failed model round. `undefined` means "not the gateway" — a
 * server bug, which must keep 500ing loudly rather than be absorbed here
 * (the same reasoning as the transcript-shape parse in ADR 0008).
 */
export function classifyModelFailure(error: unknown): ModelFailure | undefined {
  if (!isGatewayError(error)) {
    return;
  }
  const upstream: unknown = (error as { statusCode?: unknown }).statusCode;
  const type = responseErrorType(error);
  const ineligible =
    type === undefined
      ? INELIGIBLE_MESSAGE.test(error.message)
      : INELIGIBLE_RESPONSE_TYPES.has(type);
  return {
    kind: ineligible ? "provider_ineligible" : "gateway_error",
    ...(typeof upstream === "number" ? { upstreamStatus: upstream } : {}),
    status: HTTP_BAD_GATEWAY,
  };
}

/**
 * An error reported without its message: [type] says what failed and
 * [statusCode] which way, while the text stays on this server because it may
 * quote the transcript (ADR 0005). The counterpart of the app's
 * `WithheldException`.
 *
 * What a debugger gives up is the upstream's sentence. The way back is to
 * reproduce with the ids the report carries, or to add a type to
 * [FORWARDED_ERROR_TYPES] once it is proven content-free for every value it
 * can take.
 */
export class WithheldError extends Error {
  override readonly name = "WithheldError";
  /** The type that failed — all that survives of the original. */
  readonly withheldType: string;
  readonly upstreamStatus: number | undefined;

  constructor(withheldType: string, detail: { statusCode?: number } = {}) {
    super(
      [withheldType, detail.statusCode]
        .filter((part) => part !== undefined)
        .join(" ")
        .concat(" (message withheld, ADR 0005)"),
    );
    this.withheldType = withheldType;
    this.upstreamStatus = detail.statusCode;
  }
}

/** Where the failure happened; a fixed vocabulary, never free text. */
export type ErrorContext = {
  /**
   * `session_round` is a model round; `apple_revocation` is revoking a
   * Sign in with Apple grant before an account is deleted (#193).
   */
  step: "session_round" | "apple_revocation";
  userId?: string;
  /** The configured model id — a config value, not user content. */
  model?: string;
};

/**
 * [error] as it may leave this process.
 *
 * The one thing that must not survive is the **cause chain**: a
 * `GatewayError`'s `cause` is an `APICallError` whose `requestBodyValues`
 * hold the prompt — the journal transcript — and PostHog walks `cause` into
 * `$exception_list`. So the error is rebuilt as a fresh `Error` with no
 * `cause` for PostHog to follow, rather than mutated: the original object is
 * still the caller's to rethrow.
 *
 * The **message** survives only for an allowlisted gateway type, whose text
 * is the gateway's own words about routing; anything else becomes a
 * [WithheldError].
 *
 * The **stack is kept**, with the source context PostHog attaches to each
 * frame. That context is this repository's own source, which is what makes a
 * report actionable — where the throw came from, and the frames around it.
 */
function contentFree(error: unknown): Error {
  if (!(error instanceof Error)) {
    return new WithheldError(typeof error);
  }
  const statusCode: unknown = (error as { statusCode?: unknown }).statusCode;
  const detail = typeof statusCode === "number" ? { statusCode } : {};
  if (
    !(
      FORWARDED_ERROR_TYPES.has(error.name) ||
      OWN_FORWARDED_ERROR_TYPES.has(error.name)
    )
  ) {
    const withheld = new WithheldError(error.name, detail);
    // Keep where it was thrown; only the text is withheld.
    withheld.stack = error.stack;
    return withheld;
  }
  const safe = new Error(error.message);
  safe.name = error.name;
  safe.stack = error.stack;
  return safe;
}

export type ReportError = (error: unknown, context: ErrorContext) => void;

/**
 * A reporter over an existing PostHog client (ADR 0004: one vendor, one
 * client). Fire-and-forget: `captureException` queues, and the caller flushes
 * inside `waitUntil` so a frozen function does not drop the event.
 * Observability must never break journaling, so a reporter that throws is
 * swallowed.
 */
export function createErrorReporter(client: PostHog): ReportError {
  return (error, context) => {
    const failure = classifyModelFailure(error);
    try {
      client.captureException(contentFree(error), context.userId, {
        step: context.step,
        ...(context.model === undefined ? {} : { model: context.model }),
        ...(failure === undefined
          ? {}
          : {
              failure_kind: failure.kind,
              ...(failure.upstreamStatus === undefined
                ? {}
                : { upstream_status: failure.upstreamStatus }),
            }),
      });
    } catch {
      // Reporting is best-effort; a session must not fail because of it.
    }
  };
}
