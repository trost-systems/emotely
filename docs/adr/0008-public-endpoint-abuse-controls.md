# The agent endpoint is public, so it must be structurally unabusable

`POST /api/advance-session` is reachable by anyone: the app has no user accounts
yet (they arrive with #7), and the repository that describes the endpoint byte for
byte is public. An unauthenticated, open-source, LLM-backed endpoint is a free LLM
proxy unless the design makes it not one. The controls below are layered so that
no single one has to hold.

## Server-signed transcripts

The session is stateless: the client holds the whole transcript and posts it back
each round. Every response signs that transcript (HMAC-SHA256 over the JSON,
verified in constant time); only server-signed transcripts advance. Nobody can
inject, edit, or fabricate messages, so the model never sees client-authored
text as anything but the widget answer — and that enters as a size-capped,
schema-typed **tool result**: data, never instructions.

The alternative we rejected was storing sessions server-side and handing the
client an id. It would also close the injection hole, but it needs a database
before #7 delivers one, and a per-id store is itself an abuse surface (unbounded
session creation). Signing costs nothing and moves the state to the party that
already has it. Server-side resume comes with #7, on top of the same signing.

### Amendment 2026-09-24: sign the canonical JSON

"Over the JSON" meant `JSON.stringify` of the transcript as received, which
made the signature depend on key order. The app stores an unfinished session
in a Postgres `jsonb` column (ADR 0010), and `jsonb` does not keep key order,
so every resumed session failed its signature check. The HMAC now covers the
transcript's canonical JSON, with the keys of every object sorted: any faithful
re-encoding verifies, any changed value does not.

## Caps before compute

Validation runs in cost order, cheapest first, and every failure returns before a
model call: signature (401), transcript length ≤ 200 messages (413), answer ≤ 4 KB
(400), answer must match the pending question (400), non-POST (405). The
transcript-shape parse sits *behind* the signature check on purpose — a failure
there is a server bug and should 500 loudly, not be silently absorbed as bad
input.

### Amendment 2026-09-24: every refusal carries a code

Two refusals shared a status: a missing or lapsed sign-in and a bad transcript
signature are both 401, told apart only by their English text. Every error
response is now `{ code, error }` (`errorResponse` in `packages/contract`):
`code` is a closed set the app acts on and words itself, `error` stays English
for logs and for app versions that predate `code`. The app renews its token
and resends once on `unauthorized`, and offers a fresh session instead of a
retry on `invalid_signature` and `transcript_too_long`. No server text reaches
a screen, so every message can be localized.

### Amendment 2026-09-24: the app enforces the answer cap too

"4 KB" is `JSON.stringify(value).length`: UTF-16 code units of the encoded
answer, not bytes, so escapes, quotes, list punctuation and both halves of an
emoji count. A refused answer used to strand the user, since "Try again"
resent it unchanged. The cap now lives in `packages/contract`
(`maxAnswerLength`, emitted under `limits` in the JSON Schema and pinned by the
app's contract test), and the longtext and text-list inputs measure exactly
what the agent measures, count down near the cap and will not submit past it.
The cap stays at 4096: it bounds what every later round re-sends, and about
650 words per answer is room enough for journaling. The app enforces the cap
from its own build, so **lowering it strands every older build in the loop
this removed**: raise the minimum app version with it.

## Cost backstops

- A per-round output-token cap and a round guard derived from the transcript
  (the model cannot loop forever on one signed state).
- The gateway key's monthly budget ([ADR 0003](0003-model-gateway-and-cost-ceiling.md))
  is the hard ceiling: exhaustion degrades the product, never the bank account.

## Rate limiting lives in the Vercel WAF, not in code

Starting a session is deliberately free — an empty transcript needs no signature —
so the one thing signing cannot bound is *how many* sessions one source starts.
That is what the firewall rule is for:

| Rule | Value |
| --- | --- |
| Project | `emotely-agent` → Firewall → Rules |
| Match | Request Path equals `/api/advance-session` |
| Limit | 30 requests / 60 s, fixed window, keyed by IP |
| Action | 429 Too Many Requests |

A real session is roughly one request per question, so 30/min is an order of
magnitude above legitimate use. Counters are per Vercel region, so the effective
global limit for a distributed attacker is higher — acceptable, because the
budget backstop above catches what the rule lets through.

A second rule covers the startup config endpoint, added with
[#49](https://github.com/trost-systems/emotely/issues/49) now that Pro allows
more than one:

| Rule | Value |
| --- | --- |
| Project | `emotely-agent` → Firewall → Rules |
| Match | Request Path equals `/api/config` |
| Limit | 60 requests / 60 s, fixed window, keyed by IP |
| Action | 429 Too Many Requests |

The limit is looser because the endpoint is cheaper — no signature, no model
call, no user lookup, and cached at the edge (`s-maxage=300`), so the
overwhelming majority of reads never reach a function at all. It is still
rate-limited rather than left open: an uncached path is still a function
invocation, and an unauthenticated GET is the easiest thing in the system to
point a script at. A real app reads it once per launch.

We chose the WAF over an in-function limiter because the rule rejects at the
edge, before a function invocation is billed, and because a Hobby project gets
one rate-limit rule at no cost. Verified live on 2026-09-04: the 31st request
inside a minute from one IP gets a 429.

### The rules are not in `vercel.json`, but they are reproducible

`vercel.json` can carry WAF rules via `routes[].mitigate`, but only the `deny`
and `challenge` actions — **not `rate_limit`**, which is what both rules here
use. So these cannot be deployment configuration, and they stay out of CI.

They are not dashboard-only either (as this ADR claimed until 2026-09-16). The
CLI creates them non-interactively, which is what makes them reproducible by an
agent rather than by hand. Changes stage as a draft and need an explicit
publish; `vercel firewall rules list --expand` shows the live configuration.

```bash
vercel firewall rules add "Rate limit advance-session" \
  --project emotely-agent \
  --condition '{"type":"path","op":"eq","value":"/api/advance-session"}' \
  --action rate_limit --rate-limit-window 60 --rate-limit-requests 30 \
  --rate-limit-keys ip --rate-limit-action rate_limit --yes

vercel firewall rules add "Rate limit config" \
  --project emotely-agent \
  --condition '{"type":"path","op":"eq","value":"/api/config"}' \
  --action rate_limit --rate-limit-window 60 --rate-limit-requests 60 \
  --rate-limit-keys ip --rate-limit-action rate_limit --yes

vercel firewall diff --project emotely-agent      # review
vercel firewall publish --project emotely-agent   # make live
```

What remains true is that the rules live on the project, not in this
repository: nothing in CI asserts they exist, and a project re-creation drops
them. The commands above are the recovery procedure.

## What follows from it

- **The nightly live smoke** (`pnpm smoke`) makes about a dozen requests from one
  runner IP — safely under the limit. Any future probe that fires more must
  stay under 30/min or expect 429s.
- **User auth (#7) replaces none of this.** It adds a per-user key for the rate
  limit and the ability to refuse anonymous sessions; signing, caps, and budget
  stay as they are.
- **A second rate-limit rule needed Pro**, which the project has been on since
  2026-09-13. `/api/config` uses that allowance
  ([#49](https://github.com/trost-systems/emotely/issues/49)). A further rule
  (e.g. a tighter cap on empty-transcript session starts) is now possible too.
- **`/api/config` is public on purpose.** It answers without a token, unlike
  every other endpoint here (ADR 0010), because the users it exists to block
  are on a build the server no longer serves and must be told so before the
  sign-in screen. What that costs is bounded by what the endpoint holds: a
  version number and a public store link, both already visible in this
  repository. It signs nothing, reads no database, and calls no model, so the
  abuse it can support is bandwidth against a cached static body — the rule
  above and the edge cache are the whole defense, and they are proportionate
  to it.

## Amendment 2026-10-03: the auth endpoints get a human check (#94)

Everything above guards the agent on Vercel. Supabase Auth's public routes
go straight to `*.supabase.co` and were guarded only by GoTrue's own rate
limits: `sign_in_sign_ups` (30 per 5 min per IP) and `email_sent` (30 per
hour, **project-wide**). One script from one address could spend the hourly
mail cap in minutes, after which no real sign-in code and no deletion code
went out for the rest of the hour; and `/otp` with `create_user: false`
answers 422 for an unknown address and 200 for a known one, so account
existence was readable by anyone with the publishable key.

**Decision: Supabase Auth's CAPTCHA, with Cloudflare Turnstile.** GoTrue
checks a Turnstile token with Cloudflare before `/otp`, `/signup`,
`/recover`, `/resend`, `/magiclink` and the password grant — for every
client, so neither the app nor the web page can be skipped. Verifying a
code, refreshing a session and the Google/Apple ID-token grant are not
checked. A token is single-use and lapses after five minutes, so every
protected call fetches a fresh one:

| Caller | How it gets a token |
| --- | --- |
| App | `HumanCheck.guard` (`human_check` utility) runs the call with a token from Turnstile in a headless web view (`apps/mobile/app/lib/app/turnstile.dart`) under the site's origin |
| Web deletion page | `apps/web/lib/turnstile_web.dart` loads Cloudflare's script on the first "Send me a code" and runs a managed widget that is invisible unless Cloudflare wants an interaction |
| Local stack | `supabase/config.toml` holds Cloudflare's always-pass test secret; builds against it pass the test site key |

One widget (`emotely`, managed, domain `getemotely.com`) serves both
callers, because the project verifies against a single secret
(`TURNSTILE_SECRET_KEY` in the `ci` environment, deployed by
`supabase-deploy` from `main` like `SMTP_PASS`, ADR 0010). The site key is
public and lives in each caller's build configuration.

What it buys: every code mail and every probe of the 422-vs-200 answer now
costs a solved Turnstile challenge, which a script cannot mint in bulk.
`email_sent` stays at 30 per hour as the safety net behind it. A per-address
throttle in a `send_email` hook was considered and deferred: it cannot tell
the app from the web page, and the check removes the cheap burst it would
have caught.

Rollout, so that nothing breaks in between: the web page and the app send
tokens first (GoTrue ignores them while the captcha is off), the app's
first such version (2.0.1) reaches the beta tracks, and only then does one
merge switch the captcha on in production and raise `MIN_APP_VERSION` to
2.0.1, so an older build is sent to the update screen instead of failing at
sign-in.

What it costs:

- **Cloudflare becomes a recipient**: the IP address, TLS fingerprint and
  user agent of whoever asks, and Cloudflare uses those signals for its own
  bot detection as a controller (its Turnstile privacy addendum). Both
  privacy notices say so; the consent wording is untouched, because the
  check never sees a journal.
- **Every password grant needs a token too**, including the store reviewer
  accounts (through the app, unchanged for them) and every script that
  signs in with a password: the nightly live smoke, the latency probe, and
  `run-app.sh`'s credential check. None of them can solve a challenge, and
  GoTrue's only bypass is a service-role key, which ADR 0010 keeps out of
  CI. How they sign in under enforcement is
  [#304](https://github.com/trost-systems/emotely/issues/304), and the
  captcha is not switched on in production before it is settled.
- **The free plan is sized for it**: unlimited challenges and siteverify
  calls, 20 widgets, 10 hostnames per widget.

Verified after the deploy that switches it on, from any machine, with the
publishable key and an address that has an account:

```bash
# No token, then Cloudflare's public dummy token: both 400 captcha_failed,
# and no mail arrives.
curl -s -o /dev/null -w '%{http_code}\n' -H "apikey: $KEY" -H 'content-type: application/json' \
  -d '{"email":"test@getemotely.com","create_user":false}' "$URL/auth/v1/otp"
curl -s -o /dev/null -w '%{http_code}\n' -H "apikey: $KEY" -H 'content-type: application/json' \
  -d '{"email":"test@getemotely.com","create_user":false,"gotrue_meta_security":{"captcha_token":"XXXX.DUMMY.TOKEN.XXXX"}}' \
  "$URL/auth/v1/otp"
# A burst of 40 such requests (above the hourly cap of 30), then a real
# sign-in from the app: its code still arrives, so the burst spent nothing.
```

The same 400 answers an unknown address, so the 422-vs-200 oracle needs a
solved challenge per probe.
