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

### Amendment 2026-10-03: a third rule for `/api/revoke-apple`

`POST /api/revoke-apple` (#193) revokes a user's Sign in with Apple grant
before their account is deleted. It needs a live Supabase session and only
ever revokes the Apple ID linked to that account, so it cannot reach anyone
else's grant; what it can cost is two calls to Apple and one to Supabase
per request, under our key. A real user calls it once, at deletion, so the
limit is far tighter than the others:

| Rule | Value |
| --- | --- |
| Project | `emotely-agent` → Firewall → Rules |
| Match | Request Path equals `/api/revoke-apple` |
| Limit | 10 requests / 60 s, fixed window, keyed by IP |
| Action | 429 Too Many Requests |

The app treats a 429 like any other refusal: the account is still deleted,
and the user is told where to remove emotely from their Apple Account.

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

vercel firewall rules add "Rate limit revoke-apple" \
  --project emotely-agent \
  --condition '{"type":"path","op":"eq","value":"/api/revoke-apple"}' \
  --action rate_limit --rate-limit-window 60 --rate-limit-requests 10 \
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
