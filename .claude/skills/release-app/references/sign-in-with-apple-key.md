# The Sign in with Apple key

The agent revokes a user's Sign in with Apple grant when they delete their
account (#193, App Store Review Guideline 5.1.1(v)): `POST /api/revoke-apple`
in `apps/agent` trades a fresh authorization code from the app for a refresh
token and revokes it at once. Every call to Apple authenticates with a client
secret, an ES256 JWT the agent signs per request with this key. Nothing is
stored, so nothing expires: the key itself never does, and the six-month
limit on client secrets does not apply to secrets minted for five minutes.

## What it is

| | |
| --- | --- |
| Portal | developer.apple.com → Certificates, Identifiers & Profiles → **Keys** |
| Team | `VCZSHMZY25` (petertrost.com) |
| Service | **Sign in with Apple**, primary App ID **`de.emotely.emotely`** |
| Name | `emotely Sign in with Apple` |
| File | `AuthKey_<KEY_ID>.p8`, downloadable **once** |

The App ID is the client: a native app's authorization code is issued to the
bundle identifier, not to a Services ID, so no Services ID is needed.

## Where it lives

Vercel project `emotely-agent`, **production** only. Preview deployments do
not carry it, so the route fails there at cold start; nothing else does.

| Variable | Value | Secret |
| --- | --- | --- |
| `APPLE_SIGN_IN_KEY` | the `.p8` file's contents | **yes** |
| `APPLE_SIGN_IN_KEY_ID` | the key's 10-character id | no |
| `APPLE_TEAM_ID` | `VCZSHMZY25` | no |
| `APPLE_CLIENT_ID` | `de.emotely.emotely` | no |
| `SUPABASE_PUBLISHABLE_KEY` | the project's `sb_publishable_…` key (the app's default in `apps/mobile/app/lib/app/environment.dart`) | no |

The function throws at cold start without any of them, so a missing variable
is a 500 on every call, never a silent skip. The app treats any failure as
"not revoked": it deletes the account anyway and tells the user where to
remove emotely from their Apple Account.

**No backup is kept.** The Vercel environment holds the only copy. Nothing
is encrypted or signed with the key that outlives a request, so a lost key
costs nothing to replace: create a new one and follow
[Rotating it](#rotating-it).

## Creating it (human step: production access)

1. In the portal, **Keys → +**, name it as above, tick **Sign in with Apple**,
   **Configure** → Primary App ID `de.emotely.emotely` → **Save** →
   **Continue** → **Register**.
2. Note the **Key ID**, then **Download** the `.p8`. Apple offers it once.
3. Store it, blind, from `apps/agent` (the linked project directory). The key
   is read from the file, never from a terminal argument or the transcript:

   ```bash
   key=~/Downloads/AuthKey_<KEY_ID>.p8
   head -1 "$key" | grep -qx -- '-----BEGIN PRIVATE KEY-----' && wc -c < "$key"
   vercel env add APPLE_SIGN_IN_KEY production < "$key"
   printf %s '<KEY_ID>' | vercel env add APPLE_SIGN_IN_KEY_ID production
   printf %s VCZSHMZY25 | vercel env add APPLE_TEAM_ID production
   printf %s de.emotely.emotely | vercel env add APPLE_CLIENT_ID production
   printf %s 'sb_publishable_…' | vercel env add SUPABASE_PUBLISHABLE_KEY production
   rm -P "$key"
   ```

   The first line checks the shape and prints only the length (a P-256
   `.p8` is about 250 bytes). The downloaded file is deleted once stored:
   no copy is kept outside Vercel.
4. Redeploy production (`vercel redeploy <current-production-deployment-url>`;
   the Ignored Build Step skips commits that touch no agent input).
5. Verify by behavior, not by reading the value back:

   ```bash
   vercel env ls production | grep -E 'APPLE_|SUPABASE_PUBLISHABLE_KEY'
   curl -s -o /dev/null -w '%{http_code}\n' -X POST \
     https://api.getemotely.com/api/revoke-apple
   ```

   `401` means the function started with every variable and refused the
   anonymous call; `500` means one is missing or the key will not import.
   The end-to-end check is deleting a throwaway account that signed in
   with Apple on an iPhone: emotely leaves Settings → Apple Account →
   Sign-In & Security → Sign in with Apple.

## Rotating it

Apple keys do not expire; rotate only when the `.p8` may have leaked or the
key is revoked. There is no grace window to manage: each request mints its
own client secret, so the new key works from the deployment that carries it.

1. Create a new key as above, keeping the old one for now.
2. `vercel env update APPLE_SIGN_IN_KEY production < new.p8` and
   `printf %s '<NEW_KEY_ID>' | vercel env update APPLE_SIGN_IN_KEY_ID production`,
   then redeploy and verify as above.
3. **Revoke the old key** in the portal. A leak is closed only once the old
   key is revoked.

Revocations in the window between steps 2 and 3 are unaffected; a deletion
in the seconds of a redeploy that fails is told so in the app, like any
other Apple outage.

## Abuse controls

The route needs a live Supabase session and revokes only the Apple ID linked
to that account, so it cannot be used on anyone else's grant. It still gets
its own WAF rate-limit rule
([ADR 0008](../../../../docs/adr/0008-public-endpoint-abuse-controls.md)):
a real user calls it once, when they delete their account. The rule lives
on the Vercel project, not in the repository; it is added once, after the
route is deployed, from `apps/agent`:

```bash
vercel firewall rules add "Rate limit revoke-apple" \
  --project emotely-agent \
  --condition '{"type":"path","op":"eq","value":"/api/revoke-apple"}' \
  --action rate_limit --rate-limit-window 60 --rate-limit-requests 10 \
  --rate-limit-keys ip --rate-limit-action rate_limit --yes
vercel firewall diff --project emotely-agent      # review
vercel firewall publish --project emotely-agent   # make live
```

The nightly live smoke (`pnpm --filter @emotely/agent smoke`) makes two
calls to the route — one anonymous (401) and one signed in without a code
(400) — well inside the limit, and fails on a 500, which is what a missing
variable or a key that will not load looks like.
