#!/usr/bin/env bash
# Keeps the feature map honest (issue 168): every typed route a package of
# the Flutter workspace declares has an entry in the run-app skill's feature
# map, at the same location, and every entry names a route that still
# exists and says everything an agent needs to reach and recognise it.
#
# The routes come from the ast-grep rule `typed-go-route` (ADR 0018; it is
# off in scripts/ast-grep.sh's scan and switched on here), read over the tracked,
# hand-written library code of apps/mobile; jq joins a nested route's path to
# its parents'. The map is YAML, read with yq. Both sides become lines of
# `Route (package, /location)`, and any line on one side only fails the check.
# ast-grep comes from the root package, so run it through pnpm, from anywhere
# inside the repository:
#   pnpm exec bash scripts/feature-map.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

readonly map=.claude/skills/run-app/references/feature-map.yaml
# What an agent needs from an entry; `keys` and `states` may be empty maps.
readonly fields='["package", "route", "path", "reach", "does", "looks", "states", "keys"]'

die() {
  printf 'feature map: %s\n' "$1" >&2
  exit 1
}

[[ -f "${map}" ]] || die "no feature map at ${map}"

# Every typed route in tracked library code, as `Route (package, /location)`.
declared_routes() {
  local files=() file
  while IFS= read -r -d '' file; do
    case "${file}" in
      # Generated code answers to its generator.
      *.g.dart | *.freezed.dart | *.mocks.dart) ;;
      *) files+=("${file}") ;;
    esac
  done < <(git ls-files -z -- ':(glob)apps/mobile/**/lib/**/*.dart')
  ((${#files[@]} > 0)) || return 0
  ast-grep scan --filter '^typed-go-route$' --info=typed-go-route --json=compact \
    "${files[@]}" |
    jq -r '
      # A Dart string literal, raw or not, in either quotes.
      def unquoted: ltrimstr("r") | .[1:-1];
      # A path that starts with a slash is absolute; any other is under its
      # parent, as go_router joins them.
      def under($parent): if startswith("/") or $parent == "" then .
        else ($parent | rtrimstr("/")) + "/" + . end;
      def span: .range.byteOffset;
      group_by(.file)[] | . as $file | .[] | . as $route |
      # The paths of the routes around it, outermost first, then its own.
      ([$file[] | select(span.start <= ($route | span.start)
          and span.end >= ($route | span.end))]
        | sort_by(span.start)
        | reduce (.[].metaVariables.single.PATH.text | unquoted) as $segment
            (""; . as $parent | $segment | under($parent))) as $location |
      (.file | capture("^apps/mobile/(?:packages/[^/]+/)?(?<name>[^/]+)/").name) as $package |
      "\(.metaVariables.single.ROUTE.text) (\($package), \($location))"'
}

map_json="$(yq -o=json '.' "${map}")"

listed_routes() {
  jq -r '(.screens // [])[] | "\(.route) (\(.package), \(.path))"' <<<"${map_json}"
}

# An entry without one of the fields, or with it empty.
incomplete_entries() {
  jq -r --argjson fields "${fields}" '
    (.screens // [])[] as $entry | $fields[] |
    select(($entry[.] // "") == "" or $entry[.] == []) |
    "\($entry.route // "an entry"): the entry has no \"\(.)\""' <<<"${map_json}"
}

declared="$(declared_routes | LC_ALL=C sort)"
listed="$(listed_routes | LC_ALL=C sort)"

problems=0
while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  printf 'feature map: %s is declared but the map has no entry for it: add one to %s\n' "${line}" "${map}" >&2
  problems=$((problems + 1))
done < <(LC_ALL=C comm -23 <(printf '%s\n' "${declared}") <(printf '%s\n' "${listed}"))
while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  printf 'feature map: %s has an entry but no feature declares it: remove it from %s\n' "${line}" "${map}" >&2
  problems=$((problems + 1))
done < <(LC_ALL=C comm -13 <(printf '%s\n' "${declared}") <(printf '%s\n' "${listed}"))
while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  printf 'feature map: %s in %s\n' "${line}" "${map}" >&2
  problems=$((problems + 1))
done < <(incomplete_entries)

((problems == 0)) || exit 1
printf 'feature map: %d route(s), every one listed\n' "$(grep -c . <<<"${declared}" || true)"
