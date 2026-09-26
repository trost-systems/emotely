#!/usr/bin/env bash
# Tests for feature-map.sh, through its command line only: a throwaway git
# repository with this repository's rules and the script in, feature sources
# and a feature map written per test, the messages and the exit code out.
# What the route rule matches is tested by `ast-grep test --include-off`
# (ast-grep/tests/feature-map); this covers what the rule alone cannot: which
# files are read, the full location of a nested route, the comparison with the
# map, and the messages. ast-grep, jq and yq must be on PATH:
#   pnpm exec bash scripts/feature-map.test.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

readonly map=.claude/skills/run-app/references/feature-map.yaml

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A fresh git repository with the rules and the script, and the files named
# in the arguments, each followed by its content, tracked.
repo() {
  local dir="${work}/repo-${RANDOM}"
  mkdir -p "${dir}/scripts"
  git -C "${dir}" init --quiet
  cp "${root}/sgconfig.yml" "${dir}/"
  cp -R "${root}/ast-grep" "${dir}/"
  cp "${root}/scripts/feature-map.sh" "${dir}/scripts/"
  while (($# > 0)); do
    write "${dir}/$1" "$2"
    git -C "${dir}" add -- "$1"
    shift 2
  done
  printf '%s' "${dir}"
}

write() {
  mkdir -p "$(dirname "$1")"
  printf '%b' "$2" >"$1"
}

# A feature's routes.dart: the journal with its entries under it.
readonly journal_routes="@TypedGoRoute<JournalRoute>(
  path: '/',
  name: 'journal',
  routes: [
    TypedGoRoute<EntryRoute>(
      path: 'entries/:id',
      routes: [TypedGoRoute<ShareRoute>(path: 'share')],
    ),
  ],
)
class const JournalRoute() extends GoRouteData with \$JournalRoute {}
"
readonly session_routes="@TypedGoRoute<SessionRoute>(path: \"/session\", name: 'session')
class const SessionRoute() extends GoRouteData with \$SessionRoute {}
"

# One map entry with every field the check asks for.
entry() {
  printf '  - route: %s\n    package: %s\n    path: %s\n' "$1" "$2" "$3"
  printf '    reach: [Tap app_shell.journal.]\n'
  printf '    does: Shows it.\n'
  printf '    looks: An app bar titled it.\n'
  printf '    states: {SomeBloc: {SomeReady: The screen.}}\n'
  printf '    keys: {some_view.key: The button.}\n'
}

full_map="screens:
$(entry JournalRoute feature_journal /)
$(entry EntryRoute feature_journal /entries/:id)
$(entry ShareRoute feature_journal /entries/:id/share)
$(entry SessionRoute feature_session /session)
"
readonly full_map

# Runs the check in $1 and prints its exit code, then its output.
check() {
  local status=0 output
  output="$(cd "$1" && bash scripts/feature-map.sh 2>&1)" || status=$?
  printf '%s\n%s' "${status}" "${output}"
}

test_passes_when_the_map_lists_every_declared_route() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_journal/lib/src/routes.dart "${journal_routes}" \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "${full_map}")"

  result="$(check "${dir}")"
  [[ "${result}" == 0* ]] || fail "passes a complete map: got
${result}"
}

test_passes_from_any_directory_inside_the_repository() {
  local dir
  dir="$(repo \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "screens:
$(entry SessionRoute feature_session /session)
")"

  (cd "${dir}/apps/mobile" && bash ../../scripts/feature-map.sh >/dev/null 2>&1) ||
    fail "passes from a subdirectory: exited non-zero"
}

test_fails_on_a_declared_route_the_map_does_not_list() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_journal/lib/src/routes.dart "${journal_routes}" \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "screens:
$(entry JournalRoute feature_journal /)
$(entry EntryRoute feature_journal /entries/:id)
$(entry SessionRoute feature_session /session)
")"

  result="$(check "${dir}")"
  [[ "${result}" == 1* ]] || fail "fails a missing entry: exited ${result%%$'\n'*}"
  [[ "${result}" == *"ShareRoute (feature_journal, /entries/:id/share) is declared but the map has no entry for it: add one to ${map}"* ]] ||
    fail "names the unlisted route and its full location: got
${result}"
}

test_fails_on_an_entry_whose_route_no_longer_exists() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "screens:
$(entry SessionRoute feature_session /session)
$(entry AccountRoute feature_account /more/account)
")"

  result="$(check "${dir}")"
  [[ "${result}" == 1* ]] || fail "fails a stale entry: exited ${result%%$'\n'*}"
  [[ "${result}" == *"AccountRoute (feature_account, /more/account) has an entry but no feature declares it: remove it from ${map}"* ]] ||
    fail "names the stale entry: got
${result}"
}

test_fails_when_a_route_moved_to_another_location() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "screens:
$(entry SessionRoute feature_session /sessions)
")"

  result="$(check "${dir}")"
  [[ "${result}" == 1* ]] || fail "fails a moved route: exited ${result%%$'\n'*}"
  [[ "${result}" == *"SessionRoute (feature_session, /session) is declared"* &&
    "${result}" == *"SessionRoute (feature_session, /sessions) has an entry"* ]] ||
    fail "names both locations of a moved route: got
${result}"
}

test_reads_only_tracked_hand_written_library_code() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    apps/mobile/packages/feature/feature_session/lib/src/routes.g.dart "@TypedGoRoute<GeneratedRoute>(path: '/g')\nclass G {}\n" \
    apps/mobile/packages/feature/feature_session/test/routes_test.dart "@TypedGoRoute<TestRoute>(path: '/t')\nclass T {}\n" \
    "${map}" "screens:
$(entry SessionRoute feature_session /session)
")"
  write "${dir}/apps/mobile/packages/feature/feature_x/lib/src/routes.dart" \
    "@TypedGoRoute<ScratchRoute>(path: '/scratch')\nclass S {}\n"

  result="$(check "${dir}")"
  [[ "${result}" == 0* ]] || fail "reads only tracked library code: got
${result}"
}

test_names_the_app_as_the_package_of_a_route_it_declares() {
  local dir result
  dir="$(repo \
    apps/mobile/app/lib/app/routes.dart "@TypedGoRoute<DebugRoute>(path: '/debug')\nclass D {}\n" \
    "${map}" "screens: []\n")"

  result="$(check "${dir}")"
  [[ "${result}" == *"DebugRoute (app, /debug) is declared"* ]] ||
    fail "names the app as the package: got
${result}"
}

test_fails_on_an_entry_missing_a_field() {
  local dir result
  dir="$(repo \
    apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}" \
    "${map}" "screens:
  - route: SessionRoute
    package: feature_session
    path: /session
    reach: [Tap journal_view.start.]
    does: Runs a session.
    states: {SessionBloc: {SessionLoading: Thinking.}}
    keys: {}
")"

  result="$(check "${dir}")"
  [[ "${result}" == 1* ]] || fail "fails an incomplete entry: exited ${result%%$'\n'*}"
  [[ "${result}" == *'SessionRoute: the entry has no "looks"'* ]] ||
    fail "names the entry and the missing field: got
${result}"
  [[ "${result}" != *'"keys"'* ]] || fail "takes an empty keys map as given: got
${result}"
}

test_fails_without_a_map() {
  local dir result
  dir="$(repo apps/mobile/packages/feature/feature_session/lib/src/routes.dart "${session_routes}")"

  result="$(check "${dir}")"
  [[ "${result}" == 1* && "${result}" == *"no feature map at ${map}"* ]] ||
    fail "fails without a map: got
${result}"
}

test_passes_when_the_map_lists_every_declared_route
test_passes_from_any_directory_inside_the_repository
test_fails_on_a_declared_route_the_map_does_not_list
test_fails_on_an_entry_whose_route_no_longer_exists
test_fails_when_a_route_moved_to_another_location
test_reads_only_tracked_hand_written_library_code
test_names_the_app_as_the_package_of_a_route_it_declares
test_fails_on_an_entry_missing_a_field
test_fails_without_a_map

if ((failures > 0)); then
  printf '%d test(s) failed\n' "${failures}" >&2
  exit 1
fi
printf 'feature-map.sh: all tests passed\n'
