# The server serves every app version still in use, so merging is deploying

`main` deploys `apps/agent` to production on merge (Vercel Git integration,
gated only by `ci-ok`; the Ignored Build Step in `apps/agent/scripts/vercel-ignore.sh`
skips commits that touch no agent build input). The app cannot deploy that way:
a store release takes days to review and weeks to reach every device, and users
never all update. So at any moment the production server talks to several app
versions at once, and a merge that breaks one of them breaks it for everyone on
it, instantly, with no CI run in between. The rules below make that merge safe
by construction. They were drafted in #37 and hold for every wire change from
here on.

## Rules

1. **Wire changes are additive.** New fields are optional on the way in and
   nullable on the way out; nothing is renamed, removed, or retyped. The client
   is a tolerant reader: unknown keys are ignored, absent optional keys mean
   "no such thing". `app_version` and `min_app_version` were added this way.
2. **A real incompatibility is a new endpoint** (`/api/v2/advance-session`, or a
   new path), never a changed one. The old endpoint stays until PostHog shows no
   traffic from app versions that use it, then it is deleted, not kept.
3. **Server before app.** One PR may change both sides, but the server side
   must be compatible with the app already in stores, because it goes live
   first and the app release follows whenever the store lets it.
4. **The app reports its version, the server names its minimum.** Every session
   request carries `app_version` (bare semver from `pubspec.yaml`); the minimum
   comes from `GET /api/config`, which the app reads once at startup. Below the
   minimum the app blocks with a force-update screen, before sign-in. This is
   what allows rule 2's deletion: raising the minimum past a version is the
   moment its endpoints can go.
5. **Signing-secret rotation keeps in-flight sessions alive.** When
   `SESSION_SIGNING_SECRET` is rotated the server must accept the previous
   secret for a grace window as long as the transcript cap makes a session
   plausible. Implemented in
   [#50](https://github.com/trost-systems/emotely/issues/50): the verifier
   accepts `SESSION_SIGNING_SECRET_PREVIOUS` alongside the current secret
   while it is set, signing always uses the current one, and the runbook is
   in [`apps/agent/README.md`](../../apps/agent/README.md).

## How the rules are enforced, not just written down

- **One contract, two pins.** The envelope of `POST /api/advance-session` and
  the tool payloads are zod schemas in `packages/contract`, emitted into
  `contract.schema.json`. CI regenerates the file and fails on a diff. The
  agent handler parses requests with the contract schema and every response
  literal must `satisfies` the contract type, so an envelope change that skips
  the contract fails `tsc`. The Dart side pins what `AgentClient` posts and
  every key its freezed decoders need against the emitted schema, read through
  the real serialization path. Drift fails one CI run on whichever side forgot.
- **Nullable on the Dart side is the additive escape hatch.** The Dart pin
  treats a nullable field as optional, so a server field can be required in
  the schema (the server always sends it) and still nullable in the app (a
  rollback to a build without it imposes nothing). `min_app_version` was the
  worked example until it left the session envelope (below); the mechanism
  stands for the next additive field.
- **The config response is pinned the same way.** `config_response` is a zod
  schema in `packages/contract` emitted into `contract.schema.json`, and the
  Dart side pins `StartupConfig` against it through the real `toJson`/
  `fromJson` path. Both its fields are **required on both sides**, unlike the
  session envelope's optionals: this is the app's own gate, and a config it
  can only half read is one it must not act on — it blocks instead.
- **The minimum is code, not configuration.** `MIN_APP_VERSION` in
  `apps/agent/src/session-config.ts` is `1.0.0`: nothing is blocked. Raising it
  is a PR like any other: reviewed, versioned next to the code that needs it,
  and undone by the same pipeline. A PostHog flag would let it change without
  a deploy, and its one real cost is small: a second network dependency,
  where PostHog being down while the agent is up would leave the minimum
  unknown. That is rare and acceptable (the fallback is "no minimum"). The
  constant wins on review and history, not on availability.
- **The minimum comes from `GET /api/config`, not from the session**
  (amended 2026-09-15, [#49](https://github.com/trost-systems/emotely/issues/49)).
  It used to ride on every session response because a second public endpoint
  needs its own WAF rate-limit rule and Hobby allows one
  ([ADR 0008](0008-public-endpoint-abuse-controls.md)); the project has been on
  Pro since 2026-09-13, so that constraint is gone. The app now reads the
  config **once at startup, above the auth gate**, and:

  - **it blocks with a retry when that read fails.** Failing shut is the whole
    point: the app cannot tell "no minimum" from "could not ask", and a build
    the server has stopped serving must not walk past the gate whenever the
    network is down. Revisit when offline capabilities arrive — a cached
    last-known minimum could then let the app proceed.
  - **the gate sits above sign-in.** The users it exists to block are on a
    build the server refuses; making them sign in first to learn that puts a
    screen they may no longer be able to drive in front of the one telling
    them why. That is also why the endpoint takes no token.
  - **`app_version` stays on every session request**, for rule 4:
    server-side gating stays per version even though the app-side block does
    not live in the session any more.

  `min_app_version` was **removed from the session response in the same PR**
  rather than retired gradually. The retirement procedure below exists to
  protect installed apps, and there were none: the app had never been
  distributed to a tester, and every build ever produced reports `1.0.0`
  against a `MIN_APP_VERSION` of `1.0.0`, so no build was blocked either way.
  A field that no app in anyone's hands reads is not a compatibility surface.
  **This is the exception, not the precedent** — with real installs the same
  change would have had to keep sending the field and follow the procedure.

### Raising the minimum

1. Check PostHog: `posthog_flutter` stamps `$app_version` on every event, so
   the share of sessions on versions below the candidate minimum is one
   breakdown away. Raise only when that share is zero or accepted.
2. Bump `MIN_APP_VERSION`, merge. Those users then see the force-update
   screen at their next launch, and PostHog receives `update_required` with
   both versions, so the effect is measurable the same hour. The config
   response is cached at the edge (`s-maxage=300`, `stale-while-revalidate`),
   so a raise takes a few minutes to reach every region rather than landing
   with the deploy — which is why it is a planned step, not an emergency stop.
3. Only then delete the endpoints or wire shapes the blocked versions needed.

The force-update screen sends users to the `store_url` the config response
names. The app sends `?platform=ios|android` and the server answers with that
store's listing, falling back to a neutral link for anything it does not
recognize — so a request it cannot classify still gets somewhere to go. The
links moved off the app's dart-defines deliberately: the only people who ever
follow one are the ones who cannot install a build carrying a corrected one,
so they have to be fixable without a release (`EMOTELY_STORE_URL`,
`EMOTELY_STORE_URL_IOS`, `EMOTELY_STORE_URL_ANDROID`; the releases page until
the store listings exist, #9).

## Recovery goes through the pipeline; Instant Rollback is break-glass

The gate is `ci-ok` before merge. When something still reaches production
broken, the correction is a **revert PR through the same pipeline** as every
fix and feature: `git revert` the squash commit, open the PR, let `ci-ok` and
auto-merge land it, and the Git integration deploys it. That keeps `main` and
production identical, which is the property everything else here relies on
(the Ignored Build Step, the contract pins, `entire why`, and the assumption
that the deployed code is the reviewed code). The whole loop is a few minutes:
the agent CI job runs in about a minute and the deploy in another. Because of
rule 3 the server can always be reverted on its own; the app in stores was
compatible with the previous deployment by construction.

Vercel Instant Rollback exists for the case where the pipeline itself is what
is broken (CI down, a deploy that cannot be reverted cleanly, a fire that
cannot wait two minutes). From `apps/agent` (the linked project directory):

```bash
vercel rollback <deployment-url-or-id>
```

It is deliberately the exception, because it makes Git and production drift:
`main` still says the bad commit is live. Every rollback therefore comes with
two obligations, in this order: open the revert PR immediately, and undo the
rollback (`vercel promote <deployment-url-or-id>`, or the dashboard's **Undo
Rollback**) as soon as the revert has deployed. What else to know, from
Vercel's docs ([instant-rollback](https://vercel.com/docs/instant-rollback),
read 2026-09-06):

- **A rollback freezes production.** Vercel turns off auto-assignment of the
  production domain, so later merges to `main` build but do not go live until
  the rollback is undone. Forgetting the undo means `main` silently stops
  deploying, which is the drift becoming permanent.
- **Hobby can only roll back to the immediately previous production
  deployment.** Pro allows any deployment that was ever aliased to production.
- **Environment variables are not rolled back.** The restored deployment runs
  with the variables it was built with.
- **The Ignored Build Step is unaffected**: it decides which commits build,
  the rollback decides which build serves traffic.

The app has no rollback. A broken app release is fixed by a new release, and
until it lands the server keeps serving the broken version whatever it sends,
which is exactly what rules 1 and 4 guarantee it can do.

## What follows from it

- **#7 (Supabase auth and persistence) will add fields, not change them.**
  Session ids, user ids and entry ids arrive as new optional keys; the
  anonymous flow keeps working until the minimum version says otherwise.
- **The nightly live smoke** exercises production with the current contract
  and would catch a server that stopped honoring an older shape only if it
  sent one. It does not; cross-version coverage comes from rule 1 and the
  contract pins, not from the smoke.
- **Reviewers check one thing on wire PRs**: is every change additive, and if
  not, is there a new endpoint. The pins catch the accidental cases; the
  rule is for the deliberate ones.
