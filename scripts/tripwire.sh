#!/usr/bin/env bash
# The comment tripwire (ADR 0018): the ast-grep rules in ast-grep/rules over
# every file git tracks, so build output, dependencies and scratch files are
# never read. ast-grep keeps the files it has a rule language for (Dart,
# TypeScript and JavaScript, shell); the Dart rules skip generated code.
# Arguments go to `ast-grep scan`, e.g. `--format github` in CI. ast-grep
# comes from the root package, so run it through pnpm, from anywhere inside
# the repository:
#   pnpm exec bash scripts/tripwire.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
git ls-files -z | xargs -0 ast-grep scan "$@"
