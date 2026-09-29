#!/usr/bin/env bash
# Tests for l10n-check.sh, run in a throwaway package with a fake `flutter`
# on the PATH that plays gen-l10n: it writes the generated file and the
# untranslated-messages file the test asks for. Run from anywhere:
#   bash scripts/l10n-check.test.sh
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/l10n-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# The fake gen-l10n: writes FAKE_GENERATED into the generated file and
# FAKE_UNTRANSLATED into the untranslated-messages file.
mkdir -p "${work}/bin"
cat >"${work}/bin/flutter" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == gen-l10n ]] || exit 64
printf '%s\n' "${FAKE_GENERATED}" >lib/src/l10n/demo_localizations.dart
if [[ -n "${FAKE_EXTRA:-}" ]]; then
  printf 'extra\n' >lib/src/l10n/demo_localizations_fr.dart
fi
printf '%s\n' "${FAKE_UNTRANSLATED}" >build/untranslated.json
EOF
chmod +x "${work}/bin/flutter"

# A package in a git repository of its own, its generated file committed.
package() {
  local dir="${work}/pkg-${RANDOM}"
  mkdir -p "${dir}/lib/src/l10n"
  cat >"${dir}/l10n.yaml" <<'EOF'
arb-dir: l10n
output-dir: lib/src/l10n
untranslated-messages-file: build/untranslated.json
EOF
  printf 'committed\n' >"${dir}/lib/src/l10n/demo_localizations.dart"
  printf 'build/\n' >"${dir}/.gitignore"
  git -C "${dir}" init --quiet
  git -C "${dir}" add .
  git -C "${dir}" -c user.name=test -c user.email=test@example.com \
    commit --quiet -m init
  printf '%s' "${dir}"
}

# Runs the check in a fresh package; sets `status` and `output`.
check() {
  local dir
  dir="$(package)"
  set +e
  output="$(cd "${dir}" && PATH="${work}/bin:${PATH}" bash "${script}" 2>&1)"
  status=$?
  set -e
}

test_passes_when_generated_code_and_translations_are_current() {
  FAKE_GENERATED=committed FAKE_UNTRANSLATED='{}' check
  [[ ${status} -eq 0 ]] || fail "current package: exit ${status}: ${output}"
}

test_fails_when_the_committed_code_is_out_of_date() {
  FAKE_GENERATED=regenerated FAKE_UNTRANSLATED='{}' check
  [[ ${status} -ne 0 ]] || fail "stale generated code passed"
  [[ "${output}" == *"flutter gen-l10n"* ]] ||
    fail "stale generated code: no hint to regenerate: ${output}"
}

test_fails_when_a_generated_file_is_not_committed() {
  FAKE_GENERATED=committed FAKE_UNTRANSLATED='{}' FAKE_EXTRA=1 check
  [[ ${status} -ne 0 ]] || fail "an uncommitted generated file passed"
  [[ "${output}" == *"demo_localizations_fr.dart"* ]] ||
    fail "uncommitted file not named: ${output}"
}

test_fails_and_names_an_untranslated_message() {
  FAKE_GENERATED=committed FAKE_UNTRANSLATED='{"de": ["moreTab"]}' check
  [[ ${status} -ne 0 ]] || fail "an untranslated message passed"
  [[ "${output}" == *"de: moreTab"* ]] ||
    fail "untranslated message not named: ${output}"
}

test_ignores_work_in_progress_outside_the_generated_code() {
  local dir
  dir="$(package)"
  printf 'edited\n' >"${dir}/l10n.yaml.notes"
  printf '# edited\n' >>"${dir}/.gitignore"
  set +e
  output="$(cd "${dir}" && FAKE_GENERATED=committed FAKE_UNTRANSLATED='{}' \
    PATH="${work}/bin:${PATH}" bash "${script}" 2>&1)"
  status=$?
  set -e
  [[ ${status} -eq 0 ]] ||
    fail "unrelated uncommitted edits failed the check: ${output}"
}

test_passes_when_generated_code_and_translations_are_current
test_ignores_work_in_progress_outside_the_generated_code
test_fails_when_the_committed_code_is_out_of_date
test_fails_when_a_generated_file_is_not_committed
test_fails_and_names_an_untranslated_message

if [[ ${failures} -gt 0 ]]; then
  printf '%d failed\n' "${failures}" >&2
  exit 1
fi
printf 'l10n-check: all tests passed\n'
