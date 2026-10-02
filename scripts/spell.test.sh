#!/usr/bin/env bash
# Tests for `pnpm spell:us-english` (cspell.us-english.yaml), through the
# command package.json runs: a throwaway directory with the config and a few
# files in, findings and the exit code out. It pins what a config change
# could break silently: dropping `--no-config-search` lets
# cspell.config.yaml's ARB-only pattern hide every finding, and the check
# then passes on anything. cspell must be on PATH:
#   pnpm exec bash scripts/spell.test.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
command="$(jq -r '.scripts["spell:us-english"]' "${root}/package.json")"

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A fresh directory with both configs (the copy check's too, so that a run
# which reads it shows up) and the files named in the arguments, each
# followed by its content.
tree() {
  local dir="${work}/tree-${RANDOM}"
  mkdir -p "${dir}"
  cp "${root}/cspell.config.yaml" "${root}/cspell.us-english.yaml" "${dir}/"
  mkdir -p "${dir}/cspell"
  cp "${root}"/cspell/*.txt "${dir}/cspell/"
  while (($# > 0)); do
    mkdir -p "$(dirname "${dir}/$1")"
    printf '%b' "$2" >"${dir}/$1"
    shift 2
  done
  printf '%s' "${dir}"
}

# The findings as sorted `path:line word` lines.
findings() {
  (cd "$1" && { bash -c "${command}" 2>/dev/null || true; }) |
    sed -nE 's/^([^:]+):([0-9]+):[0-9]+ - Forbidden word \(([^)]*)\).*/\1:\2 \3/p' |
    sort
}

test_flags_british_spellings_in_everything_we_write() {
  local dir actual expected
  dir="$(tree \
    lib/a.dart '// The colour of the button.\nString normaliseCode() => "";\n' \
    src/b.ts 'const label = "Personalised greeting";\n' \
    docs/c.md 'The behaviour we want.\n' \
    scripts/d.sh '# Finalises the recording.\n' \
    .github/workflows/e.yml '# A cancelled run.\n' \
    .claude/skills/f/SKILL.md 'Use your judgement.\n' \
    apps/mobile/x/l10n/x_en.arb '{"@k": {"description": "In the error colour."}}\n')"
  actual="$(findings "${dir}")"
  expected="$(printf '%s\n' \
    '.claude/skills/f/SKILL.md:1 judgement' \
    '.github/workflows/e.yml:1 cancelled' \
    'apps/mobile/x/l10n/x_en.arb:1 colour' \
    'docs/c.md:1 behaviour' \
    'lib/a.dart:1 colour' \
    'lib/a.dart:2 normalise' \
    'scripts/d.sh:1 Finalises' \
    'src/b.ts:1 Personalised')"
  [[ "${actual}" == "${expected}" ]] ||
    fail "british spellings: expected
${expected}
got
${actual}"
}

test_passes_us_english_unknown_words_and_api_spellings() {
  local dir actual
  dir="$(tree \
    lib/a.dart '// The color of Colors.grey, two analyses, Supabase and Jaspr.\n' \
    .github/workflows/b.yml "if: \${{ !cancelled() }}\nrun: contains(needs.*.result, 'cancelled')\n" \
    docs/c.md 'Advertise, compromise, exercise, a dialogue.\n')"
  actual="$(findings "${dir}")"
  [[ -z "${actual}" ]] || fail "US English: expected nothing, got
${actual}"
}

test_skips_generated_files_german_copy_and_symlinked_agents_files() {
  local dir actual
  dir="$(tree \
    lib/a.g.dart '// colour\n' \
    lib/a.freezed.dart '// colour\n' \
    lib/src/l10n/x_localizations_en.dart '// colour\n' \
    apps/web/lib/main.server.options.dart '// colour\n' \
    apps/mobile/x/l10n/x_de.arb '{"k": "Programme"}\n' \
    docs/CLAUDE.md 'colour\n')"
  actual="$(findings "${dir}")"
  [[ -z "${actual}" ]] || fail "skipped files: expected nothing, got
${actual}"
}

test_exits_non_zero_on_a_finding() {
  local dir
  dir="$(tree docs/a.md 'colour\n')"
  if (cd "${dir}" && bash -c "${command}" >/dev/null 2>&1); then
    fail 'a finding must fail the run'
  fi
}

test_flags_british_spellings_in_everything_we_write
test_passes_us_english_unknown_words_and_api_spellings
test_skips_generated_files_german_copy_and_symlinked_agents_files
test_exits_non_zero_on_a_finding

if ((failures > 0)); then
  printf '%d failed\n' "${failures}" >&2
  exit 1
fi
printf 'spell.test.sh: all passed\n'
