---
name: force-update
description: How to raise the minimum app version so older builds are blocked with a force-update screen, and how to change the store links that screen sends users to. Use whenever asked to force an update, block an app version, raise MIN_APP_VERSION, retire a wire shape that old apps still use, or fix the store URL on the update screen.
---

# Forcing an update

The app reads `GET /api/config` once at startup, before sign-in, and blocks
with a force-update screen when its own version is below `min_app_version`
([ADR 0009](../../../docs/adr/0009-wire-compatibility.md)). Raising that
minimum is how a wire shape older apps depend on becomes deletable.

Both values are constants in
[`apps/agent/src/session-config.ts`](../../../apps/agent/src/session-config.ts),
so raising the minimum is an ordinary PR — reviewed, versioned next to the
code that needs it, and revertible through the same pipeline.

## Before you raise it

Check who you are about to block. `posthog_flutter` stamps `$app_version` on
every event, so the share of users below the candidate minimum is one
breakdown away. Raise only when that share is zero or knowingly accepted —
**a blocked user cannot do anything in the app except visit a store link.**

## Raise it

1. Edit `MIN_APP_VERSION` in `apps/agent/src/session-config.ts` to the oldest
   version you still want to serve (bare semver, `x.y.z`, no build number).
2. Open a PR, let `ci-ok` go green, merge. Merging deploys the agent.
3. Only now delete the endpoints or wire shapes the blocked versions needed.

The server refuses to start with a malformed value — `createConfigHandler`
parses it through the contract schema at cold start — so a typo fails the
deploy's first request instead of blocking every user on an unreadable
version.

## When it takes effect

Not instantly, twice over:

- The response is cached at the edge (`s-maxage=300`,
  `stale-while-revalidate=600`), so a raise takes a few minutes to reach every
  region.
- The app reads the config **at launch**. Someone already in a session keeps
  going until they next start the app.

Treat it as a planned step, not a stop button. To stop traffic now, the
firewall is the instrument, not this.

## Verify

```bash
curl -s https://api.getemotely.com/api/config | jq
curl -s 'https://api.getemotely.com/api/config?platform=ios' | jq -r .store_url
```

PostHog receives `update_required` with `min_app_version` and `app_version`
from every app that hits the screen, so the effect is measurable the same
hour.

## The store links

`store_url` is per platform: the app sends `?platform=ios|android` and the
server answers with that store's listing, falling back to a neutral link for
anything it does not recognize. They are server-side on purpose — **the only
people who ever follow that link are the ones who cannot install a build
carrying a corrected one.**

Defaults live beside the minimum (`STORE_URL`, `STORE_URL_IOS`,
`STORE_URL_ANDROID`; all the releases page until the store listings exist,
#9). Override per environment without an app release:

```bash
cd apps/agent   # the linked project directory
vercel env add EMOTELY_STORE_URL_IOS production < /path/to/url.txt
vercel redeploy <current-production-deployment-url>
```

`EMOTELY_STORE_URL` is the neutral fallback; `EMOTELY_STORE_URL_ANDROID` the
Play link. Environment variables apply to the next deployment, and the
Ignored Build Step skips commits that touch no agent input, so redeploy
explicitly.

## Undo

Revert the PR and merge; the deploy follows. The edge cache means the same
few minutes apply on the way back, so a mistaken raise is minutes of
blocked launches, not seconds. That asymmetry is the reason to check PostHog
first.
