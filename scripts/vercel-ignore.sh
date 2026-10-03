#!/usr/bin/env sh
# Vercel "Ignored Build Step" shared by emotely-agent and emotely-web. Each
# project's apps/<project>/scripts/vercel-ignore.sh (its vercel.json
# ignoreCommand) names its build inputs and runs this:
#
#   vercel-ignore.sh <project> <pathspec>...
#
# Exit 0 skips the deployment, exit 1 builds it. When in doubt, build.
#
# Why this exists: Vercel's built-in "skip unaffected projects" only knows the
# pnpm workspace graph. Everything outside a workspace package (apps/mobile,
# docs, AGENTS.md, ...) counts as a "global change" and deploys every
# project, so app-only PRs were building the agent and the site.
#
# What it diffs the inputs against:
# - The branch's last successful deployment (VERCEL_GIT_PREVIOUS_SHA, set only
#   when an Ignored Build Step is configured), so a change skipped in one
#   push is not lost when a later push touches nothing. Vercel clones with
#   --depth=10, so an older one is fetched.
# - On a branch's first deployment, where that is empty: the merge base with
#   main, so every commit on the branch counts, not only the last (#258).
# - Neither (main's first deployment, nothing fetchable): build.
#
# Vercel's clone may have no remote; then main is fetched from the public
# GitHub repository the deployment names.
set -u

project="$1"
shift
main=main

say() { echo "vercel-ignore: $*"; }
has_commit() { git cat-file -e "$1^{commit}" 2>/dev/null; }
fetch() { git fetch --quiet --no-tags "$@" 2>/dev/null; }

head="${VERCEL_GIT_COMMIT_SHA:-$(git rev-parse HEAD)}"

remote=""
if git remote get-url origin >/dev/null 2>&1; then
  remote=origin
elif [ "${VERCEL_GIT_PROVIDER:-}" = github ] &&
  [ -n "${VERCEL_GIT_REPO_OWNER:-}" ] && [ -n "${VERCEL_GIT_REPO_SLUG:-}" ]; then
  remote="https://github.com/$VERCEL_GIT_REPO_OWNER/$VERCEL_GIT_REPO_SLUG.git"
fi

# The previous deployment's commit, fetched if it lies outside the clone. A
# diff needs only both commits' trees, not the history between them.
previous_base() {
  previous="${VERCEL_GIT_PREVIOUS_SHA:-}"
  [ -n "$previous" ] || return 1
  if ! has_commit "$previous" && [ -n "$remote" ]; then
    fetch --depth=1 "$remote" "$previous"
  fi
  has_commit "$previous" && echo "$previous"
}

# The merge base of HEAD and main. In Vercel's shallow clone both histories
# are deepened until they meet; a full clone (a local run, where HEAD may be
# unpushed) fetches main whole and is never made shallow.
merge_base() {
  [ -n "$remote" ] || return 1
  main_ref="refs/vercel-ignore/$main"
  if [ "$(git rev-parse --is-shallow-repository)" != true ]; then
    fetch "$remote" "+refs/heads/$main:$main_ref" || return 1
    git merge-base "$main_ref" "$head" 2>/dev/null
    return
  fi
  for depth in 50 200 1000; do
    fetch --depth="$depth" "$remote" "+refs/heads/$main:$main_ref" "$head" ||
      return 1
    git merge-base "$main_ref" "$head" 2>/dev/null && return 0
  done
  return 1
}

if base="$(previous_base)"; then
  since="the last deployment"
elif [ "${VERCEL_GIT_COMMIT_REF:-}" = "$main" ]; then
  say "no previous deployment of $main to diff against; building"
  exit 1
elif base="$(merge_base)"; then
  since="the merge base with $main"
else
  say "no reachable previous deployment and no merge base with $main; building"
  exit 1
fi

git diff --quiet "$base" "$head" -- "$@"
case $? in
  0)
    say "no $project build input changed since $since ($base); skipping"
    exit 0
    ;;
  1) say "$project build inputs changed since $since ($base); building" ;;
  *) say "could not diff against $since ($base); building" ;;
esac
exit 1
