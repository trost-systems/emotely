---
name: run-app
description: How to run, drive and verify the Flutter app (apps/mobile/app) on an iOS simulator — run-app.sh sets it up signed in against the deployed agent, the agent drives it with plain marionette commands, and the CLI records and collects an evidence bundle (screenshots, video, logs, PostHog events); plus the performance budget (perf.sh: profile-mode frames, request counts and backend latency) and the performance survey on real phones in Firebase Test Lab (survey.sh: history, findings by severity), the on-device acceptance session and the unit gate. Use whenever asked to run the app, see a screen, find or reach the screen a report or screenshot is about (the feature map), verify a change on a device, collect an evidence bundle, run integration_test, or measure, debug or change the app's performance or the performance budget.
---

# Running apps/mobile/app

## Verify on the simulator

`scripts/run-app.sh` sets the app up signed in on a fresh simulator, you drive
it with plain `marionette` commands, and it collects the evidence.
Verifying a change on the simulator, or collecting its evidence — read
[references/verification.md](references/verification.md) first: up → drive →
collect → down, the worked example, the keys and parallel sessions.

## Find a screen

[references/feature-map.yaml](references/feature-map.yaml) lists every screen:
its route, how to reach it from the signed-in journal (the keys to tap, in
order), what it does, its bloc states, its keys, and what it looks like. Read
it first when a report names a screen or brings a screenshot: match the
screenshot against each entry's `looks`, then follow its `reach` with
marionette. A new route needs its entry in the same pull request; CI's
`ast-grep` job fails without it (`scripts/feature-map.sh`).

## Performance budget

The budget is `apps/mobile/app/integration_test/perf_budget.yaml`, over three
paths: the journal scroll, opening an entry and a session round.

- **On every app pull request:** the request counts, through the widget test
  `apps/mobile/app/test/perf/request_budget_test.dart`, in seconds.
- **Nightly:** frames at 60 fps and the deployed backend's latency, on
  emulators. It never blocks; whatever fails files the `performance` issue.
- **On a phone:** frames come from the performance survey below.

`scripts/perf.sh run` is the nightly's profile run, for measuring frames
locally on a fresh Android emulator. Measuring, reading a failure or
changing the budget — read
[references/performance.md](references/performance.md) first.

## Performance survey on real phones

`scripts/survey.sh` walks every screen of the feature map in profile mode on
real phones in Firebase Test Lab, on demand (a workflow run by hand, or
`survey.sh ftl`; no schedule), keeps
each run's numbers in a history (`survey.sh history --device a14m --screen
journal`) and files findings by severity as one issue per screen and metric.
Test Lab's daily quota is shared and small. Running it, reading the history,
fixing a finding, or touching the devices or severity rules — read
[references/performance-survey.md](references/performance-survey.md) first.

## Build-time configuration

All configuration is `--dart-define`s, read in one place: `lib/app/environment.dart`.

| define | default | purpose |
| --- | --- | --- |
| `EMOTELY_AGENT_URL` | `https://api.getemotely.com/api/advance-session` | the agent (production alias of the `emotely-agent` Vercel project); point at a local or preview deployment when needed |
| `POSTHOG_KEY` | empty = analytics off (the SDK skips setup) | PostHog project token (`phc_…`) |
| `EMOTELY_SUPABASE_URL` | the hosted project | Supabase project URL; public (ADR 0010) |
| `EMOTELY_SUPABASE_PUBLISHABLE_KEY` | the hosted project's key | Supabase publishable key; public, acts only under the signed-in user |
| `SMOKE_EMAIL` | none | debug builds only: the one address asked for a password (the CLI sets it); the live integration test signs in with it too |
| `SMOKE_PASSWORD` | none | integration_test only: the smoke user's password |
| `EMOTELY_DEBUG_BANNER` | `true` | debug builds only: `false` hides Flutter's DEBUG banner (the CLI sets it, so screenshots look like the installed app) |

Every secret lives in `apps/agent/.env.local` and is read **blind** — never
printed, never pasted into a message:

```bash
KEY=$(grep -E '^POSTHOG_KEY=' apps/agent/.env.local | cut -d= -f2- | tr -d '"' | tr -d "'")
```

## What the CLI does not do

- **Another agent, or Android.** The CLI runs the deployed agent on iOS. For
  anything else build and run by hand: `fvm flutter build ios --simulator`
  (plus the defines above) from `apps/mobile/app`, then the simulator tool's
  `launch` with `build/ios/iphonesimulator/Runner.app`, or `fvm flutter run
  -d <device>`. On a device a person signs in with the emailed six-digit code;
  against the local Supabase stack (supabase skill) the code shows up in
  Inbucket at http://127.0.0.1:54324. The app renders a **blank screen** when
  the `Runner.app` on disk came from `flutter test integration_test`: rebuild.
- **Toolchain.** Flutter is pinned by FVM (`apps/mobile/app/.fvmrc`); call
  `fvm flutter` / `fvm dart` from `apps/mobile/app`. CocoaPods comes from the
  app's `Gemfile`: a fresh worktree has no bundle, so `pod` fails with
  "CocoaPods not installed or not in valid state" until `bundle config set
  --local path vendor/bundle && bundle install` runs once per checkout (the
  CLI does it). It fails under a non-UTF-8 locale (`LANG=en_US.UTF-8`).
  After adding a CocoaPods plugin the first build may need `pod repo update`.

Driving Sign in with Google or Apple on a device — read
[references/provider-sign-in.md](references/provider-sign-in.md) first.

## On-device acceptance (live agent)

A whole session against the deployed agent, answering whatever it asks —
nightly / pre-release by hand, never per PR:

```bash
SMOKE_EMAIL=$(grep -E '^SMOKE_EMAIL=' apps/agent/.env.local | cut -d= -f2-)
SMOKE_PASSWORD=$(grep -E '^SMOKE_PASSWORD=' apps/agent/.env.local | cut -d= -f2-)
cd apps/mobile/app && fvm flutter test integration_test/live_session_test.dart -d <device udid> --dart-define=POSTHOG_KEY="$KEY" --dart-define=SMOKE_EMAIL="$SMOKE_EMAIL" --dart-define=SMOKE_PASSWORD="$SMOKE_PASSWORD"
```

Expect ~25 s after the build (about ten live model rounds). It starts a new
session, so it needs the smoke account without an unfinished one: discard
what a driven session leaves open (above).

## PostHog by hand

`run-app.sh collect` already fetches a session's events. For anything else, the personal key
(also read blind) reads the events API; properties must be ids, types, counts
and status codes only — never content (ADR 0005):

```bash
PHX=$(grep -E '^POSTHOG_PERSONAL_API_KEY=' apps/agent/.env.local | cut -d= -f2- | tr -d '"' | tr -d "'")
curl -s -H "Authorization: Bearer $PHX" "https://eu.posthog.com/api/projects/262464/events/?event=session_completed&limit=1&after=$(date -u +%Y-%m-%dT00:00:00Z)" | jq '.results[0].properties | with_entries(select(.key | startswith("$") | not))'
```

Error tracking answers on the same endpoint. Provoke a handled failure (the
cheapest: request a sign-in code for an address Supabase refuses, e.g. a
second request within 60 s), then list the `$exception` events since the run
started; the SDK stamps `$app_version`/`$app_build` and `ErrorReporter` adds
`step`:

```bash
AFTER=$(date -u +%Y-%m-%dT%H:%M:%SZ)   # take this BEFORE provoking the failure
curl -s -H "Authorization: Bearer $PHX" "https://eu.posthog.com/api/projects/262464/events/?event=%24exception&limit=5&after=$AFTER" | jq '.results[] | {timestamp, exceptions: [.properties["$exception_list"][] | {type, value, handled: .mechanism.handled}], step: .properties.step, status_code: .properties.status_code, app_version: .properties["$app_version"], app_build: .properties["$app_build"]}'
```

`value` must be the type plus a code (`… (message withheld, ADR 0005)`) for
everything but `AgentException`, `ClientException` and `TimeoutException`.
Uncaught-error autocapture is off in debug builds, so a simulator run only
shows handled failures. The SDK flushes on a timer or when the app goes to
the background: press HOME and give it ~45 s before querying.

## Unit gate (what CI runs)

Every package in the workspace, each in its own directory — codegen
tripwire, format, analyze, complexity and size limits, the 100% coverage
gate:

```bash
cd apps/mobile && melos run ci
```

One gate at a time is `melos run codegen:check` / `format` / `analyze` /
`complexity` / `test`. To run only what changed since `main` plus its dependents, as a
pull request's CI does:

```bash
cd apps/mobile && EMOTELY_SCOPE="--diff=origin/main...HEAD --include-dependents" melos run ci
```
