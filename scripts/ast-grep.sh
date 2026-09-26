#!/usr/bin/env bash
# The ast-grep gate (ADR 0018): every rule in ast-grep/rules — the comment
# tripwire, the architecture rules — over every file git tracks, so build
# output, dependencies and scratch files are never read. ast-grep keeps the
# files it has a rule language for (Dart, TypeScript and JavaScript, shell);
# each rule's own `files` and `ignores` narrow that further. Arguments go to
# `ast-grep scan`, e.g. `--format github` in CI. ast-grep comes from the root
# package, so run it through pnpm, from anywhere inside the repository:
#   pnpm exec bash scripts/ast-grep.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
git ls-files -z | xargs -0 ast-grep scan "$@"
