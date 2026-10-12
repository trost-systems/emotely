#!/usr/bin/env bash
# Runs this checkout's own local Supabase stack, so parallel agent sessions
# never share a database: one session's `supabase db reset` replaced every
# other session's schema when they all used the one stack config.toml names.
# `stack.sh help` for usage.
#
# The stack is named after the checkout and listens on ports the OS assigns.
# Both go into supabase/.env.development.local (ignored), which the CLI
# loads before config.toml (`SUPABASE_<KEY>` overrides any config key), so
# every plain `supabase` command in this checkout reaches this stack and no
# other. A machine-wide registry lets a later `up` delete the stacks of
# checkouts that are gone.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
# Machine-wide, shared by every checkout and every clone: one symlink per
# stack, named after it, pointing at its checkout. Not under $TMPDIR: a
# sandboxed agent session may be given a private one.
STACKS_DIR="${EMOTELY_SUPABASE_STACKS:-${XDG_STATE_HOME:-$HOME/.local/state}/emotely/supabase}"

# new_project_id <checkout>: "emotely-", the checkout's directory name and a
# random suffix, so two clones named alike get two stacks. The CLI names
# every container and volume after it and allows 40 characters of
# [a-zA-Z0-9_.-].
new_project_id() {
  local name suffix
  name="$(printf '%s' "$(basename "$1")" | tr -c 'a-zA-Z0-9_-' '-' | cut -c1-24)"
  suffix="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  printf 'emotely-%s-%s' "$name" "$suffix"
}

# free_ports <n>: n distinct ports the OS assigns, one per line. The CLI
# refuses port 0, so it is asked here: all n sockets stay bound until each
# has its port, so none comes twice. Perl because it ships with macOS and
# with every Debian and Ubuntu (perl-base), runners included.
free_ports() {
  perl -MIO::Socket::INET -e '
    my @sockets = map { IO::Socket::INET->new(Listen => 1, LocalPort => 0) or die "no free port: $!\n" } 1 .. $ARGV[0];
    print map { $_->sockport . "\n" } @sockets;
  ' "$1"
}

die() {
  printf 'stack: %s\n' "$*" >&2
  exit 1
}
log() { printf 'stack: %s\n' "$*" >&2; }

session_file() { printf '%s/supabase/.env.development.local' "$REPO"; }
session_id() { sed -n 's/^SUPABASE_PROJECT_ID=//p' "$(session_file)" 2>/dev/null || true; }

# write_session <project id> <api> <db> <shadow> <studio> <smtp>: in one
# step, so a CLI started meanwhile reads the old file or the new one.
write_session() {
  local file tmp
  file="$(session_file)"
  tmp="$file.$$.tmp"
  cat >"$tmp" <<EOF
# This checkout's own local Supabase stack, written by
# .claude/skills/supabase/scripts/stack.sh: \`stack.sh down\` removes it.
# The CLI reads this file before config.toml, so every supabase command run
# in this checkout goes to this stack.
SUPABASE_PROJECT_ID=$1
SUPABASE_API_PORT=$2
SUPABASE_DB_PORT=$3
SUPABASE_DB_SHADOW_PORT=$4
SUPABASE_STUDIO_PORT=$5
SUPABASE_LOCAL_SMTP_PORT=$6
EOF
  mv -f "$tmp" "$file"
}

# Every supabase command runs from the checkout's root, where the CLI finds
# config.toml and the session file beside it.
in_repo() { (cd "$REPO" && "$@"); }

running() { docker ps --format '{{.Names}}' | grep -q -x -F "supabase_$1_$2"; }

# register <project id>: a symlink to the checkout, so `prune` can tell a
# stack whose checkout is gone.
register() {
  mkdir -p "$STACKS_DIR"
  ln -sfn "$REPO" "$STACKS_DIR/$1"
}

# start <project id> <supabase args...>: on fresh ports each time. The OS
# may hand a port out again between asking and Docker binding it, so a
# taken port is retried with new ones; anything else fails at once.
start() {
  local id="$1" attempt log port ports status
  shift
  log="$(mktemp)"
  for attempt in 1 2 3; do
    ports=()
    while read -r port; do ports+=("$port"); done < <(free_ports 5)
    ((${#ports[@]} == 5)) || die "the OS gave no free ports"
    write_session "$id" "${ports[@]}"
    # Only now: `prune` deletes a registered stack its checkout does not name.
    register "$id"
    status=0
    in_repo supabase "$@" 2>&1 | tee "$log" >&2 || status=$?
    if ((status == 0)); then
      rm -f "$log"
      return 0
    fi
    grep -q -i -E 'port is already allocated|address already in use' "$log" || break
    log "a port was taken meanwhile; attempt $((attempt + 1)) on new ones"
  done
  rm -f "$log"
  die "supabase $* failed for stack $id (output above)"
}

cmd_up() {
  local db_only=0 id
  case "${1:-}" in
    --db-only) db_only=1 ;;
    "") ;;
    *) die "unknown option for up: $1" ;;
  esac
  id="$(session_id)"
  [[ -n "$id" ]] || id="$(new_project_id "$REPO")"
  cmd_prune
  if running db "$id"; then
    if ((db_only)) || running kong "$id"; then
      log "stack $id is already up: \`supabase status\` prints its URLs and keys"
      return 0
    fi
    # `supabase start` takes a running database for a started stack and
    # starts nothing more; stopped, the database keeps its data.
    in_repo supabase stop >&2
  fi
  if ((db_only)); then
    start "$id" db start
  else
    start "$id" start
  fi
  log "stack $id is up; every supabase command in $REPO now uses it"
}

cmd_down() {
  local id
  id="$(session_id)"
  if [[ -z "$id" ]]; then
    log "no stack in $REPO"
    return 0
  fi
  in_repo supabase stop --project-id "$id" --no-backup >&2
  rm -f "$(session_file)" "$STACKS_DIR/$id"
  log "stack $id and its data are gone"
}

# Deletes every registered stack whose checkout is gone or names another
# stack now: a worktree deleted without `down` leaves its containers
# running. Stacks started by hand or before this script are not registered
# and stay; `supabase stop --project-id <name> --no-backup` deletes one.
cmd_prune() {
  local entry id checkout named
  [[ -d "$STACKS_DIR" ]] || return 0
  for entry in "$STACKS_DIR"/*; do
    [[ -L "$entry" ]] || continue
    id="$(basename "$entry")"
    checkout="$(readlink "$entry")"
    named="$(sed -n 's/^SUPABASE_PROJECT_ID=//p' "$checkout/supabase/.env.development.local" 2>/dev/null || true)"
    [[ "$named" == "$id" ]] && continue
    log "pruning stack $id: $checkout no longer uses it"
    if in_repo supabase stop --project-id "$id" --no-backup >&2; then
      rm -f "$entry"
    else
      log "could not stop stack $id; it stays registered for the next prune"
    fi
  done
}

usage() {
  cat <<EOF
Usage: stack.sh <command>

  up [--db-only]   Start this checkout's own stack: named after the checkout,
                   on ports the OS assigns, its data kept across ups. From
                   then on every supabase command run in this checkout uses
                   it: supabase db reset --local, supabase test db --local,
                   supabase status -o env (URLs and keys). --db-only starts
                   the database alone, enough for migrations, pgTAP, lint and
                   schema:generate; a later full up adds the rest.
  down             Stop the stack and delete its data and its session file.
  prune            Delete the stacks of checkouts that are gone (up does it
                   too). Registry: $STACKS_DIR
  help             This text.
EOF
}

main() {
  case "${1:-help}" in
    up) shift; cmd_up "$@" ;;
    down) cmd_down ;;
    prune) cmd_prune ;;
    help | -h | --help) usage ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
}

# Sourced by stack.test.sh, which calls the functions itself.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
