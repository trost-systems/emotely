#!/usr/bin/env bash
# Checks one package's localizations (ADR 0020), from the package directory:
# regenerates them with `flutter gen-l10n`, then fails when the committed
# generated code differs from what the ARB files produce, when a generated
# file is not committed, or when a locale lacks a message the English
# template has. `melos run l10n:check` runs it in every package in scope
# that has an l10n.yaml.
set -euo pipefail

# melos applies `--file-exists=l10n.yaml` before `--include-dependents`, so
# a scoped run (`EMOTELY_SCOPE`) also reaches dependents that show no text.
# They have nothing to check.
if [[ ! -f l10n.yaml ]]; then
  printf 'no l10n.yaml here: nothing to check\n'
  exit 0
fi

untranslated="$(yq '.["untranslated-messages-file"] // ""' l10n.yaml)"
if [[ -z "${untranslated}" ]]; then
  printf 'l10n.yaml sets no untranslated-messages-file; copy it from another package.\n' >&2
  exit 1
fi
mkdir -p "$(dirname "${untranslated}")"
# Only the generated code is compared, so work in progress elsewhere in the
# package never fails the check. gen-l10n writes next to the ARB files unless
# told otherwise.
generated="$(yq '.["output-dir"] // .["arb-dir"] // "lib/l10n"' l10n.yaml)"

flutter gen-l10n >/dev/null

failed=0

if ! git diff --quiet -- "${generated}"; then
  printf 'Generated localizations are out of date. Run flutter gen-l10n here and commit:\n' >&2
  git diff --stat -- "${generated}" >&2
  failed=1
fi

new_files="$(git ls-files --others --exclude-standard -- "${generated}")"
if [[ -n "${new_files}" ]]; then
  printf 'Generated localizations not committed:\n%s\n' "${new_files}" >&2
  failed=1
fi

missing="$(jq -r 'to_entries[] | "\(.key): \(.value | join(", "))"' "${untranslated}")"
if [[ -n "${missing}" ]]; then
  printf 'Messages missing a translation (add them to that locale'"'"'s ARB file):\n%s\n' "${missing}" >&2
  failed=1
fi

exit "${failed}"
