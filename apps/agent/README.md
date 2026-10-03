# apps/agent

The deployed TypeScript service that runs the tool-calling session loop
(`POST /api/advance-session`) on Vercel. Architecture and the reasons behind
it live in the root [`README.md`](../../README.md) and [`docs/adr/`](../../docs/adr/);
this file holds what is specific to operating the service.

## Endpoints

| Endpoint | Auth | What it does |
| --- | --- | --- |
| `POST /api/advance-session` | Supabase JWT ([ADR 0010](../../docs/adr/0010-supabase-data-layer.md)) | One session round: verifies the signed transcript, calls the model, returns the next question or the finished entry. |
| `GET /api/config` | none | The startup config the app reads once before anything else: `min_app_version` and `store_url`. Takes `?platform=ios\|android` to pick the right store listing. Public and edge-cached — see below. |
| `POST /api/revoke-apple` | Supabase JWT | Revokes the caller's Sign in with Apple grant before their account is deleted ([#193](https://github.com/trost-systems/emotely/issues/193)) — see below. |

`POST /api/revoke-apple` exists because Supabase never revokes Apple tokens
and stores none to revoke. When a user whose account has an Apple identity
deletes it, the app asks Apple's sheet for a fresh authorization code and
posts it here with the user's token. The route asks Supabase
(`GET /auth/v1/user`, under the caller's own token) which Apple ID the
account is linked to, trades the code at Apple's `/auth/token` for a refresh
token, and revokes that at `/auth/revoke` — only if the code's Apple ID is
the linked one. Each call to Apple carries a client secret minted per
request from the Sign in with Apple key, five minutes long; no Apple token
outlives the request. Any refusal (`apple_identity_mismatch`,
`apple_revocation_unavailable`) leaves the grant in place, and the app
deletes the account anyway and tells the user where to remove emotely
themselves. Apple's and Supabase's refusals are reported to PostHog with
`step: "apple_revocation"`, in their fixed vocabulary only.

`GET /api/config` is the one unauthenticated endpoint. The app checks it
**above the sign-in gate** ([#49](https://github.com/trost-systems/emotely/issues/49)):
the users it exists to block are on a build the server no longer serves, so
requiring a token would put a screen they may not be able to drive in front of
the one telling them to update. It signs nothing, touches no database and
calls no model, and its body (a version and a public link) is already in this
repository. It is cached at the edge (`s-maxage=300`,
`stale-while-revalidate=600`) and carries its own WAF rate-limit rule
([ADR 0008](../../docs/adr/0008-public-endpoint-abuse-controls.md)).

Two consequences worth knowing when you change `MIN_APP_VERSION`:

- **A raise reaches users at their next launch, not instantly**, and only
  after the edge cache expires (up to five minutes, longer while
  `stale-while-revalidate` serves the old value). Plan it; it is not a stop
  button.
- **The app blocks when this endpoint is down.** That is deliberate (it fails
  shut, ADR 0009), which makes availability here more user-visible than
  anywhere else in the service — a broken `/api/config` is a hard outage even
  though no model is involved. The nightly smoke probes it for that reason.

## Environment variables

Read once per cold start in [`api/advance-session.ts`](api/advance-session.ts),
[`api/config.ts`](api/config.ts) and [`api/revoke-apple.ts`](api/revoke-apple.ts). Values are set on the `emotely-agent`
Vercel project by a human, never committed (see the root
[`AGENTS.md`](../../AGENTS.md)).

| Variable | Required | Purpose |
| --- | --- | --- |
| `SESSION_SIGNING_SECRET` | yes | HMAC key that signs every transcript the server returns; only transcripts it signed advance ([ADR 0008](../../docs/adr/0008-public-endpoint-abuse-controls.md)). |
| `SESSION_SIGNING_SECRET_PREVIOUS` | no | The secret being retired. Set only for the grace window of a rotation (below); unset in normal operation. An empty value counts as unset. |
| `SUPABASE_URL` | yes | The Supabase project whose users may call ([ADR 0010](../../docs/adr/0010-supabase-data-layer.md)). |
| `AI_GATEWAY_API_KEY` | yes | Vercel AI Gateway key ([ADR 0003](../../docs/adr/0003-model-gateway-and-cost-ceiling.md)). |
| `EMOTELY_MODEL` | no | Overrides `DEFAULT_MODEL` in `src/session-config.ts`. The value must be served by providers that **all** qualify under the gateway's privacy filters (below), or every round fails. |
| `POSTHOG_KEY`, `POSTHOG_HOST` | no | AI Observability **and error tracking**; both or neither ([ADR 0004](../../docs/adr/0004-posthog-observability-stack.md)). Unset means no spans and no exception reports — the runbook below has nothing to read. |
| `EMOTELY_STORE_URL` | no | Where the force-update screen sends a caller that named no platform, or one we do not know. Overrides `STORE_URL` in `src/session-config.ts`. Set these to correct a link without an app release — the only kind of fix that reaches someone who cannot install one. |
| `EMOTELY_STORE_URL_IOS` | no | The App Store listing, served for `?platform=ios`. Overrides `STORE_URL_IOS`. |
| `EMOTELY_STORE_URL_ANDROID` | no | The Play listing, served for `?platform=android`. Overrides `STORE_URL_ANDROID`. |
| `SUPABASE_PUBLISHABLE_KEY` | for `/api/revoke-apple` | The project's public key, which Supabase's gateway asks of every request; the route reads the caller's identities with it and the caller's token. |
| `APPLE_SIGN_IN_KEY` | for `/api/revoke-apple` | The Sign in with Apple `.p8` (PEM). **The one secret here besides the signing secrets.** Created, stored and rotated as the release-app skill's `references/sign-in-with-apple-key.md` says; production only. |
| `APPLE_SIGN_IN_KEY_ID`, `APPLE_TEAM_ID`, `APPLE_CLIENT_ID` | for `/api/revoke-apple` | The key's id, team `VCZSHMZY25`, and the App ID `de.emotely.emotely` — the client secret's `kid`, `iss` and `sub`. |

## Picking a model: it must qualify under the privacy filters

Every round sends `disallowPromptTraining` and `zeroDataRetention` to the
gateway ([ADR 0003](../../docs/adr/0003-model-gateway-and-cost-ceiling.md)
amendment 2026-09-15). Both **fail closed**: if no provider serving the model
qualifies, the gateway rejects the request and the session dies on its first
round — there is no quiet fallback to a weaker provider.

So a model is only eligible if enough of the providers that serve it qualify
under both filters.

**The monthly benchmark measures this for you.** It probes every candidate with
one cheap round before scoring it, reports a **Providers** column (qualifying /
considered), and refuses to call a model eligible below **two** qualifying
providers — under a fail-closed filter, a single provider is a single point of
failure for the whole product. Measured 2026-09-15: the default
`openai/gpt-oss-120b` is 8/8, but eight of the twelve candidates sit at 1.

To check a model by hand, run a round with those two `providerOptions.gateway`
flags and read `providerMetadata.gateway`: `enabledZeroDataRetention` and
`enabledDisallowPromptTraining` confirm the filters were applied at all (a
misspelled option key is silently ignored), and `routing.skippedProviderAttempts`
names each provider that was dropped and why.

`EMOTELY_MODEL` is a Vercel environment variable, so changing it bypasses both
the benchmark and CI — there is no deploy-time guard yet (follow-up to
[issue #98](https://github.com/trost-systems/emotely/issues/98)). When a rejection
does happen, the runbook below says how to recognize and recover from it.

## Runbook: every session is failing

**Symptom.** Every round returns **502** with `{"error":"model unavailable"}`,
and PostHog error tracking fills with `$exception` events carrying
`failure_kind: "provider_ineligible"` and the configured `model`. The app
shows its generic failure and reports `session_failed` with status 502.

A 502 means the *gateway refused the round*, not that the service is broken —
a server bug still 500s loudly and is not reported this way. `failure_kind`
separates the two cases the gateway has:

| `failure_kind` | What it means |
| --- | --- |
| `provider_ineligible` | No provider serving the model satisfies ZDR / the training opt-out. Fails closed, so **every** session dies. |
| `gateway_error` | Any other gateway refusal — auth, rate limit, model not found, upstream 5xx. |

**For `provider_ineligible`, check these two, in this order.**

1. **The Vercel plan.** Request-level Zero Data Retention is **Pro and
   Enterprise only**. A downgrade to Hobby therefore does not quietly weaken
   privacy — it hard-fails every round of every session (root
   [`AGENTS.md`](../../AGENTS.md) § Billing, and
   [ADR 0003](../../docs/adr/0003-model-gateway-and-cost-ceiling.md)). Confirm
   the `emotely-agent` team is still on Pro before looking at anything else:
   this is the likeliest cause, and the fastest to rule in or out.
2. **Provider eligibility for the configured model.** The set of providers
   serving a model changes under us — the gateway can drop one, or a provider
   can withdraw its ZDR agreement — so a model that qualified last month may
   not today. Check which model is actually in force (`EMOTELY_MODEL` on the
   project, else the `agent-model` flag payload, else `DEFAULT_MODEL` in
   `src/session-config.ts`), then run one round against it and read
   `providerMetadata.gateway.routing.planningReasoning`. The error message
   itself names the model and the providers it considered, and it reaches
   PostHog verbatim — gateway text is allowlisted precisely so this diagnosis
   needs no extra round.

**Recovery** is to put an eligible model back in force — revert
`EMOTELY_MODEL` or the `agent-model` flag to `DEFAULT_MODEL`, which is
measured — or to restore the plan. Do **not** recover by dropping the privacy
options: they are load-bearing for the privacy notice
([ADR 0005](../../docs/adr/0005-journal-content-privacy-mode.md)), and failing
closed is the intended behavior.

**Why the alarm exists.** Before this, a gateway rejection surfaced as an
unhandled 500 and the only alarm was the nightly `live-smoke` job, so a total
outage could run for up to 24 hours unnoticed (issue #99).

### What the reports do and do not contain

Exception reports are content-free by construction
([ADR 0005](../../docs/adr/0005-journal-content-privacy-mode.md)): the
properties are the step, the model id, the failure kind and the upstream
status, and only an allowlisted gateway error keeps its message.
`src/error-tracking.ts` owns the rule and explains each decision.

**You get the stack trace**, with the source context `posthog-node` attaches
to each frame — that is what tells you where a failure came from.

Two things are deliberately withheld, so do not go looking for them:

- **The cause chain.** A `GatewayError`'s `cause` is an `APICallError` whose
  `requestBodyValues` hold the prompt — i.e. the journal transcript. It is
  dropped before the SDK sees it, which is the whole reason this module
  rebuilds the error instead of forwarding it.
- **Any non-gateway error's message**, which arrives as a `WithheldError`
  naming only the type and status.

To debug past that, reproduce locally with the model id the report carries.

## Rotating the signing secret

The session is stateless: the client holds the transcript and its signature and
posts both back every round. A rotation that only swapped
`SESSION_SIGNING_SECRET` would therefore turn every in-flight session into a
401 on its next round. ADR 0009 rule 5 says that must not happen, and the
verifier implements it: it accepts a signature made with **either** the current
secret or the previous one, while signing always uses the current one. A
transcript signed under the old secret is accepted once and comes back signed
with the new one, so sessions migrate by themselves within one round.

The grace window is exactly the time `SESSION_SIGNING_SECRET_PREVIOUS` is set.
A session is at most 200 messages ([ADR 0008](../../docs/adr/0008-public-endpoint-abuse-controls.md)),
so a day is plenty; sessions abandoned for longer than that fail their next
round with a 401 and start over, which is the same outcome as today.

Secret values are handled by a human and never enter a terminal transcript or
a chat: generate them out of band and pipe them in blind. Run the CLI from
`apps/agent`, the linked project directory.

1. **Stage the old secret as the previous one.** Copy the current value of
   `SESSION_SIGNING_SECRET` from the project's environment variables (Vercel
   dashboard → `emotely-agent` → Settings → Environment Variables) into a
   temporary file, then:

   ```bash
   vercel env add SESSION_SIGNING_SECRET_PREVIOUS production < /path/to/old-secret.txt
   ```

2. **Set the new secret.** Generate a fresh value (e.g. `openssl rand -base64 48`
   straight into a file) and update the current secret:

   ```bash
   vercel env update SESSION_SIGNING_SECRET production < /path/to/new-secret.txt
   ```

   Delete both temporary files.

3. **Deploy.** Environment variables apply to the next deployment, and the
   Ignored Build Step skips commits that touch no agent input, so rebuild the
   current production deployment explicitly:

   ```bash
   vercel redeploy <current-production-deployment-url>
   ```

   From here every response is signed with the new secret and transcripts
   signed with the old one are still accepted.

4. **Wait a day**, then close the window:

   ```bash
   vercel env rm SESSION_SIGNING_SECRET_PREVIOUS production
   vercel redeploy <current-production-deployment-url>
   ```

Things worth knowing:

- **Order matters.** Steps 1 and 2 must both be in place before step 3; a
  deploy between them serves neither the old secret as previous nor the new
  one as current, so only one of the two is accepted during that deploy.
- **Setting `PREVIOUS` to the new value** (instead of the old one) is harmless
  but useless: the verifier then accepts only the new secret, exactly as if
  the variable were unset, and in-flight sessions fail. The old value goes in
  `PREVIOUS`, the new one in `SESSION_SIGNING_SECRET`.
- **Never leave `PREVIOUS` set.** While it is set, two secrets open the
  endpoint instead of one; step 4 is part of the rotation, not optional
  cleanup.
- **Do not rotate to recover from a leak without both steps.** Removing a
  compromised secret needs the window closed immediately: skip the wait in
  step 4 and accept the failed rounds.

## Scripts

`package.json` is the reference; the ones that matter in CI are `lint`
(repo root), `typecheck`, `test`, and `eval` (live-model protocol eval,
needs `AI_GATEWAY_API_KEY`). `smoke` is the nightly live probe against
production.
