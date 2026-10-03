#!/usr/bin/env bash
# Checks the store listings in fastlane's metadata folder before a `metadata`
# lane uploads them: each field within its store's limit, every locale with
# every field English has, and no Play file ending in a newline. Either
# console refuses an over-long field only when the upload runs, which is a
# human-approved write; this fails the pull request instead.
#
#   bash scripts/store-listing-check.sh [metadata-dir]
#
# Layout (fastlane's): App Store <locale>/<field>.txt, which deliver strips
# before upload; Play android/<locale>/<field>.txt, which supply uploads as
# it is. Limits, from the stores' own help pages (checked 2026-09-29):
# App Store name and subtitle 30 characters, keywords 100 bytes, promotional
# text 170, description and release notes 4000
# (developer.apple.com/help/app-store-connect/reference/app-information/);
# Play title 30, short description 80, full description 4000
# (support.google.com/googleplay/android-developer/answer/9859152), release
# notes 500.
set -euo pipefail
# Characters, not bytes, for ${#…}, on Linux and macOS alike.
export LC_ALL=C.UTF-8

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/apps/mobile/app/fastlane/metadata}"

failed=0
error() {
  printf '%s: %s\n' "$1" "$2" >&2
  failed=1
}

# "<unit> <limit>" for an App Store field, empty for one without a limit
# (URLs, categories).
app_store_limit() {
  case "$1" in
    name.txt | subtitle.txt) printf 'characters 30' ;;
    keywords.txt) printf 'bytes 100' ;;
    promotional_text.txt) printf 'characters 170' ;;
    description.txt | release_notes.txt) printf 'characters 4000' ;;
    *) ;;
  esac
}

play_limit() {
  case "$1" in
    title.txt) printf '30' ;;
    short_description.txt) printf '80' ;;
    full_description.txt) printf '4000' ;;
    *) ;;
  esac
}

# measure <unit> <text>: its length in characters or bytes.
measure() {
  if [[ "$1" == bytes ]]; then
    printf '%s' "$2" | wc -c | tr -d ' '
  else
    printf '%s' "${#2}"
  fi
}

# over <label> <unit> <limit> <text>
over() {
  local length
  length="$(measure "$2" "$4")"
  if ((length > $3)); then
    error "$1" "${length} $2, the store allows $3"
  fi
}

# Every locale in <store-dir> has every field en-US has.
complete() {
  local store="$1" prefix="$2" locale file
  [[ -d "${store}/en-US" ]] || return 0
  for locale in "${store}"/*-*/; do
    locale="$(basename "${locale}")"
    for file in "${store}"/en-US/*.txt; do
      [[ -e "${file}" ]] || continue
      [[ -e "${store}/${locale}/$(basename "${file}")" ]] ||
        error "${prefix}${locale}/$(basename "${file}")" "missing; en-US has it"
    done
  done
}

for file in "${root}"/*-*/*.txt; do
  [[ -e "${file}" ]] || continue
  name="$(basename "${file}")"
  label="${file#"${root}/"}"
  limit="$(app_store_limit "${name}")"
  [[ -n "${limit}" ]] || continue
  # deliver strips surrounding whitespace; $(<…) drops the final newlines.
  over "${label}" "${limit% *}" "${limit#* }" "$(<"${file}")"
done

for file in "${root}"/android/*-*/*.txt "${root}"/android/*-*/changelogs/*.txt; do
  [[ -e "${file}" ]] || continue
  name="$(basename "${file}")"
  label="${file#"${root}/"}"
  if [[ "${label}" == */changelogs/* ]]; then
    limit=500
  else
    limit="$(play_limit "${name}")"
  fi
  if [[ -s "${file}" && "$(tail -c 1 "${file}" | wc -l | tr -d ' ')" != 0 ]]; then
    error "${label}" "ends in a newline, which supply uploads as part of the text"
  fi
  [[ -n "${limit}" ]] || continue
  text="$(cat "${file}"; printf x)"
  over "${label}" characters "${limit}" "${text%x}"
done

complete "${root}" ""
complete "${root}/android" "android/"

exit "${failed}"
