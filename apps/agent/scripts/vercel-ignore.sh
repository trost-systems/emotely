#!/usr/bin/env sh
# Vercel "Ignored Build Step" for emotely-agent (wired via ignoreCommand in
# vercel.json): skips the deployment unless one of the agent's build inputs
# changed. Which commit it diffs against is decided in the shared
# scripts/vercel-ignore.sh; the list of inputs is this project's.
#
# Runs in the project's Root Directory (apps/agent). Pathspecs use the `:/`
# prefix so they resolve from the repo top level.
set -u

top="$(git rev-parse --show-toplevel)" || exit 1

# Everything the agent build reads. Keep in sync with the workspace layout.
exec sh "$top/scripts/vercel-ignore.sh" agent \
  :/apps/agent \
  :/packages \
  :/pnpm-lock.yaml \
  :/pnpm-workspace.yaml \
  :/package.json \
  :/tsconfig.base.json \
  :/.nvmrc \
  :/.vercelignore
