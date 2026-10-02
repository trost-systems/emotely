# Supabase is the data layer: the app writes under row-level security, the agent only verifies who is calling

Until #7 the app had no accounts and nothing outlived a session: the entry was
shown once and gone. A journaling app needs the opposite, and it needs it
without the agent growing a database or the public repository growing a secret.
The decisions here were drafted in #7 and hold for every table and every
authenticated request from here on.

## Decisions

1. **Supabase (Postgres + Auth), one project, Frankfurt.** Fresh schema, no
   Firebase baggage; row-level security (RLS) is the whole authorization
   model, the same per-user ownership the legacy Firestore rules expressed.
   Region `eu-central-1`, next to the PostHog EU project (ADR 0004). Free plan
   until it isn't enough: it pauses after a week without traffic, which daily
   journaling prevents.
2. **The app writes, the agent verifies.** The app talks to Supabase directly
   with the user's JSON Web Token (JWT): it upserts its `sessions` row after
   every round, inserts the `entries` row on completion, and reads its own
   history. The agent verifies the JWT on every request against the project's
   public key set (`/auth/v1/.well-known/jwks.json`, via `jose`) and reads
   `sub`; it never holds a database connection. Consequences: **no service-role
   key exists anywhere in this repository or in Vercel** (the Supabase URL and
   publishable key are public by design), the agent gains one dependency, and
   a compromised agent deployment can read nothing it was not sent.
   Rejected: the agent writing as the user by forwarding the bearer token to
   PostgREST. Also secret-free, but every round would pay a database round
   trip and the agent would own a data layer it does not need.
3. **The transcript signature stays.** The `sessions` row holds the signed
   transcript, so a user editing their own row cannot forge what the model
   sees (ADR 0008). Resume is the same call as continue: load the row, post
   transcript, signature and answer.
4. **Sign-in is an email one-time code, and it is required.** Six digits typed
   into the app, no password, no deep link. Email is our own account system,
   so Apple guideline 4.8 does not force Sign in with Apple until a social
   provider is added ([#51](https://github.com/trost-systems/emotely/issues/51)).
   No anonymous sign-in: it needs CAPTCHA and a cleanup job per Supabase's
   own guidance, and a journal that is not persisted is not the product.
   *2026-09-13, one exception:* the two store reviewer accounts
   (`apps/app/lib/auth/review_accounts.dart`) sign in with a password, because
   App Review, Google Play's reviewers and the pre-launch crawler have no
   mailbox to read a code from, and the crawler's retries were burning the
   email quota. They are created server-side by the release skill's script,
   an operator-run, out-of-band service-role path: the key is fetched blind
   through the maintainer's Supabase CLI login for the length of one run and
   never enters the app, CI or Vercel — decision 2 stands. The app still has
   no sign-up path.
5. **Schema and auth configuration are code, gated and deployed like
   everything else.** `supabase/migrations/` and `supabase/config.toml` (with
   the sign-in email template) are the source of truth. CI applies the
   migrations to a fresh Postgres and runs the pgTAP suite in
   `supabase/tests/`, which impersonates two users and an anonymous caller
   and asserts that cross-user reads and writes fail before they reach a row.
   A merge to `main` runs `supabase db push` and `supabase config push`. The
   dashboard is for looking, not for changing.

## The schema

| table | row | rules |
| --- | --- | --- |
| `sessions` | one journaling conversation: signed transcript, the pending question and the questions asked so far (what a resume renders), status, question set, app version | owner-only; at most one `in_progress` per user (partial unique index) |
| `entries` | one finished entry: summary, answers by question id, the questions as asked | owner-only; no `update` privilege, delete only |

Both default `user_id` to `auth.uid()`, cascade from `auth.users`, and grant
nothing to `anon`. `complete_session()` writes the entry and closes the session in one
transaction as the caller, so RLS decides which session it may touch. `delete_account()` is a `security definer` function that
deletes the caller from `auth.users`, which cascades: in-app account deletion
is an App Store requirement (5.1.1) and ten lines here.

## Wire compatibility was broken once, on purpose

ADR 0009 rule 3 says the server must stay compatible with the app in stores.
The agent started refusing unauthenticated requests in the same stack as the
app learned to sign in, because there is no app in any store and no user but
the maintainer. Envelope unchanged, `Authorization` header added, `401`
without it. This is a pre-release exception, recorded so nobody reads it as
precedent: from the first store build on, rules 1 to 4 apply unmodified.

## What follows from it

- **ADR 0008 gains a per-user key.** Every verified request carries `sub`, so
  an in-code per-user limiter is possible the day it is needed; the WAF rule
  stays IP-keyed and unchanged. Anonymous sessions are refused, which closes
  the one cost ADR 0008 could not bound.
- **Journal content lives in Supabase and nowhere else.** It passes through
  the agent transiently, as before, and never reaches PostHog (ADR 0005).
  PostHog is told the user id (a UUID) on sign-in and reset on sign-out; the
  email address never leaves for it.
- **Two secrets, both in GitHub's `ci` environment, neither in the repo:** a
  Supabase access token and the database password, used only by the deploy
  job. The Vercel project needs one new variable, the public Supabase URL.
- **The built-in mailer sends two emails an hour.** Enough for one user,
  a release blocker for #9
  ([#52](https://github.com/trost-systems/emotely/issues/52)).
- **How to run and test the schema locally is a skill**
  (`.claude/skills/supabase`), so an autonomous agent can add a table, prove
  its policies, and ship it without a human step.

## Amendment 2026-09-27: the agent runs in Frankfurt too

Decision 1 put the data in Frankfurt; the agent that every round of a session
passes through was left on Vercel's default region, `iad1` (Washington, D.C.),
which nobody chose. Each round carries the transcript — Art. 9 data — and,
since #204, the user's name, so the one leg of the trip that was ours to place
crossed the Atlantic before any provider was involved
([#208](https://github.com/trost-systems/emotely/issues/208)).

**Decision: every `emotely-agent` function runs in `fra1` (Frankfurt,
AWS `eu-central-1`), pinned by `"regions": ["fra1"]` in `apps/agent/vercel.json`.**
Vercel documents that `regions` "overrides the Vercel Function Region in
Project Settings", so the repository decides and the dashboard's setting
(still `iad1` on 2026-09-27) no longer matters for any deployment built from
it. `src/function-region.test.ts` fails if the pin goes, grows a second
region, gains `functionFailoverRegions` or a per-function override, because
the in-app notice now says Frankfurt and any of those would make it wrong
without a notice change.

Checked before moving, against Vercel's docs of 2026-08/09:

- **Plan.** Any single region is available on every plan; Pro allows several.
  One region is the point here, not a limit we are working around.
- **Fluid compute** is a per-project execution model with no region list; it
  runs in `fra1` as in `iad1`. Its whole-region failover redirects traffic to
  the next closest region only when every availability zone in the region is
  down; configurable failover regions (`functionFailoverRegions`) are
  Enterprise-only and not set. The residual case — a full `fra1` outage — is
  the one time a round may run elsewhere, and the nearest regions are EU ones.
- **Firewall (ADR 0008).** The WAF sits in front of the function and rejects
  before it is invoked; its counters stay per Vercel region as ADR 0008
  already says, and neither rule names a function region. Both rules are
  unchanged, and nothing about them lives in `vercel.json`.
- **AI Gateway** is called over HTTPS (`ai-gateway.vercel.sh`) from wherever
  the function runs; routing, ZDR and the training opt-out (ADR 0003) are
  request options, not regional features. Vercel does not publish where the
  gateway processes a request, and the providers serving the current model
  are mostly US-hosted, so **the gateway and provider legs can still leave the
  EU**; the notice keeps that transfer and its safeguard.
- **Neighbors.** Supabase (the JWKS the agent verifies against, decision 2)
  and PostHog EU (ADR 0004) are both in Frankfurt, so those calls become
  local. The transatlantic hop moves from phone→agent to agent→provider;
  per-round latency should be roughly unchanged and is watched after the
  switch in PostHog's AI observability, not assumed.
- **Cost (ADR 0003).** `fra1` bills Fluid Active CPU at $0.184/h and
  provisioned memory at $0.0152/GB-h against `iad1`'s $0.128 and $0.0106, about
  44% more. The agent is I/O-bound on the model call, so for a daily poweruser
  (~360 rounds a month) that is a fraction of a cent, invisible next to the
  ~$0.11 of tokens and far inside the €1 ceiling.

**What changes for the reader:** the in-app notice now places the agent in
Frankfurt and keeps the standard contractual clauses for the gateway and the
provider. The consent wording already said only that "the provider may be
outside the EU", which is now exactly true, so `consentVersion` stays.
