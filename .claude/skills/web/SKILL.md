---
name: web
description: How to run, test, build and deploy the landing page (apps/web, Jaspr/Dart, getemotely.com), including the headless-Chrome form tests and the Vercel project wiring. Use whenever touching apps/web, the waitlist form, the site copy, or the site's Vercel deployment.
---

# The landing page (apps/web)

A static [Jaspr](https://jaspr.site) site in Dart: `lib/main.server.dart`
renders every route to HTML at build time, `lib/main.client.dart` mounts the
`@client` islands in the browser: the waitlist form, the waitlist
confirmation, and the account-deletion form (`components/`). Plain
CSS in `web/styles.css`. No Node anywhere in this app. The site's copy
uses [`CONTEXT.md`](../../../CONTEXT.md)'s terms, like every surface a user
reads.

The site speaks English at `/…` and German at `/de/…`, by path only — no
redirect, nothing read from the browser. `germanPaths` in
`lib/site_locale.dart` is the one table of translated pages: a German page
is a route in the German `ShellRoute` of `lib/app.dart`, a row in that
table, and a page under `lib/pages/de/`. The shell (`lib/site_shell.dart`)
derives `<html lang>`, the `hreflang` alternates and the language switch
from the table, and `site_test.dart` checks each row renders, lists itself
and its pair, and keeps the original's sections. An island takes its
language as `lang` (a `SiteLocale` code), because `@client` parameters
must be serializable.

Everything below is agent-executable; run from `apps/web`.

## Run

```bash
dart pub get
dart pub global activate jaspr_cli 0.23.4   # tracks the jaspr version in pubspec.yaml
jaspr serve                                  # http://localhost:8080, hot reload
```

## Check (what CI runs, in this order)

```bash
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test                                    # VM: pages + the HTTP call
dart test -p chrome test/client              # headless Chrome: the form island
jaspr build --sitemap-domain https://getemotely.com   # → build/jaspr
git diff --exit-code -- lib                  # generated *.options.dart must not drift
```

A global hook denies `dart test` / `flutter test` to agents and points at
the very_good CLI MCP `test` tool instead. That tool is the agent-side
equivalent of the two test lines above, with one catch: run it with
**`optimization: false`**. Its test optimizer bundles every file into one
VM entrypoint, which pulls the `@TestOn('browser')` files in `test/client`
into a VM compile and fails on `dart:js_interop`. Pass `platform: chrome`
plus `paths: ["test/client"]` for the browser half. CI is unaffected — it
runs the plain commands above.

Rules the lints enforce beyond `apps/mobile/app`: `jaspr_lints` (HTML helpers over
`Component.element`, children last, styles ordered). `@client` files must
use classic constructors — `jaspr_builder` parses them with analyzer 12,
which cannot read primary constructors; the per-file ignore in
`waitlist_form.dart` says so.

## Fonts and icons

`web/fonts/` holds the site's two faces as latin `woff2` subsets next to
their SIL OFL licenses: Baskervville (every word, the app's text face too)
and Sacramento (the wordmark, as in the legacy logo). They are served from
the site on purpose — a `fonts.googleapis.com` link would hand visitor IPs
to Google (LG München I, 3 O 17493/20) and contradict the privacy page. To
add a face or subset, download the `woff2` from the Google Fonts CSS
(`curl -A "<Chrome UA>" "https://fonts.googleapis.com/css2?family=..."`
lists the URLs per unicode range), drop it in `web/fonts/`, add the OFL
file from `github.com/google/fonts/tree/main/ofl/<family>`, and declare it
in `web/styles.css`.

The icons (`favicon.svg`, `favicon.ico`, `apple-touch-icon.png`) are the
legacy emotely mark from Peter's iCloud (`emotely/SVG/favicon_1.svg`):
render the SVG with `qlmanage -t -s 1024`, then `magick` for the ICO
(48/32/16) and the 180 px PNG.

## Testing the island

`@client` components only take serializable parameters, so the HTTP client
is not injected. The form calls `http.Client()`, which honors
`http.runWithClient`; tests wrap pump + interaction in it with a
`MockClient` (`package:http/testing.dart`). Drive the DOM with
`tester.input(find.byKey(...), value: ...)` and `tester.click(...)`, then
`await pumpEventQueue()`. `testComponents` (VM) cannot fire input events —
its `web.Event` has no target — so anything that reads an input runs under
`testClient` in Chrome.

## What the form talks to

`lib/waitlist.dart` posts to `public.waitlist` with the publishable key and
`Prefer: return=minimal`. The table (`supabase/migrations/*_waitlist.sql`,
ADR 0011) owns validation, silent de-duplication and rate limits and answers
201 / 429 (`PT429`) / 400. The row carries the page's `locale` (`en`, `de`),
and the confirmation mail the database sends is written in it and links to
that language's `/confirm?t=<token>` or `/de/confirm?t=<token>`; that page's
island (`components/confirm_waitlist.dart`) calls the RPC `confirm_waitlist`
once and shows confirmed / no longer valid / retry.

The site and the database deploy separately, in no fixed order, so a new
column the form sends must not break sign-ups while the migration is not yet
live: PostgREST answers an unknown key with 400 `PGRST204` naming it, which
`joinWaitlist` reads as "not yet" and retries without that key. Do the same
for the next column the form starts sending.

`lib/delete_account.dart` is the third island's seam (`/delete-account`,
`components/delete_account_form.dart`), the web deletion route Google Play's
Data safety form requires. Two calls to GoTrue with the same publishable
key — `POST /auth/v1/otp` with `create_user: false` so a deletion request
never creates an account, then `POST /auth/v1/verify` — and the access token
that comes back calls `rpc/delete_account` as the user, under RLS. Nothing
privileged is involved, the page requires the function's `true` before it
claims anything, and a verify that mints a session which then fails to
delete is followed by `POST /auth/v1/logout`, so no session outlives the
attempt.

`create_user: false` makes GoTrue answer 422 `otp_disabled` for an unknown
address and 200 for a known one; both map to `sent` and the copy is
conditional ("if that address has an account"). That does **not** close the
oracle and the page is not what opens it — `/auth/v1/otp` is public, the
app's own sign-in calls it the same way, and a scripted caller reads the
422-vs-200 (or the send latency) straight from GoTrue. Closing it needs a
server-side control, tracked in
[#94](https://github.com/trost-systems/emotely/issues/94); what the page owes
its reader is not to answer the question for them. The events it sends
carry an outcome name only — no address, no code.

Every island is pre-rendered at build time, so anything that needs
`window` sits behind `kIsWeb`. To exercise it locally, `supabase start` and pass
`--dart-define=EMOTELY_SUPABASE_URL=http://127.0.0.1:54321` plus the local
anon key to `jaspr serve` (see `lib/environment.dart`).

## Deploy

Vercel project `emotely-web` (`prj_Pd7GyDWACqua2yHuQFUbY6f8AQFn`), root
directory `apps/web`, GitHub integration on `trost-systems/emotely`.
Production: `getemotely.com`; `www.getemotely.com` redirects (308) to it.
`vercel.json` names the steps:

- `scripts/vercel-install.sh` — fetches Dart 3.13.3 (pinned, sha256 checked)
  because the build image has none, `dart pub get`, activates `jaspr_cli`.
- `scripts/vercel-build.sh` — `jaspr build` with the sitemap, then prunes the
  package assets `build_web_compilers` copies next to the JS.
- `scripts/vercel-ignore.sh` — exit 0 (skip) unless `apps/web` changed, so
  agent- or app-only PRs never build or preview the site. The agent project
  has the mirror image.

Bumping Dart: change `DART_VERSION` and `DART_SHA256` in the install script
(checksum from `…/sdk/dartsdk-linux-x64-release.zip.sha256sum` on the Dart
archive), the `sdk:` in `.github/workflows/ci.yml`, and the constraint in
`pubspec.yaml`.

Preview deployments are SSO-protected (Vercel default); production is
public. Inspect a build with `vercel inspect <url> --logs`.
