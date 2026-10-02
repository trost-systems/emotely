/**
 * Reads back whether the gateway actually honored the privacy filters that
 * `session-core.ts` sends on every round, and how much routing headroom the
 * model has left once non-qualifying providers are filtered out.
 *
 * Why this exists (issue #98): `disallowPromptTraining` and `zeroDataRetention`
 * both fail *closed* — the gateway rejects the request outright when no
 * eligible provider serves the model. That turns the qualifying provider set
 * into a hard model-selection constraint (ADR 0003 amendment 2026-09-15), and
 * the monthly benchmark had no idea: it ranked candidates on latency and cost
 * and could put a model on top that cannot serve a single session.
 *
 * The gateway reports this in two places, both used here because they answer
 * different questions:
 *
 * - `enabledZeroDataRetention` / `enabledDisallowPromptTraining` — booleans
 *   confirming the filters were *understood and applied*. They matter because
 *   `GatewayProviderOptions` carries an index signature, so a misspelled key
 *   type-checks, is forwarded verbatim and is silently ignored. A round that
 *   comes back without these is a round with no privacy filtering at all.
 * - `routing.skippedProviderAttempts` — which providers were dropped, and why
 *   (`zdr_not_supported`, `zdr_ineligible_model`). This is what turns a binary
 *   "does it serve?" into "how much fallback is left?".
 *
 * Measured live on 2026-09-15 across all twelve benchmark candidates: every one
 * of them serves under both flags, so the feared outright failure does not hit
 * the current shortlist. What it *did* surface is thinner: eight of the twelve
 * are left with a single qualifying provider, and a fail-closed filter over one
 * provider means any outage or a withdrawn agreement takes every session down.
 * That is the fragility this module scores, not just the outright rejection.
 */

import { SESSION_PROVIDER_OPTIONS } from "./session-core.ts";

/** A fail-closed rejection names ZDR or prompt training; nothing else does. */
const PRIVACY_REJECTION =
  /zero data retention|\bZDR\b|prompt training|disallowPromptTraining/i;

/**
 * The gateway's own confirmation keys on `providerMetadata.gateway`. Named
 * constants rather than inline literals: these are the gateway's wire contract,
 * and a silent rename on their side should be greppable from one place.
 */
const ZDR_CONFIRMED_KEY = "enabledZeroDataRetention";
// Not a credential: this is the literal field name the AI Gateway returns on
// providerMetadata.gateway. It only trips the entropy heuristic because it is a
// long camelCase identifier, so the rule is suppressed for this line alone.
// biome-ignore lint/security/noSecrets: gateway response field name, not a secret
const NO_TRAINING_CONFIRMED_KEY = "enabledDisallowPromptTraining";

export type ProviderQualification = {
  /** False when the gateway refused the request under the privacy filters. */
  served: boolean;
  /** The gateway confirmed it applied the retention filter. */
  zeroDataRetention: boolean;
  /** The gateway confirmed it applied the training opt-out. */
  disallowPromptTraining: boolean;
  /** Providers left after filtering — the real fallback pool. */
  qualifyingProviders: number;
  /** Providers the gateway considered before filtering. */
  consideredProviders: number;
  /** `provider:reason` for each provider the filters removed. */
  disqualified: string[];
};

type SkippedAttempt = { provider?: unknown; reason?: unknown };

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null
    ? (value as Record<string, unknown>)
    : undefined;
}

function countedList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

/**
 * Parse one round's `providerMetadata.gateway` into a qualification verdict.
 * Anything missing is read as "not confirmed" rather than assumed fine: the
 * whole point is to catch a filter that silently did not apply.
 */
export function qualificationFromMetadata(
  gateway: unknown,
): ProviderQualification {
  const meta = asRecord(gateway);
  const routing = asRecord(meta?.["routing"]);
  const skipped = countedList(routing?.["skippedProviderAttempts"]);

  const disqualified = skipped.map((entry) => {
    const s = (asRecord(entry) ?? {}) as SkippedAttempt;
    return `${String(s.provider ?? "unknown")}:${String(s.reason ?? "unknown")}`;
  });

  // `fallbacksAvailable` lists the alternates behind the resolved provider, so
  // the pool that actually served the request is that list plus the resolved
  // one. Skipped attempts are reported separately and are already excluded.
  const resolved = routing?.["resolvedProvider"] === undefined ? 0 : 1;
  const qualifyingProviders =
    routing === undefined
      ? 0
      : countedList(routing["fallbacksAvailable"]).length +
        resolved -
        disqualified.length;

  return {
    served: true,
    zeroDataRetention: meta?.[ZDR_CONFIRMED_KEY] === true,
    disallowPromptTraining: meta?.[NO_TRAINING_CONFIRMED_KEY] === true,
    qualifyingProviders: Math.max(0, qualifyingProviders),
    consideredProviders: Math.max(0, qualifyingProviders) + disqualified.length,
    disqualified,
  };
}

/**
 * Classify a thrown error as a privacy-filter rejection, or `undefined` if it
 * is something else. Returning `undefined` matters: a 503 or a malformed tool
 * call is an infrastructure blip the benchmark retries, and mislabeling one as
 * a privacy failure would quietly disqualify a perfectly good model.
 */
export function qualificationFromError(
  error: unknown,
): ProviderQualification | undefined {
  if (!PRIVACY_REJECTION.test(String(error))) {
    return;
  }
  return {
    served: false,
    zeroDataRetention: false,
    disallowPromptTraining: false,
    qualifyingProviders: 0,
    consideredProviders: 0,
    disqualified: [],
  };
}

/**
 * Minimum qualifying providers for a model to be a defensible default.
 *
 * Two, not one: the filters fail closed, so a model down to a single
 * qualifying provider has no fallback left — one provider outage, or one
 * withdrawn Vercel agreement, and every session fails rather than degrades.
 * The current default (`openai/gpt-oss-120b`, 8/8 measured 2026-09-15) clears
 * this comfortably; eight of the twelve benchmark candidates do not.
 */
const MIN_QUALIFYING_PROVIDERS = 2;

/**
 * The ineligibility reason for this model's provider qualification, or
 * `undefined` when it is fit to be the default.
 */
export function qualificationReason(
  qualification: ProviderQualification,
): string | undefined {
  if (!qualification.served || qualification.qualifyingProviders === 0) {
    return "no provider qualifies under ZDR + no-prompt-training";
  }
  if (
    !(qualification.zeroDataRetention && qualification.disallowPromptTraining)
  ) {
    return "gateway did not confirm ZDR + no-prompt-training";
  }
  if (qualification.qualifyingProviders < MIN_QUALIFYING_PROVIDERS) {
    // Fail-closed over a single provider: one outage or one withdrawn
    // agreement and every session fails. Not a defensible default.
    return `only ${qualification.qualifyingProviders} of ${qualification.consideredProviders} providers qualify (no fallback headroom)`;
  }
}

/** The smallest possible probe: one token is enough to make the gateway plan. */
const PROBE_MAX_OUTPUT_TOKENS = 8;
const PROBE_PROMPT = "Reply with OK.";

type ProbeResult = { providerMetadata?: unknown };
type Probe = (opts: {
  model: string;
  prompt: string;
  maxOutputTokens: number;
  providerOptions: typeof SESSION_PROVIDER_OPTIONS;
}) => Promise<ProbeResult>;

/**
 * Measure one model's provider qualification with a single cheap round.
 *
 * The probe deliberately reuses `SESSION_PROVIDER_OPTIONS` — the very constant
 * the product sends — rather than restating the flags. A probe run under
 * different options would measure a routing decision that no real session ever
 * makes, which is exactly the gap issue #98 is closing.
 *
 * `generateText` is injected so the classification is unit-testable without a
 * network round; the benchmark passes the real one.
 */
export async function measureQualification(
  model: string,
  probe: Probe,
): Promise<ProviderQualification> {
  try {
    const result = await probe({
      model,
      prompt: PROBE_PROMPT,
      maxOutputTokens: PROBE_MAX_OUTPUT_TOKENS,
      providerOptions: SESSION_PROVIDER_OPTIONS,
    });
    const metadata = asRecord(result.providerMetadata);
    return qualificationFromMetadata(metadata?.["gateway"]);
  } catch (error) {
    const rejected = qualificationFromError(error);
    if (rejected === undefined) {
      // Not a privacy rejection — a 503, a bad key, a missing model. Let the
      // benchmark treat it as the crash it is rather than silently scoring it.
      throw error;
    }
    return rejected;
  }
}

/** The report cell: qualifying / considered, or why there is no number. */
export function describeQualification(
  qualification: ProviderQualification | undefined,
): string {
  if (qualification === undefined) {
    return "—";
  }
  if (!qualification.served) {
    return "none";
  }
  return `${qualification.qualifyingProviders}/${qualification.consideredProviders}`;
}
