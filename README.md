# emotely

[![TestFlight internal](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Ftrost-systems%2Femotely%2Fstatus%2Fstatus.json&query=%24.ios.internal.label&label=TestFlight%20internal&logo=apple&color=blue)](https://github.com/trost-systems/emotely/commits/status)
[![Play internal](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Ftrost-systems%2Femotely%2Fstatus%2Fstatus.json&query=%24.android.internal.label&label=Play%20internal&logo=googleplay&color=blue)](https://github.com/trost-systems/emotely/commits/status)

A daily journaling app with an AI **companion** that walks you through a
structured reflection — walking a chosen question set — and produces a summarized
journal entry. This is a ground-up rebuild of the original emotely (a shipped
Flutter + Firebase app, sunset in early 2025) around a modern, tools-first AI
harness.

Three goals, held at once:

1. **Personal use** — I journal with it daily.
2. **Public AI-engineering showcase** — the agent service and the Flutter GenUI
   client are both open (MIT) and meant to be read.
3. **Fund spare-time work** — a 5€/month subscription with high margins.

## Decisions

The load-bearing decisions and their rationale live in [`docs/adr/`](docs/adr/):

1. [Monorepo](docs/adr/0001-monorepo.md) — agent + app + shared contract in one repo
2. [Tools-first harness](docs/adr/0002-tools-first-harness.md) — tool calls, not prompted JSON
3. [Model gateway + cost ceiling](docs/adr/0003-model-gateway-and-cost-ceiling.md) — provider-agnostic, cheap-model constraint
4. [PostHog observability stack](docs/adr/0004-posthog-observability-stack.md) — full bundle, no Sentry; in the app only after the user allows usage analytics
5. [Journal content privacy](docs/adr/0005-journal-content-privacy-mode.md) — content never recorded, metadata only (leak-tested)
6. [Flutter iOS + Android only](docs/adr/0006-flutter-ios-android-only.md) — no web, demand-driven expansion
7. [Protected `main`](docs/adr/0007-protected-main-for-autonomous-agents.md) — PR + CI gate, because agents write here
8. [Public endpoint abuse controls](docs/adr/0008-public-endpoint-abuse-controls.md) — signed transcripts, caps, WAF rate limit, budget ceiling
9. [Wire compatibility](docs/adr/0009-wire-compatibility.md) — additive changes, version gating, force-update, revert through the pipeline
10. [Supabase data layer](docs/adr/0010-supabase-data-layer.md) — app writes under RLS, agent only verifies the JWT, schema as code
11. [Public waitlist writes to Postgres](docs/adr/0011-public-waitlist-writes-to-postgres.md) — insert-only for the world, rate limits and the double-opt-in mail in triggers, no server in between
12. [Reuse the original store listings](docs/adr/0012-reuse-the-original-store-listings.md) — keep the existing Play record and its install base
13. [Fastlane release pipeline](docs/adr/0013-fastlane-release-pipeline.md) — match signing, ASC API key, TestFlight and the Play internal track from CI
14. [Explicit consent, append-only](docs/adr/0014-explicit-consent-as-an-append-only-record.md) — Art. 9 (2) (a) consent before the first session, every grant and withdrawal its own immutable row, wording versioned and CI-enforced; usage-analytics consent recorded as a second kind
15. [Lego package layering](docs/adr/0015-lego-package-layering.md) — utilities, features, app as glue; a pub workspace with melos, every gate per package and scoped to what changed
16. [Declarative routing with go_router](docs/adr/0016-declarative-routing-with-go-router.md) — each feature declares its own typed routes and the app mounts them, the auth guard as a redirect over the live bloc state, nothing as `extra`
17. [State management stays on bloc](docs/adr/0017-state-management-stays-on-bloc.md) — Riverpod weighed and deferred; four conditions reopen the decision
18. [Custom checks are engine rules first](docs/adr/0018-custom-checks-are-engine-rules-first.md) — ast-grep or analyzer rules before any program of our own; Rust prebuilt only as a last resort
19. [Onboarding before sign-up](docs/adr/0019-onboarding-before-sign-up.md) — a versioned list of typed steps on the device, sign-up last, the name asked (never taken from Apple or Google) and sent to the companion as `userContext`
20. [Localization per package](docs/adr/0020-localization-per-package.md) — gen-l10n ARB files owned by each package that shows text, composed by the app; design_system components word their own chrome; literal UI strings an analyzer error; German first

The project's language is defined in [`CONTEXT.md`](CONTEXT.md).

## Architecture

Monorepo. Two apps that share one contract, plus Supabase (data/auth) and
PostHog (analytics + the self-driving loop).

```
emotely/
├─ apps/
│  ├─ agent/      TypeScript · Vercel AI SDK agent loop · deploys to Vercel
│  │             tools: ask_question / record_answer / complete_session
│  │             evals/ — offline fixtures → cost + quality (CI gate)
│  ├─ mobile/     a pub workspace (melos): the Flutter client and its packages
│  │  ├─ app/               the glue: composes the features · iOS + Android
│  │  └─ packages/
│  │     ├─ utility/        depend only on utilities: analysis (the rule set), contract
│  │     │                  (the tool-call shapes), agent_client, analytics, the three
│  │     │                  repositories (journal, consent, profile), supabase_schema
│  │     │                  (the generated tables), design_system (theme and
│  │     │                  shared widgets), legal_links, feedback_link, testing
│  │     │                  (shared test support)
│  │     └─ feature/        depend only on utilities, never on each other: feature_auth,
│  │                        feature_journal (home), feature_session, feature_account
│  │                        (the More tab, the profile, the account, the consent
│  │                        gate), feature_onboarding (the steps before sign-up);
│  │                        each
│  │                        reaches the others only
│  │                        through a navigator the app implements with its
│  │                        go_router route table
│  └─ web/        Jaspr (Dart) · getemotely.com landing page + waitlist · static, deploys to Vercel
├─ packages/
│  └─ contract/   the tool-call schema — single source of truth for both sides
├─ ast-grep/     custom checks as ast-grep rules + their tests (ADR 0018) · the tripwire:
│                no workaround comments, no suppression without a reason · the
│                architecture rules: defines read only in an app's environment file
├─ supabase/     Postgres schema + RLS tests (pgTAP) + auth config · deploys on merge
└─ README.md
```

### Why a monorepo

The agent and the app are two halves of one product joined by **one contract**:
the agent emits tool calls, the app renders a native widget per call. That shared
schema (`packages/contract`) must never drift between producer and consumer — in a
monorepo a schema change plus both sides move in one atomic, CI-verified commit.
Solo founder → one CI, one release story, one front door. Both repos are public
anyway, so the usual "keep one half private" argument doesn't apply.

Tooling stays boring: pnpm workspaces for the TS side, a pub workspace plus
melos for `apps/mobile` ([ADR 0015](docs/adr/0015-lego-package-layering.md)),
path-filtered GitHub Actions. No Nx/Turbo/Bazel.

### The stack

| Layer | Choice | Why |
|---|---|---|
| **Client** | Flutter, iOS + Android only (no web) | Native GenUI story; VGV/Flutter-community audience |
| **Agent runtime** | TypeScript · Vercel AI SDK · Vercel | Tools-first agent loop, streaming, the AI-eng showcase |
| **Model access** | Vercel AI Gateway | Swap models via config (bare `creator/model` strings); 0% fees; benchmarked monthly |
| **Data + auth** | Supabase (Postgres + Auth) | Fresh schema, no Firebase baggage |
| **Observability** | PostHog (full bundle, see below) | LLM obs, flags, experiments, error tracking, Max AI |
| **Subscriptions** | RevenueCat | Known quantity from the original app |
| **License** | MIT, both apps | Portfolio-friendly, maximally reusable |

### Tool-calling replaces the old JSON hack

The original assistant ran on the Firebase GenAI Chatbot extension: a ~2KB prompt
that *begged* the model to emit parseable JSON (`response` + `summary`), with a
"recovery prompt" retry when the JSON didn't parse. That's fighting the model.

The rebuild gives the model **tools** instead:

- `ask_question(question, answer_type)` — `answer_type ∈ text_list | longtext | rating | emoji | color`; the client renders the matching native widget and supplies the answer as the tool result. **This is the generative UI.**
- `record_answer(question, value)` — structured, validated tool args, typed per answer type. No JSON-parsing prayer.
- `complete_session(summary)` — the summary is a validated tool argument, not parsed prose.

The old `ColorText` / `ColorTextEditingController` feature becomes just one
`answer_type` (`color`).

## PostHog — the "self-driving" layer

Adopted day one (all free at our scale, ~0€ at 1k MAU):

- **Product analytics** — `posthog_flutter` (app) + `posthog-node` (agent). In the app, only
  after the user allows usage analytics (ADR 0004 amendment 2026-09-26).
- **AI Observability** — `@posthog/ai` with `experimental_telemetry` on AI SDK
  calls → `$ai_generation` events (tokens, cost, latency, traces per model).
  **content recording OFF at the source** (`recordInputs`/`recordOutputs`
  false; a CI leak test proves no journal text reaches spans). Only metadata
  is captured. Non-negotiable for a journaling app.
- **Feature flags + experiments** — a flag payload `{ model, prompt }` drives
  **server-side model selection** in the agent, no deploy. PostHog's **LLM prompt
  experiments** auto-attribute cost + quality per variant.
- **Error tracking** — native PostHog exception tracking. **No Sentry.**
- **Max AI + anomaly alerts** — agentic analyst that watches AI-cost-per-user and
  session-completion and pings on drift. This is the self-driving watchdog.
- **Surveys** — added for the beta (2026-09-18): event-triggered popovers for
  structured questions, alongside the mailto feedback row
  ([ADR 0004](docs/adr/0004-posthog-observability-stack.md)).
- **Session replay** — deferred (only with mask-all-text, given sensitive
  journal content).

**The self-driving loop:** PostHog flag hands the agent `{model, prompt}` →
`@posthog/ai` emits cost/latency per variant → LLM prompt experiment attributes
cost + quality per variant → Max AI / anomaly alerts flag drift. The product tunes
its own model choice; you get pinged instead of dashboard-staring.

Set **billing limits / spike protection** per product on day one — a retry storm
must not surprise-bill.

## Cost model (the constraint) and model choice

A daily poweruser (~30 sessions/month, ~10 questions each) must cost
**≤ €1/month** (≈ $0.036/session) inside a 5€ subscription — margins are fine at
that level. Within that ceiling, **the fastest reliable model wins**: GenUI
latency is what the user feels between widgets, so models are ranked by median
per-round latency with cost as the tiebreak. We start reliable and fast, and
optimize toward cheaper models with real usage data.

- The cheap tier (Qwen/GLM/DeepSeek flash-class, Gemini Flash-Lite) runs a full
  session for well under a cent — ~10¢/month.
- Haiku-class and small frontier tiers (e.g. GPT-5.6 Luna at $0.20/M input) are
  eligible candidates, not excluded.
- **Prompt caching** needs no code — every gateway candidate is implicitly
  cached, and the win is the growing conversation prefix across ~25 rounds.
  It is measured per model, not assumed.
- The task is narrow and well-specified (a fixed question set, extract →
  summarize) — good tool calling matters more than frontier reasoning.

The model is chosen **empirically** by the benchmark (`pnpm --filter
@emotely/agent benchmark`): eligible = protocol eval 3/3, every behavior
scenario 2-of-3, within budget. A monthly workflow re-runs it and opens an issue
with the ranking plus any new tool-capable models in the gateway catalog. See
[ADR 0003](docs/adr/0003-model-gateway-and-cost-ceiling.md).

## Two layers of evaluation

1. **Offline evals** (`apps/agent/evals/`) — deterministic fixtures replayed
   against each candidate model. The CI gate; catches regressions before ship.
   Seed from the original app's `promptfoo` conversation fixtures.
2. **Online experiment** (PostHog) — real sessions, real cost, live variant
   comparison. The self-driving loop.

Offline proves *correct + cheap in the lab*; online proves *cheap + retained in
the wild*.

## Build order

1. **`apps/agent` skeleton** — Vercel AI SDK loop, the three tools, gateway wired,
   one cheap model hardcoded. Prove a full 10-question session runs end-to-end via
   tool calls. No client yet.
2. **Offline eval harness** — port the original prompt + `promptfoo` conversation
   fixtures into `evals/`. CI gate: replay, assert correctness, measure cost per
   candidate.
3. **Benchmark** — rank candidates on latency within the cost ceiling; pick the
   fastest reliable one. Gateway decided: Vercel AI Gateway (ADR 0003 amendment).
4. **PostHog online** — OTel span processor (content recording off), flag-driven model
   selection, first LLM prompt experiment.
5. **`apps/mobile/app`** — Flutter shell rendering a widget per tool call, Supabase auth +
   entry persistence, `posthog_flutter`.
6. **Subscription + polish** — RevenueCat, paywall, ship to TestFlight.

## Setting up a machine

One script brings a fresh Linux box — a cloud agent container, a VM, a CI
runner — to where every job in `.github/workflows/ci.yml` runs locally:

```bash
sudo scripts/setup-dev-environment.sh            # install
sudo scripts/setup-dev-environment.sh --verify   # install, then run every CI job
```

It wants root on x86_64 and installs into a system prefix, which is what a
container is; it is not a dotfiles-friendly installer for a personal laptop.
Docker must already be there (it starts the daemon, it does not install
Engine) or the Supabase job is skipped — and the script says so rather than
claiming a clean run.

It is idempotent, it aborts on the first failed step, and it takes **every
version from the repository** — Node from `.nvmrc`, pnpm from `packageManager`,
Flutter from `apps/mobile/app/.fvmrc`, Dart from the checksum-pinned
`apps/web/scripts/vercel-install.sh`, the Supabase CLI, `jaspr_cli`, `melos`
and `very_good_cli` from `.github/workflows/ci.yml`. Bumping a pin means editing the file that owns it;
the script follows, and refuses to run when two files pin the same tool
differently. Every download is checked against a checksum the upstream project
publishes, fetched at run time.

The toolchain lands in `/opt/emotely-toolchain` (uninstall is `rm -rf` of that
one directory) and `/opt/emotely-toolchain/env.sh` puts it on `PATH`. Two Dart
SDKs live there on purpose: `dart` is the standalone SDK `apps/web` is pinned
to, and `flutter-dart` is Flutter's bundled one — the only one that can resolve
`sdk: flutter` packages, so it is what `apps/mobile/app` uses wherever CI says `dart`.

What it deliberately leaves out, and prints when it finishes: secrets (it
writes an empty `apps/agent/.env.local` template and stops there), Entire —
whose hooks in `.claude/settings.json` no-op while the CLI is absent, so
commits made on such a machine carry no `Entire-Checkpoint` trailer — `fvm`,
the GitHub CLI, and everything needed to run the app on a device (no Android
SDK, no JDK, no emulator, no Xcode, so the android half of `app-release.yml`
is out of reach too). `apps/mobile/app`'s unit and widget tests do run.

## Running the app

Build-time configuration is `--dart-define`s read in `apps/mobile/app/lib/app/environment.dart`
(agent URL, PostHog token — empty means analytics and error tracking off;
uncaught-error autocapture is off in debug builds regardless). How to build, run,
drive the app on a simulator, and run the on-device acceptance session is an
agent skill: [`.claude/skills/run-app`](.claude/skills/run-app/SKILL.md). Its
CLI (`scripts/run-app.sh up`) sets a debug build up on a simulator, signed in,
for an agent to drive with plain [marionette](https://github.com/leancodepl/marionette_mcp)
commands, then collects an evidence bundle: screenshots, a video, logs and
PostHog events.

## Verify-at-build-time (do NOT pin from memory)

Per project convention, research the latest before pinning:

- Vercel AI SDK, `@posthog/ai`, `posthog-node`, `posthog_flutter` versions.
- Current GLM and Gemini Flash-Lite model IDs (note: "GLM 5.2" does not exist —
  current is the GLM-4.x line; confirm exact version).

## Legacy

The original app lives at `~/dev/emotely-legacy` (Flutter + Firebase, sunset early
2025). Worth cherry-picking, not migrating: the context/opening/recovery prompt
design, the `promptfoo` conversation fixtures, the `ColorText` idea, and the strong
accessibility bar (a11y tests for every view). Everything else — the Firebase
GenAI extension, the JSON-recovery hack, Firestore, Sentry, the web target — is
gone.
