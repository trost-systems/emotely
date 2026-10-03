#!/usr/bin/env bash
# Tests for vercel-ignore.sh, the Ignored Build Step both Vercel projects run.
# Each test builds a throwaway "GitHub" repository in a temp dir, clones it
# the way Vercel does (shallow, --depth=10) and runs the script inside the
# clone with the VERCEL_GIT_* variables Vercel would set. Exit 0 skips the
# deployment, exit 1 builds it. Run from anywhere:
#   bash scripts/vercel-ignore.test.sh
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${scripts}/.." && pwd)"
script="${scripts}/vercel-ignore.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Commits in the throwaway repositories must not depend on the machine's git
# configuration (signing, hooks, default branch) or leak Vercel's variables.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset VERCEL_ENV VERCEL_GIT_COMMIT_REF VERCEL_GIT_COMMIT_SHA \
  VERCEL_GIT_PREVIOUS_SHA VERCEL_GIT_PROVIDER VERCEL_GIT_REPO_OWNER \
  VERCEL_GIT_REPO_SLUG

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A fresh origin with one commit on main holding the project's input (app/)
# and a file outside it (other/). Prints its path.
new_origin() {
  local origin="${work}/${RANDOM}${RANDOM}/origin"
  mkdir -p "${origin}"
  git -C "${origin}" init --quiet --initial-branch=main
  mkdir -p "${origin}/app" "${origin}/other"
  echo 0 >"${origin}/app/input"
  echo 0 >"${origin}/other/file"
  git -C "${origin}" add app other
  git -C "${origin}" commit --quiet --message initial
  printf '%s' "${origin}"
}

# Appends a line to <path> in <origin>, commits it on the checked-out branch
# and prints the new commit.
commit() {
  local origin="$1" path="$2"
  mkdir -p "$(dirname "${origin}/${path}")"
  echo "${RANDOM}" >>"${origin}/${path}"
  git -C "${origin}" add "${path}"
  git -C "${origin}" commit --quiet --message "change ${path}"
  git -C "${origin}" rev-parse HEAD
}

# Makes <count> commits that touch only other/ and prints the last one.
commits_elsewhere() {
  local origin="$1" count="$2" sha=""
  for _ in $(seq "${count}"); do
    sha="$(commit "${origin}" other/file)"
  done
  printf '%s' "${sha}"
}

branch() {
  git -C "$1" switch --quiet --create "$2" "${3:-main}"
}

# Clones <branch> of <origin> as Vercel does and prints the clone's path. The
# clone keeps `origin` as its remote.
vercel_clone() {
  local origin="$1" ref="$2"
  local clone
  clone="$(dirname "${origin}")/clone-${RANDOM}"
  git clone --quiet --no-local --depth=10 --branch "${ref}" "file://${origin}" "${clone}"
  printf '%s' "${clone}"
}

# Runs the script in <clone> for <ref> with the given VERCEL_GIT_PREVIOUS_SHA
# (empty for none) and any further VAR=value pairs; prints the exit code.
run() {
  local clone="$1" ref="$2" previous="$3"
  shift 3
  local code=0
  (
    cd "${clone}" &&
      env VERCEL_GIT_COMMIT_REF="${ref}" \
        VERCEL_GIT_COMMIT_SHA="$(git rev-parse HEAD)" \
        VERCEL_GIT_PREVIOUS_SHA="${previous}" "$@" \
        sh "${script}" test :/app
  ) >"${clone}.log" 2>&1 || code=$?
  printf '%s' "${code}"
}

expect() {
  local name="$1" want="$2" code="$3" clone="$4"
  local got
  case "${code}" in
    0) got=skip ;;
    1) got=build ;;
    *) got="exit ${code}" ;;
  esac
  [[ "${got}" == "${want}" ]] ||
    fail "${name}: wanted ${want}, got ${got}; script said: $(cat "${clone}.log")"
}

test_previous_deployment_and_inputs_unchanged_skips() {
  local origin clone previous
  origin="$(new_origin)"
  branch "${origin}" feature
  previous="$(commit "${origin}" app/input)"
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  expect "previous deployment, inputs unchanged since" skip \
    "$(run "${clone}" feature "${previous}")" "${clone}"
}

test_previous_deployment_and_inputs_changed_builds() {
  local origin clone previous
  origin="$(new_origin)"
  branch "${origin}" feature
  previous="$(commit "${origin}" other/file)"
  commit "${origin}" app/input >/dev/null
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  expect "previous deployment, inputs changed since" build \
    "$(run "${clone}" feature "${previous}")" "${clone}"
}

# The deployment before HEAD^ changed the inputs and failed, so the previous
# successful one lies outside the shallow clone; diffing HEAD^ would skip.
test_previous_deployment_outside_the_shallow_clone_builds() {
  local origin clone previous
  origin="$(new_origin)"
  branch "${origin}" feature
  previous="$(commit "${origin}" other/file)"
  commit "${origin}" app/input >/dev/null
  commits_elsewhere "${origin}" 12 >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  expect "previous deployment outside the shallow clone" build \
    "$(run "${clone}" feature "${previous}")" "${clone}"
}

# Issue #258: a new branch's first push, whose last commit leaves the inputs
# alone while an earlier one changed them.
test_first_push_with_an_earlier_input_change_builds() {
  local origin clone
  origin="$(new_origin)"
  branch "${origin}" feature
  commit "${origin}" app/input >/dev/null
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  expect "first push, an earlier commit changed the inputs" build \
    "$(run "${clone}" feature "")" "${clone}"
}

# Vercel's clone may have no remote at all; the script then fetches from the
# GitHub repository the deployment names (here redirected to the origin).
test_first_push_without_a_remote_fetches_from_github() {
  local origin clone
  origin="$(new_origin)"
  branch "${origin}" feature
  commit "${origin}" app/input >/dev/null
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"
  git -C "${clone}" remote remove origin

  expect "first push without a remote" build \
    "$(run "${clone}" feature "" \
      VERCEL_GIT_PROVIDER=github VERCEL_GIT_REPO_OWNER=owner \
      VERCEL_GIT_REPO_SLUG=repo GIT_CONFIG_COUNT=1 \
      GIT_CONFIG_KEY_0="url.file://${origin}.insteadOf" \
      GIT_CONFIG_VALUE_0=https://github.com/owner/repo.git)" "${clone}"
}

# The fork point lies deeper than the clone's ten commits.
test_first_push_of_a_long_branch_builds() {
  local origin clone
  origin="$(new_origin)"
  branch "${origin}" feature
  commit "${origin}" app/input >/dev/null
  commits_elsewhere "${origin}" 15 >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  expect "first push of a branch longer than the clone" build \
    "$(run "${clone}" feature "")" "${clone}"
}

# The diff is against the merge base, not main's tip: inputs main changed
# after the branch forked are not the branch's.
test_first_push_without_input_changes_skips() {
  local origin clone
  origin="$(new_origin)"
  branch "${origin}" feature
  commits_elsewhere "${origin}" 3 >/dev/null
  git -C "${origin}" switch --quiet main
  commit "${origin}" app/input >/dev/null
  git -C "${origin}" switch --quiet feature
  clone="$(vercel_clone "${origin}" feature)"

  expect "first push, no commit changed the inputs" skip \
    "$(run "${clone}" feature "")" "${clone}"
}

test_first_push_without_a_reachable_base_builds() {
  local origin clone
  origin="$(new_origin)"
  branch "${origin}" feature
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"
  git -C "${clone}" remote remove origin

  expect "first push, no remote to fetch main from" build \
    "$(run "${clone}" feature "")" "${clone}"
  expect "previous deployment unreachable, no remote" build \
    "$(run "${clone}" feature 0123456789abcdef0123456789abcdef01234567)" "${clone}"
}

test_production_on_main() {
  local origin clone previous
  origin="$(new_origin)"
  previous="$(commit "${origin}" app/input)"
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" main)"
  expect "main, inputs unchanged since the last production deployment" skip \
    "$(run "${clone}" main "${previous}" VERCEL_ENV=production)" "${clone}"
  # Without a previous deployment the merge base with main is HEAD itself,
  # which would skip every first production deployment.
  expect "main without a previous deployment" build \
    "$(run "${clone}" main "" VERCEL_ENV=production)" "${clone}"

  origin="$(new_origin)"
  previous="$(commit "${origin}" other/file)"
  commit "${origin}" app/input >/dev/null
  clone="$(vercel_clone "${origin}" main)"
  expect "main, inputs changed since the last production deployment" build \
    "$(run "${clone}" main "${previous}" VERCEL_ENV=production)" "${clone}"
}

# Each project's wrapper hands its own input list to the shared script.
test_project_wrappers() {
  local origin clone
  origin="$(new_origin)"
  mkdir -p "${origin}/scripts" "${origin}/apps/agent/scripts" "${origin}/apps/web/scripts"
  cp "${script}" "${origin}/scripts/"
  cp "${repo}/apps/agent/scripts/vercel-ignore.sh" "${origin}/apps/agent/scripts/"
  cp "${repo}/apps/web/scripts/vercel-ignore.sh" "${origin}/apps/web/scripts/"
  git -C "${origin}" add scripts apps
  git -C "${origin}" commit --quiet --message wrappers
  branch "${origin}" feature
  commit "${origin}" packages/contract/x >/dev/null
  commit "${origin}" other/file >/dev/null
  clone="$(vercel_clone "${origin}" feature)"

  local code
  code=0
  (cd "${clone}/apps/agent" && sh scripts/vercel-ignore.sh) >"${clone}.log" 2>&1 || code=$?
  expect "agent wrapper, packages changed" build "${code}" "${clone}"
  code=0
  (cd "${clone}/apps/web" && sh scripts/vercel-ignore.sh) >"${clone}.log" 2>&1 || code=$?
  expect "web wrapper, packages changed" skip "${code}" "${clone}"
}

test_previous_deployment_and_inputs_unchanged_skips
test_previous_deployment_and_inputs_changed_builds
test_previous_deployment_outside_the_shallow_clone_builds
test_first_push_with_an_earlier_input_change_builds
test_first_push_without_a_remote_fetches_from_github
test_first_push_of_a_long_branch_builds
test_first_push_without_input_changes_skips
test_first_push_without_a_reachable_base_builds
test_production_on_main
test_project_wrappers

if ((failures > 0)); then
  printf '%d failed\n' "${failures}" >&2
  exit 1
fi
printf 'all passed\n'
