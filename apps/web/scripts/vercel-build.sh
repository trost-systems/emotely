#!/usr/bin/env sh
# Vercel "Build Command" for emotely-web: a static Jaspr build into
# build/jaspr (the project's Output Directory), sitemap included.
set -eu

export PATH="$PWD/.dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"

# POSTHOG_KEY is a plain (public) project env var on Vercel; unset means the
# site ships without the analytics script.
#
# /beta and /de/beta are unlisted: /beta is the single link an invitation
# mail carries, and listing either in sitemap.xml would hand it to every
# crawler that reads the sitemap. robots.txt stays clean for the same reason — a Disallow line
# would advertise the path rather than hide it.
jaspr build --sitemap-domain https://getemotely.com \
  --sitemap-exclude '^(/de)?/beta$' \
  --dart-define="POSTHOG_KEY=${POSTHOG_KEY:-}"

# build_web_compilers copies every package's non-Dart assets next to the
# compiled JS (analyzer docs, test runner pages, ...). Nothing in the site
# references them; only the compiled entrypoint and our own files ship.
rm -rf build/jaspr/.dart_tool build/jaspr/.build.manifest build/jaspr/packages
ls -la build/jaspr
