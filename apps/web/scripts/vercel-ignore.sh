#!/usr/bin/env sh
# Vercel "Ignored Build Step" for emotely-web (wired via ignoreCommand in
# vercel.json): skips the deployment unless one of the site's build inputs
# changed, so an agent-only or app-only PR never builds (or previews) the
# site. Which commit it diffs against is decided in the shared
# scripts/vercel-ignore.sh; the list of inputs is this project's.
#
# Runs in the project's Root Directory (apps/web). Pathspecs use the `:/`
# prefix so they resolve from the repo top level.
set -u

top="$(git rev-parse --show-toplevel)" || exit 1

# Everything the site build reads. Keep in sync with the layout.
exec sh "$top/scripts/vercel-ignore.sh" site \
  :/apps/web
