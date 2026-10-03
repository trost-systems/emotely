#!/usr/bin/env bash
# Finds the newest build app-release deferred for the Play internal track:
# `android internal` ends green without uploading while something is in
# Google's review, and app-release keeps that build's App Bundle as the
# artifact `play-internal-deferred-aab`. play-internal-catch-up.yml asks this
# script every hour, before it touches a secret.
#
#   play-deferred-build.sh <owner/repo>
#
# Prints GitHub step outputs: `build` (1000 + app-release's run number, the
# BUILD_NUMBER app-release gave it), `run_id` (the run holding the newest
# artifact) and `artifacts` (the ids of every deferred artifact, newest
# included, for the workflow to delete once the track has caught up). Prints
# nothing when no build waits. Needs gh (GH_TOKEN with actions: read) and jq.
set -euo pipefail

refuse() {
  printf 'play-deferred-build: %s\n' "$1" >&2
  exit 1
}

(($# == 1)) || refuse "usage: play-deferred-build.sh <owner/repo>"
repo="$1"

# Unexpired artifacts from main only: the `release` environment deploys from
# main alone, so another branch's artifact is not one app-release made.
artifacts="$(gh api --paginate \
  "repos/${repo}/actions/artifacts?name=play-internal-deferred-aab&per_page=100" \
  --jq '.artifacts[] | select(.expired == false and .workflow_run.head_branch == "main") | "\(.id) \(.workflow_run.id)"')"
[[ -n "${artifacts}" ]] || exit 0

# Newest by run number, not by upload time: re-running an older run uploads
# its artifact later, and its build is still the older one.
newest_number=0 newest_run="" ids=()
while read -r artifact run; do
  [[ "${artifact}" =~ ^[0-9]+$ && "${run}" =~ ^[0-9]+$ ]] || refuse "unexpected artifact '${artifact}' of run '${run}'"
  read -r number path event < <(gh api "repos/${repo}/actions/runs/${run}" --jq '"\(.run_number) \(.path) \(.event)"')
  # Only app-release's own pushes to main: its run number is the build's.
  [[ "${path}" == .github/workflows/app-release.yml && "${event}" == push ]] || continue
  [[ "${number}" =~ ^[1-9][0-9]*$ ]] || refuse "run ${run} has no run number"
  ids+=("${artifact}")
  if ((number > newest_number)); then
    newest_number="${number}" newest_run="${run}"
  fi
done <<<"${artifacts}"
[[ -n "${newest_run}" ]] || exit 0

# The same number app-release.yml's android-internal job built with
# (BUILD_NUMBER = 1000 + run number).
printf 'build=%s\nrun_id=%s\nartifacts=%s\n' "$((1000 + newest_number))" "${newest_run}" "${ids[*]}"
