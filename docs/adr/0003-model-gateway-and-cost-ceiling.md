# Route models through a gateway, under a hard cost ceiling

The agent calls its LLM through a **provider-agnostic gateway**, not a direct
provider SDK. This lets us swap models with a config/flag change and benchmark
candidates on real sessions. The gateway pattern is settled; the specific vendor is
deferred (see below).

## The constraint that drives model choice

A daily poweruser (~30 sessions/month, ~10 topics each) must cost **well under
50¢/month**, ideally a few cents, inside a 5€/month subscription with high margins.

- Frontier models (Claude Sonnet/Opus): out — blow the budget per session.
- Haiku-class: borderline (~$1.50–2.70/mo).
- Gemini Flash-Lite / GLM-4.x-class: a few cents to ~60¢/mo — the only tier that
  reliably hits "a few cents."
- Prompt caching on the static context prompt cuts session cost 3–5× and matters
  more than the exact model.

The task is narrow and well-specified (10 fixed topics, extract → summarize), so a
cheap model with good tool-calling is sufficient; no frontier reasoning is needed.
The final model is chosen **empirically** via the offline eval harness plus a
PostHog LLM prompt experiment — never pinned from memory.

## Deferred: which gateway

OpenRouter vs Vercel AI Gateway. Both work with the Vercel AI SDK and with PostHog
AI Observability. Deciding criterion: integration cleanliness — OpenRouter has a
*dedicated* PostHog install path; Vercel AI Gateway is listed as "supported." The
specific vendor is chosen at build step 3, after understanding the concrete
differences (routing, failover, caching, billing) — not yet decided.

## Amendment 2026-08-22: gateway decided, ceiling revised

**Gateway: Vercel AI Gateway.** The deferral's deciding criterion ("OpenRouter
has a dedicated PostHog install path") did not survive the AI SDK v7 research:
PostHog's supported v7 path is an OpenTelemetry span processor that instruments
the SDK, not the provider, so observability is gateway-agnostic — and the
"dedicated" OpenRouter path is an OpenAI-client wrapper that would force us off
`generateText`. What remains is fees: Vercel AI Gateway charges 0% on tokens and
0% on BYOK; OpenRouter 5.5% on credits and 5% on BYOK. Lock-in is one env var
plus bare `creator/model` strings either way.

**Ceiling: ≤ €1/month per daily poweruser (≈ $0.036/session at 30 sessions),
and within that, the fastest reliable model wins.** Margins inside a €5
subscription are fine at that level, and GenUI latency is what the user feels
between widgets. This replaces "well under 50¢, frontier out": Haiku-class and
the small frontier tiers (e.g. GPT-5.6 Luna at $0.20/M in) are eligible
candidates, ranked by median per-round latency with cost as tiebreak. We start
reliable and fast, and optimize toward cheaper models with real usage data.

**Caching needs no code.** Every gateway candidate is implicitly cached; the
win is the growing conversation prefix across ~25 rounds, not just the static
prompt. Measured, not assumed: the first live reading for glm-4.7-flash was
`cached=0` despite its catalog tag.

Selection is re-run monthly by a scheduled benchmark that also lists new
tool-capable models from the live catalog (issue #4).

**2026-08-23 benchmark outcome:** `openai/gpt-oss-120b` is the default — the
only candidate near 600 ms p50 (runners-up `gpt-5.6-luna-fast`, `gpt-5-nano`,
`gpt-5.6-luna` sit at 1.1–1.2 s), ~$0.11/month, 97% cache hits, clean
behavior scores once the session loop refused `complete_session` with an
asked-but-unrecorded answer (a protocol gap the benchmark exposed). The
previous default `zai/glm-4.7-flash` failed protocol or behavior in every
run. Haiku 4.5 and Gemini 3.7 Flash pass everything but exceed the ceiling
without explicit cache markers, and are 3× slower.

## Amendment 2026-09-15: no prompt training, no provider retention

Every model round sends `providerOptions.gateway.disallowPromptTraining: true`
and `zeroDataRetention: true` (`roundSettings()` in `session-core.ts`).

**Why.** A journal transcript is special-category data under GDPR Art. 9
(health, emotions, relationships). The gateway does not train on prompts
itself, but by default it does not route on the *providers'* training policies,
and a provider whose stance is unknown is assumed to train. Without the opt-in
the privacy notice cannot name a safeguard for the transfer under Art. 13(1)(f)
and cannot promise the data is not trained on. `disallowPromptTraining`
"[r]estricts routing to providers that have agreements with Vercel for AI
Gateway to not use prompts for model training"; `zeroDataRetention`
"[r]estricts routing to providers with zero data retention agreements with
Vercel for AI Gateway" — retention, not just training.

**The two are not independent guarantees; setting both is defense in depth.**
Vercel is explicit that "ZDR is a superset of this control. If you enable ZDR,
training opt-out is already covered"
([ZDR on AI Gateway](https://vercel.com/blog/zdr-on-ai-gateway), read
2026-09-15). So `disallowPromptTraining` adds no coverage on top of ZDR today.
It is set anyway because they are separate request flags with separate
eligibility sets: if ZDR ever has to be dropped — a plan change, or a model
whose providers offer no ZDR agreement — the training opt-out must not vanish
with it. The weaker, more widely supported filter is the one we would still be
standing on, so it is stated explicitly rather than inherited.

**Routing consequence: none measured, but both filters fail closed.** The
gateway rejects the request outright when no eligible provider exists for the
model, so a bad interaction here breaks every session rather than degrading
quietly. Measured live on 2026-09-15 against `openai/gpt-oss-120b`: all eight
providers that serve it (baseten, fireworks, bedrock, togetherai, nebius,
parasail, groq, cerebras) satisfy *both* filters, so the fallback set is
unchanged and ZDR costs no availability. The gateway said so in its own
routing metadata — "ZDR requested: all 8 attempts support ZDR … Disallow
prompt training requested: all 8 attempts disallow prompt training".

**This is now a model-selection constraint.** The monthly benchmark (#4) and
the `agent-model` flag can both change the default model, and a model whose
providers do not all qualify would fail closed on every round. Re-measure the
qualifying provider set before promoting a new default, not after.

**Cost: no token surcharge**, and the ceiling is untouched — routing among
equally-priced providers for the same model. There is a *plan* dependency,
though: request-level ZDR is available only to Vercel Pro and Enterprise
teams. That is not a new bill (the team is on Pro and must stay there while
the app is in front of testers), but it does mean a downgrade would start
failing every session rather than silently loosening privacy — which is the
safer failure, and one more reason not to downgrade.

## Amendment 2026-09-15 (b): the benchmark measures provider qualification

The previous amendment made the qualifying provider set a model-selection
constraint but left the enforcement to a human reading a note. The monthly
benchmark — the thing that actually ranks candidates — did not know about it,
so it could put a model on top that cannot serve a single session (#98).

**It measures it now.** Every candidate gets one cheap probe round, sent with
the same `SESSION_PROVIDER_OPTIONS` constant the product uses, before any
protocol or scenario run. The verdict becomes an `ineligibilityReasons()` entry
and a **Providers** column in the generated report, so a non-qualifying model
can never top the table regardless of latency or cost.

**The gateway answers this directly**, which is better than the prose parsing
the first amendment relied on. `providerMetadata.gateway` carries
`enabledZeroDataRetention` and `enabledDisallowPromptTraining` — booleans
confirming the filters were understood and applied — and
`routing.skippedProviderAttempts` names each provider that was dropped, with a
reason (`zdr_not_supported`, `zdr_ineligible_model`). Reading the booleans also
closes the typo hole noted in `session-core.ts`: a misspelled option key
type-checks and is silently ignored, and a round that comes back without these
confirmations is a round with no privacy filtering at all.

**The measured picture, all twelve candidates, 2026-09-15.** The feared outcome
did not materialize: every candidate *serves* under both flags, including
`nvidia/nemotron-3.5-lightning`, the #1-ranked model from benchmark #30. So
promoting it would not have failed 100% of sessions.

What the measurement did surface is a thinner failure mode. Only three
candidates keep a deep qualifying pool — `openai/gpt-oss-120b` 8/8,
`deepseek/deepseek-v4-flash` 7/9, `anthropic/claude-haiku-4.5` 4/4 — while
`nemotron` drops to 2 of 3 (`runinfra` skipped, `zdr_not_supported`) and **eight
of the twelve are left with a single qualifying provider**: `qwen3.7-flash`,
`glm-4.7-flash`, `gemini-2.5-flash-lite`, `gemini-3.7-flash`, `gpt-5-nano`,
`gpt-5-mini`, `gpt-5.6-luna`, `gpt-5.6-luna-fast`.

**Hence a floor of two qualifying providers.** Under a fail-closed filter, one
provider is a single point of failure for the whole product: one outage, or one
withdrawn Vercel agreement, and every session fails rather than degrades. A
model at 1/N is disqualified no matter how fast or cheap it is. The current
default clears this comfortably at 8/8.

**Outright rejection is real, just not on the shortlist.** Sampling the wider
catalog found models the gateway refuses under these flags —
`arcee-ai/trinity-large-thinking` ("No ZDR … providers … available"), and
`anthropic/claude-fable-5` / `-5.1`, which are ZDR-ineligible as models. Those
return HTTP 400, so the benchmark classifies a privacy rejection as
ineligibility and rethrows anything else rather than blaming privacy for a 503.

**Still not guarded: the deploy path.** `EMOTELY_MODEL` is a Vercel environment
variable read in `api/advance-session.ts` — outside the repo and outside CI —
so changing it still bypasses every check here. A startup probe was considered
and deliberately deferred: the endpoint is a per-request serverless function,
so a live gateway round at cold start would add latency to the metric we rank
on and would turn a transient gateway blip into an outage of the whole
endpoint. The better shape is a deploy-time or scheduled smoke check, decided
on its own (follow-up to #98).
