#!/usr/bin/env bash
# Fails if this branch adds a migration whose timestamp is not newer than
# the newest migration on the base ref. `supabase db push` refuses to apply
# a migration older than the remote's newest one, so such a migration would
# merge green and then break supabase-deploy on main (see #296).
# Usage: scripts/migration-order.sh <base-ref>   (e.g. origin/main)
set -euo pipefail
base=${1:?usage: migration-order.sh <base-ref>}
dir=supabase/migrations
mb=$(git merge-base "$base" HEAD)
latest=$(git ls-tree --name-only "$base" -- "$dir/" | xargs -rn1 basename \
  | grep -E '^[0-9]{14}_.*\.sql$' | sort | tail -n1 | cut -c1-14)
[ -n "$latest" ] || { echo "No migrations on $base."; exit 0; }
status=0
while IFS= read -r file; do
  name=$(basename "$file")
  ts=${name:0:14}
  if ! [[ $ts =~ ^[0-9]{14}$ ]]; then
    echo "::error file=$file::Migration name must start with a 14-digit UTC timestamp (YYYYMMDDHHMMSS)."
    status=1
  elif [[ ! $ts > $latest ]]; then
    echo "::error file=$file::Migration timestamp $ts is not newer than $latest, the newest on $base. Rename it to the current UTC time (date -u +%Y%m%d%H%M%S)."
    status=1
  fi
done < <(git diff --name-only --diff-filter=AR "$mb" HEAD -- "$dir/" | grep -E '\.sql$' || true)
[ "$status" = 0 ] && echo "Added migrations are newer than $latest."
exit "$status"
