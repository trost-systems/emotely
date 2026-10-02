#!/usr/bin/env bash
# The ast-grep gate (ADR 0018), from anywhere inside the repository. ast-grep
# comes from the root package, so run it through pnpm.
#
#   pnpm exec bash scripts/ast-grep.sh test
#     The rule tests (`ast-grep test`), failing on a test whose rule id no
#     rule has: ast-grep itself only prints "Configuration not found" and
#     passes, so a renamed or deleted rule would silently lose its tests.
#     Rules with `severity: off` are tested too (`--include-off`): they
#     extract rather than lint (scripts/feature-map.sh switches one on by
#     id), and without it ast-grep skips their tests with that same message.
#
#   pnpm exec bash scripts/ast-grep.sh [scan arguments]
#     Every rule in ast-grep/rules — the comment tripwire, the architecture
#     rules — over every file git tracks, so build output, dependencies and
#     scratch files are never read. ast-grep keeps the files it has a rule
#     language for (Dart, TypeScript and JavaScript, shell); each rule's own
#     `files` and `ignores` narrow that further. A bare `ast-grep-ignore`
#     fails (`no-suppress-all`): a suppression names the rules it silences,
#     and the tripwire wants its reason. Arguments go to `ast-grep scan`,
#     e.g. `--format github` in CI.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ "${1:-}" == test ]]; then
  shift
  status=0
  output="$(ast-grep test --include-off --color never "$@" 2>&1)" || status=$?
  printf '%s\n' "${output}"
  orphans="$(sed -n 's/^Configuration not found! //p' <<<"${output}")"
  if [[ -n "${orphans}" ]]; then
    while IFS= read -r id; do
      printf 'error: a test in ast-grep/tests names "%s", but there is no rule with the id "%s": rename or remove the test with its rule\n' \
        "${id}" "${id}" >&2
    done <<<"${orphans}"
    exit 1
  fi
  exit "${status}"
fi

git ls-files -z | xargs -0 ast-grep scan --error=no-suppress-all "$@"
