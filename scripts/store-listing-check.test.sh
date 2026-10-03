#!/usr/bin/env bash
# Tests for store-listing-check.sh, run against throwaway metadata folders in
# fastlane's layout (deliver: <locale>/*.txt, supply: android/<locale>/*.txt).
# Run from anywhere:
#   bash scripts/store-listing-check.test.sh
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/store-listing-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A listing that passes: both stores, English and German, each field within
# its limit. App Store files end in a newline (deliver strips it), Play files
# do not (supply uploads them as they are).
listing() {
  local dir="${work}/metadata-${RANDOM}${RANDOM}"
  local locale
  for locale in en-US de-DE; do
    mkdir -p "${dir}/${locale}" "${dir}/android/${locale}"
    printf 'emotely: AI Journal\n' >"${dir}/${locale}/name.txt"
    printf 'Journal\n' >"${dir}/${locale}/subtitle.txt"
    printf 'journal,diary\n' >"${dir}/${locale}/keywords.txt"
    printf 'A journal.\n' >"${dir}/${locale}/description.txt"
    printf 'emotely' >"${dir}/android/${locale}/title.txt"
    printf 'A journal' >"${dir}/android/${locale}/short_description.txt"
    printf 'A journal.' >"${dir}/android/${locale}/full_description.txt"
  done
  printf '%s' "${dir}"
}

# Runs the check on a folder; sets `status` and `output`.
check() {
  set +e
  output="$(bash "${script}" "$1" 2>&1)"
  status=$?
  set -e
}

# n copies of a character.
repeat() {
  local out=""
  local i
  for ((i = 0; i < $2; i++)); do out+="$1"; done
  printf '%s' "${out}"
}

expect_failure() {
  local what="$1" needle="$2"
  [[ ${status} -ne 0 ]] || fail "${what} passed"
  [[ "${output}" == *"${needle}"* ]] || fail "${what}: '${needle}' not named: ${output}"
}

test_passes_on_a_listing_within_its_limits() {
  local dir
  dir="$(listing)"
  check "${dir}"
  [[ ${status} -eq 0 ]] || fail "valid listing: exit ${status}: ${output}"
}

test_passes_at_exactly_the_limit_counting_characters_not_bytes() {
  local dir
  dir="$(listing)"
  # 30 characters, 60 bytes: a limit in characters must let it through.
  printf '%s\n' "$(repeat 'ä' 30)" >"${dir}/de-DE/subtitle.txt"
  printf '%s' "$(repeat 'ü' 80)" >"${dir}/android/de-DE/short_description.txt"
  check "${dir}"
  [[ ${status} -eq 0 ]] || fail "limit-length umlaut text: exit ${status}: ${output}"
}

test_fails_on_an_app_store_subtitle_over_30_characters() {
  local dir
  dir="$(listing)"
  printf '%s\n' "$(repeat a 31)" >"${dir}/de-DE/subtitle.txt"
  check "${dir}"
  expect_failure "a 31-character subtitle" "de-DE/subtitle.txt"
}

test_fails_on_an_app_store_name_over_30_characters() {
  local dir
  dir="$(listing)"
  printf '%s\n' "$(repeat a 31)" >"${dir}/en-US/name.txt"
  check "${dir}"
  expect_failure "a 31-character name" "en-US/name.txt"
}

test_counts_app_store_keywords_in_bytes() {
  local dir
  dir="$(listing)"
  # 51 characters, 101 bytes: over Apple's 100-byte keyword limit.
  printf '%s\n' "a$(repeat 'ö' 50)" >"${dir}/de-DE/keywords.txt"
  check "${dir}"
  expect_failure "101 bytes of keywords" "de-DE/keywords.txt"
}

test_fails_on_a_play_short_description_over_80_characters() {
  local dir
  dir="$(listing)"
  printf '%s' "$(repeat a 81)" >"${dir}/android/en-US/short_description.txt"
  check "${dir}"
  expect_failure "an 81-character short description" "android/en-US/short_description.txt"
}

test_fails_on_a_play_title_over_30_characters() {
  local dir
  dir="$(listing)"
  printf '%s' "$(repeat a 31)" >"${dir}/android/de-DE/title.txt"
  check "${dir}"
  expect_failure "a 31-character Play title" "android/de-DE/title.txt"
}

test_fails_on_a_play_file_ending_in_a_newline() {
  local dir
  dir="$(listing)"
  printf 'emotely\n' >"${dir}/android/de-DE/title.txt"
  check "${dir}"
  expect_failure "a Play title with a trailing newline" "android/de-DE/title.txt"
}

test_fails_when_a_locale_lacks_a_field_english_has() {
  local dir
  dir="$(listing)"
  rm "${dir}/de-DE/keywords.txt" "${dir}/android/de-DE/short_description.txt"
  check "${dir}"
  expect_failure "German without keywords" "de-DE/keywords.txt"
  expect_failure "German without a short description" "android/de-DE/short_description.txt"
}

# Release notes (supply's changelogs/<version code>.txt or default.txt, the
# beta notes of the alpha track): Play allows 500 characters per language.
test_passes_on_play_release_notes_of_exactly_500_characters() {
  local dir
  dir="$(listing)"
  mkdir -p "${dir}/android/de-DE/changelogs"
  printf '%s' "$(repeat 'ü' 500)" >"${dir}/android/de-DE/changelogs/default.txt"
  check "${dir}"
  [[ ${status} -eq 0 ]] || fail "500-character release notes: exit ${status}: ${output}"
}

test_fails_on_play_release_notes_over_500_characters() {
  local dir
  dir="$(listing)"
  mkdir -p "${dir}/android/en-US/changelogs"
  printf '%s' "$(repeat a 501)" >"${dir}/android/en-US/changelogs/default.txt"
  check "${dir}"
  expect_failure "501-character release notes" "android/en-US/changelogs/default.txt"
}

test_fails_on_play_release_notes_ending_in_a_newline() {
  local dir
  dir="$(listing)"
  mkdir -p "${dir}/android/en-US/changelogs"
  printf 'New beta.\n' >"${dir}/android/en-US/changelogs/default.txt"
  check "${dir}"
  expect_failure "release notes with a trailing newline" "android/en-US/changelogs/default.txt"
}

test_passes_on_a_listing_within_its_limits
test_passes_at_exactly_the_limit_counting_characters_not_bytes
test_fails_on_an_app_store_subtitle_over_30_characters
test_fails_on_an_app_store_name_over_30_characters
test_counts_app_store_keywords_in_bytes
test_fails_on_a_play_short_description_over_80_characters
test_fails_on_a_play_title_over_30_characters
test_fails_on_a_play_file_ending_in_a_newline
test_fails_when_a_locale_lacks_a_field_english_has
test_passes_on_play_release_notes_of_exactly_500_characters
test_fails_on_play_release_notes_over_500_characters
test_fails_on_play_release_notes_ending_in_a_newline

if [[ ${failures} -gt 0 ]]; then
  printf '%d failed\n' "${failures}" >&2
  exit 1
fi
printf 'store-listing-check: all tests passed\n'
