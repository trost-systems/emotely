#!/usr/bin/env bash
# Tests for tripwire.sh, through its command line only: a throwaway git
# repository with this repository's rules in, findings and the exit code out.
# What each rule matches is tested by `ast-grep test` (ast-grep/tests); this
# covers what the rules alone cannot: which files are read, the messages, and
# the output CI turns into annotations. ast-grep must be on PATH:
#   pnpm exec bash scripts/tripwire.test.sh
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
  cp "${root}/scripts/tripwire.sh" "${dir}/scripts/"
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
  (cd "$1" && { bash scripts/tripwire.sh --json=stream 2>/dev/null || true; }) |
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

test_fails_with_the_file_the_line_and_the_reason() {
  local dir output
  dir="$(repo lib/a.ts 'f();\n// TODO: handle later\n')"

  if output="$(cd "${dir}" && bash scripts/tripwire.sh --report-style short 2>&1)"; then
    fail "fails a workaround comment: exited 0"
  fi
  [[ "${output}" == *'lib/a.ts:2:1: error[workaround-tag-typescript]: workaround comment "TODO"'* ]] ||
    fail "names the file, the line and the reason: got
${output}"
}

test_writes_github_annotations_when_asked() {
  local dir output
  dir="$(repo scripts/a.sh '# TODO\n')"

  output="$(cd "${dir}" && { bash scripts/tripwire.sh --format github 2>/dev/null || true; })"
  [[ "${output}" == *'::error file=scripts/a.sh,line=1,endLine=1,title=workaround-tag-bash::workaround comment "TODO"'* ]] ||
    fail "writes a GitHub annotation: got
${output}"
}

test_passes_a_clean_tree_from_any_directory_inside_it() {
  local dir
  dir="$(repo lib/a.dart '// Nothing deferred.\n')"

  (cd "${dir}/lib" && bash ../scripts/tripwire.sh >/dev/null 2>&1) ||
    fail "passes a clean tree from a subdirectory: exited non-zero"
}

test_reports_every_tracked_hand_written_source_with_its_path
test_exempts_generated_files_and_anything_git_does_not_track
test_fails_with_the_file_the_line_and_the_reason
test_writes_github_annotations_when_asked
test_passes_a_clean_tree_from_any_directory_inside_it

if ((failures > 0)); then
  printf '%d test(s) failed\n' "${failures}" >&2
  exit 1
fi
printf 'tripwire.sh: all tests passed\n'
