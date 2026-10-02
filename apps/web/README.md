# emotely web (getemotely.com)

The landing page: a static [Jaspr](https://jaspr.site) site in Dart, one
`@client` island (the waitlist form), plain CSS, no Node.

```
lib/
  main.server.dart        document shell, built once per route at build time
  main.client.dart        mounts the @client islands in the browser
  site_document.dart      the <head> every page shares
  app.dart                the router: one shell per language, its pages
  site_shell.dart         <html lang>, header and footer per language
  site_locale.dart        English at /…, German at /de/…, and which page has which
  pages/                  Home (the offer), Privacy, Imprint, …
  pages/de/               their German translations
  components/             WaitlistForm (@client)
  waitlist.dart           joinWaitlist(): the one HTTP call (ADR 0011)
  environment.dart        Supabase URL/key defaults (public by design)
web/                      styles.css, favicon, robots.txt
scripts/                  the Vercel install/build/ignore steps
```

## Run

Needs the Dart SDK on PATH (the Flutter SDK's `dart` works) and Chrome for
the browser tests.

```bash
dart pub get
dart pub global activate jaspr_cli 0.23.4
jaspr serve                      # http://localhost:8080, hot reload
```

## Check

```bash
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test                        # VM: pages and the HTTP client
dart test -p chrome test/client  # headless Chrome: the waitlist form
jaspr build --sitemap-domain https://getemotely.com   # → build/jaspr
```

The form talks to Supabase directly with the publishable key; what it may
do is decided in Postgres (`supabase/migrations/*_waitlist.sql`). Tests put
a fake behind `http.Client()` via `http.runWithClient`, so nothing leaves
the machine.

## Deploy

Vercel project `emotely-web`, root directory `apps/web`, git integration.
`vercel.json` names the steps: `scripts/vercel-install.sh` fetches the pinned
Dart SDK (the build image has none), `scripts/vercel-build.sh` runs
`jaspr build`, `scripts/vercel-ignore.sh` skips builds and previews that do
not touch `apps/web`. Production is `getemotely.com` (+ `www` redirect).
