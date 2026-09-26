#!/usr/bin/env bash
# Tests for ast-grep.sh, through its command line only: a throwaway git
# repository with this repository's rules in, findings and the exit code out.
# What each rule matches is tested by `ast-grep test` (ast-grep/tests); this
# covers what the rules alone cannot: which files are read (a rule test case
# has no path, so `files` and `ignores` are only tested here), the messages,
# and the output CI turns into annotations. ast-grep must be on PATH:
#   pnpm exec bash scripts/ast-grep.test.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A fresh git repository with the rules and the script, all untracked, and
# the files named in the arguments, each followed by its content, tracked.
repo() {
  local dir="${work}/repo-${RANDOM}"
  mkdir -p "${dir}/scripts"
  git -C "${dir}" init --quiet
  cp "${root}/sgconfig.yml" "${dir}/"
  cp -R "${root}/ast-grep" "${dir}/"
  cp "${root}/scripts/ast-grep.sh" "${dir}/scripts/"
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

# The findings as sorted `path:line: message` lines, lines counted from 1.
findings() {
  (cd "$1" && { bash scripts/ast-grep.sh --json=stream 2>/dev/null || true; }) |
    jq -r '"\(.file):\(.range.start.line + 1): \(.message)"' | sort
}

test_reports_every_tracked_hand_written_source_with_its_path() {
  local dir
  dir="$(repo \
    apps/mobile/lib/a.dart '// XXX: handle later\n' \
    apps/agent/src/b.ts '// ok\n// @ts-expect-error\nf();\n' \
    apps/agent/src/c.mjs 'f(); // HACK\n' \
    scripts/d.sh '#!/bin/sh\n# FIXME\n' \
    lib/e.dart 'void f() {}\n// Use the cached value for now.\n')"

  local expected
  expected="$(printf '%s\n' \
    'apps/agent/src/b.ts:2: unexplained suppression "@ts-expect-error": give its reason in 4 or more words on the same line or on the comment line above' \
    'apps/agent/src/c.mjs:1: workaround comment "HACK": record deferred work in an issue, not a comment' \
    'apps/mobile/lib/a.dart:1: workaround comment "XXX": record deferred work in an issue, not a comment' \
    'lib/e.dart:2: workaround comment "for now": record deferred work in an issue, not a comment' \
    'scripts/d.sh:2: workaround comment "FIXME": record deferred work in an issue, not a comment')"
  local actual
  actual="$(findings "${dir}")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "reports every tracked source: got
${actual}"
}

test_exempts_generated_files_and_anything_git_does_not_track() {
  local dir
  dir="$(repo \
    lib/a.g.dart '// coverage:ignore-file\n// XXX\n' \
    lib/a.freezed.dart '// coverage:ignore-file\n' \
    lib/main.server.options.dart '// XXX\n' \
    lib/mocks.mocks.dart '// Use it for now.\n' \
    lib/clean.dart '// Nothing to see here.\n' \
    README.md '<!-- XXX -->\n// XXX\n')"
  write "${dir}/lib/scratch.dart" '// XXX\n'
  write "${dir}/node_modules/x/y.ts" '// TODO\n'

  local actual
  actual="$(findings "${dir}")"
  [[ -z "${actual}" ]] || fail "exempts generated and untracked files: got
${actual}"
}

# no-from-environment: a define is read only in the environment file of the
# app it belongs to; anywhere else, feature and utility packages first, the
# message names that file.
test_reads_defines_only_in_each_apps_environment_file() {
  local dir
  dir="$(repo \
    apps/mobile/app/lib/app/environment.dart "const a = String.fromEnvironment('A');\n" \
    apps/mobile/app/integration_test/environment.dart "const p = String.fromEnvironment('P');\n" \
    apps/web/lib/environment.dart "const k = String.fromEnvironment('K');\n" \
    apps/mobile/packages/feature/feature_x/lib/src/x.dart "const a = String.fromEnvironment('A');\n" \
    apps/mobile/packages/utility/utility_y/lib/y.dart "\nconst b = bool.fromEnvironment('B');\n" \
    apps/mobile/app/lib/app/dependencies.dart "const c = int.fromEnvironment('C');\n" \
    apps/mobile/app/integration_test/live_test.dart "const p = String.fromEnvironment('P');\n" \
    apps/web/lib/main.dart "const d = String.fromEnvironment('D');\n")"

  local app="reads a --dart-define outside the app: read it in apps/mobile/app/lib/app/environment.dart and pass the value into the package's registration function (ADR 0015)"
  local site="reads a define outside the site's environment file: read it in apps/web/lib/environment.dart and import the value from there"
  local expected
  expected="$(printf '%s\n' \
    "apps/mobile/app/integration_test/live_test.dart:1: \"String.fromEnvironment\" ${app}" \
    "apps/mobile/app/lib/app/dependencies.dart:1: \"int.fromEnvironment\" ${app}" \
    "apps/mobile/packages/feature/feature_x/lib/src/x.dart:1: \"String.fromEnvironment\" ${app}" \
    "apps/mobile/packages/utility/utility_y/lib/y.dart:2: \"bool.fromEnvironment\" ${app}" \
    "apps/web/lib/main.dart:1: \"String.fromEnvironment\" ${site}")"
  local actual
  actual="$(findings "${dir}")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "reads defines only in each app's environment file: got
${actual}"
}

test_fails_with_the_file_the_line_and_the_reason() {
  local dir output
  dir="$(repo lib/a.ts 'f();\n// TODO: handle later\n')"

  if output="$(cd "${dir}" && bash scripts/ast-grep.sh --report-style short 2>&1)"; then
    fail "fails a workaround comment: exited 0"
  fi
  [[ "${output}" == *'lib/a.ts:2:1: error[workaround-tag-typescript]: workaround comment "TODO"'* ]] ||
    fail "names the file, the line and the reason: got
${output}"
}

test_fails_a_define_read_in_a_feature_package() {
  local dir output
  dir="$(repo apps/mobile/packages/feature/feature_x/lib/x.dart "const a = String.fromEnvironment('A');\n")"

  if output="$(cd "${dir}" && bash scripts/ast-grep.sh --report-style short 2>&1)"; then
    fail "fails a define read in a feature package: exited 0"
  fi
  [[ "${output}" == *'feature_x/lib/x.dart:1:11: error[no-from-environment]: "String.fromEnvironment" reads a --dart-define'* ]] ||
    fail "names the rule and the read: got
${output}"
}

# ast-grep's own suppression silences any rule here, so it must name the
# rules it silences and give its reason like every other suppression. A bare
# one on a code line would otherwise silence the finding on itself.
test_wants_rule_ids_and_a_reason_on_ast_grep_ignore() {
  local dir
  dir="$(repo \
    apps/mobile/packages/feature/feature_x/lib/x.dart "void f() {}\n// ast-grep-ignore: no-from-environment\nconst a = String.fromEnvironment('A');\nconst b = String.fromEnvironment('B'); // ast-grep-ignore\n" \
    apps/mobile/packages/utility/utility_y/lib/y.dart "void f() {}\n// ast-grep-ignore: no-from-environment -- the harness replays a recorded define\nconst a = String.fromEnvironment('A');\n")"

  local expected
  expected="$(printf '%s\n' \
    'apps/mobile/packages/feature/feature_x/lib/x.dart:2: unexplained suppression "ast-grep-ignore: no-from-environment": give its reason in 4 or more words on the same line or on the comment line above' \
    'apps/mobile/packages/feature/feature_x/lib/x.dart:4: ast-grep-ignore must specify rule IDs.')"
  local actual
  actual="$(findings "${dir}")"
  [[ "${actual}" == "${expected}" ]] ||
    fail "wants rule ids and a reason on ast-grep-ignore: got
${actual}"
}

# `ast-grep test` passes a test whose rule is gone, printing only
# "Configuration not found"; `ast-grep.sh test` fails it.
test_rule_tests_pass_with_every_rule_in_place() {
  local dir
  dir="$(repo)"

  (cd "${dir}" && bash scripts/ast-grep.sh test >/dev/null 2>&1) ||
    fail "passes the rule tests of an unchanged rule set: exited non-zero"
}

test_rule_tests_fail_on_a_test_whose_rule_was_renamed() {
  local dir output
  dir="$(repo)"
  sed -i.orig 's/^id: no-from-environment$/id: no-define-reads/' \
    "${dir}/ast-grep/rules/architecture/no-from-environment.yml"

  if output="$(cd "${dir}" && bash scripts/ast-grep.sh test 2>&1)"; then
    fail "fails a test whose rule was renamed: exited 0"
  fi
  [[ "${output}" == *'no rule with the id "no-from-environment"'* ]] ||
    fail "names the orphaned test's rule id: got
${output}"
}

test_writes_github_annotations_when_asked() {
  local dir output
  dir="$(repo scripts/a.sh '# TODO\n')"

  output="$(cd "${dir}" && { bash scripts/ast-grep.sh --format github 2>/dev/null || true; })"
  [[ "${output}" == *'::error file=scripts/a.sh,line=1,endLine=1,title=workaround-tag-bash::workaround comment "TODO"'* ]] ||
    fail "writes a GitHub annotation: got
${output}"
}

test_passes_a_clean_tree_from_any_directory_inside_it() {
  local dir
  dir="$(repo lib/a.dart '// Nothing deferred.\n')"

  (cd "${dir}/lib" && bash ../scripts/ast-grep.sh >/dev/null 2>&1) ||
    fail "passes a clean tree from a subdirectory: exited non-zero"
}

test_reports_every_tracked_hand_written_source_with_its_path
test_exempts_generated_files_and_anything_git_does_not_track
test_reads_defines_only_in_each_apps_environment_file
test_fails_with_the_file_the_line_and_the_reason
test_fails_a_define_read_in_a_feature_package
test_wants_rule_ids_and_a_reason_on_ast_grep_ignore
test_rule_tests_pass_with_every_rule_in_place
test_rule_tests_fail_on_a_test_whose_rule_was_renamed
test_writes_github_annotations_when_asked
test_passes_a_clean_tree_from_any_directory_inside_it

if ((failures > 0)); then
  printf '%d test(s) failed\n' "${failures}" >&2
  exit 1
fi
printf 'ast-grep.sh: all tests passed\n'
