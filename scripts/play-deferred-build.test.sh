#!/usr/bin/env bash
# Tests for play-deferred-build.sh, with a fake `gh` on the PATH that answers
# `gh api` from canned JSON and applies the script's own --jq filter with jq,
# so the filters are tested too. Run from anywhere:
#   bash scripts/play-deferred-build.test.sh
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/play-deferred-build.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# The fake: the artifacts listing comes from FAKE_DIR/artifacts.json, a run
# from FAKE_DIR/run-<id>.json; anything else is an error.
mkdir -p "${work}/bin"
cat >"${work}/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == api ]] || exit 64
shift
path="" filter="."
while (($#)); do
  case "$1" in
    --paginate) ;;
    --jq) filter="$2"; shift ;;
    *) path="$1" ;;
  esac
  shift
done
case "${path}" in
  repos/trost-systems/emotely/actions/artifacts\?name=play-internal-deferred-aab\&per_page=100)
    file="${FAKE_DIR}/artifacts.json" ;;
  repos/trost-systems/emotely/actions/runs/*)
    file="${FAKE_DIR}/run-${path##*/}.json" ;;
  *) printf 'fake gh: unexpected path %s\n' "${path}" >&2; exit 65 ;;
esac
jq -r "${filter}" "${file}"
EOF
chmod +x "${work}/bin/gh"

# An artifact of `run` on `branch`, as the artifacts listing shows it.
artifact() {
  local id="$1" run="$2" branch="${3:-main}" expired="${4:-false}"
  printf '{"id":%s,"name":"play-internal-deferred-aab","expired":%s,"workflow_run":{"id":%s,"head_branch":"%s"}}' \
    "${id}" "${expired}" "${run}" "${branch}"
}

# A fresh fake API: the artifacts given, and one run file per "id:number[:path[:event]]".
api() {
  FAKE_DIR="${work}/api-${RANDOM}"
  mkdir -p "${FAKE_DIR}"
  local listing="$1"
  shift
  printf '{"total_count":0,"artifacts":[%s]}\n' "${listing}" >"${FAKE_DIR}/artifacts.json"
  local run id number path event
  for run in "$@"; do
    IFS=: read -r id number path event <<<"${run}"
    printf '{"id":%s,"run_number":%s,"path":"%s","event":"%s"}\n' \
      "${id}" "${number}" "${path:-.github/workflows/app-release.yml}" "${event:-push}" >"${FAKE_DIR}/run-${id}.json"
  done
  export FAKE_DIR
}

# Runs the script; sets `status` and `output`.
run() {
  set +e
  output="$(PATH="${work}/bin:${PATH}" bash "${script}" trost-systems/emotely 2>&1)"
  status=$?
  set -e
}

test_prints_nothing_when_no_build_waits() {
  api ''
  run
  [[ ${status} -eq 0 && -z "${output}" ]] || fail "no artifact: exit ${status}: ${output}"
}

test_names_the_one_deferred_build() {
  api "$(artifact 501 9001)" 9001:123
  run
  local expected=$'build=1123\nrun_id=9001\nartifacts=501'
  [[ ${status} -eq 0 && "${output}" == "${expected}" ]] || fail "one build: exit ${status}: ${output}"
}

test_the_newest_run_wins_and_every_artifact_is_listed() {
  api "$(artifact 503 9003),$(artifact 502 9002)" 9003:125 9002:124
  run
  local expected=$'build=1125\nrun_id=9003\nartifacts=503 502'
  [[ ${status} -eq 0 && "${output}" == "${expected}" ]] || fail "two builds: exit ${status}: ${output}"
}

# A re-run of an older run uploads its artifact last; its build is still older.
test_the_newest_run_wins_over_the_newest_upload() {
  api "$(artifact 504 9002),$(artifact 503 9003)" 9002:124 9003:125
  run
  [[ "${output}" == *"build=1125"* && "${output}" == *"run_id=9003"* ]] ||
    fail "a re-run's later upload won: ${output}"
}

test_ignores_artifacts_from_other_branches_and_expired_ones() {
  api "$(artifact 505 9005 feature),$(artifact 504 9004 main true),$(artifact 503 9003)" 9003:123
  run
  local expected=$'build=1123\nrun_id=9003\nartifacts=503'
  [[ "${output}" == "${expected}" ]] || fail "branch or expiry not filtered: ${output}"
}

test_ignores_artifacts_of_other_workflows_and_events() {
  api "$(artifact 506 9006),$(artifact 505 9005),$(artifact 503 9003)" \
    9006:300:.github/workflows/ci.yml 9005:301:.github/workflows/app-release.yml:workflow_dispatch 9003:123
  run
  local expected=$'build=1123\nrun_id=9003\nartifacts=503'
  [[ "${output}" == "${expected}" ]] || fail "another workflow's artifact counted: ${output}"
}

test_prints_nothing_when_only_foreign_artifacts_exist() {
  api "$(artifact 506 9006)" 9006:300:.github/workflows/ci.yml
  run
  [[ ${status} -eq 0 && -z "${output}" ]] || fail "foreign artifact only: exit ${status}: ${output}"
}

test_refuses_without_a_repository() {
  set +e
  output="$(PATH="${work}/bin:${PATH}" bash "${script}" 2>&1)"
  status=$?
  set -e
  [[ ${status} -ne 0 && "${output}" == *usage* ]] || fail "no repository: exit ${status}: ${output}"
}

for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "${test}"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "${failures}" >&2
  exit 1
fi
printf 'play-deferred-build.sh: all tests passed\n'
