#!/usr/bin/env bash
# Tests for stack.sh without Docker: the stack's name, the ports, the
# session file, the retry on a taken port, and pruning the stacks of deleted
# checkouts. `supabase` and `docker` are stubbed as shell functions that log
# their calls. Sources the script (its `main` runs only when executed).
# Run from anywhere:
#   bash .claude/skills/supabase/scripts/stack.test.sh
set -euo pipefail

# shellcheck source=SCRIPTDIR/stack.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/stack.sh"
REAL_REPO="${REPO}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# --- the stack's name -------------------------------------------------------------

test_names_the_stack_after_the_checkout() {
  local id
  id="$(new_project_id /Users/someone/emotely/.claude/worktrees/issue-158-day)"
  [[ "${id}" =~ ^emotely-issue-158-day-[0-9a-f]{6}$ ]] ||
    fail "names the stack after the checkout: got ${id}"
}

test_gives_two_stacks_of_one_checkout_name_different_names() {
  [[ "$(new_project_id /a/emotely)" != "$(new_project_id /b/emotely)" ]] ||
    fail "gives two clones named alike different stacks"
}

test_keeps_the_name_within_the_cli_limit_and_alphabet() {
  local id
  id="$(new_project_id '/x/a very long checkout name, with commas & spaces and more')"
  ((${#id} <= 40)) || fail "keeps the name within 40 characters: got ${#id}"
  [[ "${id}" =~ ^[a-zA-Z0-9_.-]+$ ]] || fail "keeps the name to the CLI's alphabet: got ${id}"
}

# --- ports --------------------------------------------------------------------------

test_takes_as_many_distinct_free_ports_as_asked() {
  local ports
  ports="$(free_ports 5)"
  [[ "$(wc -l <<<"${ports}" | tr -d ' ')" == 5 ]] || fail "takes 5 ports: got ${ports}"
  [[ "$(sort -u <<<"${ports}" | wc -l | tr -d ' ')" == 5 ]] || fail "takes distinct ports: got ${ports}"
  while read -r port; do
    if ! [[ "${port}" =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
      fail "takes unprivileged ports: got ${port}"
    fi
  done <<<"${ports}"
}

# --- the session file ---------------------------------------------------------------

# Each test gets a checkout and a registry of its own. The stubs log each
# call as "<working directory>|<arguments>"; `docker ps` lists $RUNNING; a
# start fails with $START_ERROR as many times as $REPO/start-failures says.
RUNNING=""
START_ERROR=""
fixture() {
  REPO="$(mktemp -d "${work}/checkout-XXXXXX")"
  mkdir -p "${REPO}/supabase"
  STACKS_DIR="${REPO}.stacks"
  : >"${REPO}/calls"
  printf '0' >"${REPO}/start-failures"
  RUNNING=""
  START_ERROR='Bind for 0.0.0.0:54324 failed: port is already allocated'
}
supabase() {
  local left
  printf '%s|%s\n' "${PWD}" "$*" >>"${REPO}/calls"
  if [[ "$1" == start || "$1 ${2:-}" == "db start" ]]; then
    left="$(cat "${REPO}/start-failures")"
    if ((left > 0)); then
      printf '%s' "$((left - 1))" >"${REPO}/start-failures"
      printf '%s\n' "${START_ERROR}" >&2
      return 1
    fi
  fi
}
docker() {
  if [[ "$1" == ps && -n "${RUNNING}" ]]; then
    tr ' ' '\n' <<<"${RUNNING}"
  fi
}
calls() { cat "${REPO}/calls"; }
count_calls() { grep -c -F -x "$1" "${REPO}/calls" || true; }
session_value() { sed -n "s/^$1=//p" "${REPO}/supabase/.env.development.local"; }

test_up_starts_a_stack_named_after_the_checkout_on_free_ports() {
  fixture
  cmd_up >/dev/null 2>&1 || fail "up starts a stack: it failed"
  [[ "$(session_value SUPABASE_PROJECT_ID)" =~ ^emotely-checkout-[A-Za-z0-9]+-[0-9a-f]{6}$ ]] ||
    fail "up names the stack after the checkout: got $(session_value SUPABASE_PROJECT_ID)"
  local key
  for key in API DB DB_SHADOW STUDIO LOCAL_SMTP; do
    [[ "$(session_value "SUPABASE_${key}_PORT")" =~ ^[0-9]+$ ]] ||
      fail "up gives the stack a ${key} port: got $(session_value "SUPABASE_${key}_PORT")"
  done
  [[ "$(count_calls "${REPO}|start")" == 1 ]] ||
    fail "up runs supabase start from the checkout: calls were $(calls)"
}

test_up_keeps_the_stacks_name_across_ups() {
  fixture
  cmd_up >/dev/null 2>&1
  local first
  first="$(session_value SUPABASE_PROJECT_ID)"
  cmd_up >/dev/null 2>&1
  [[ "$(session_value SUPABASE_PROJECT_ID)" == "${first}" ]] ||
    fail "up keeps the stack's name, and so its data: ${first} became $(session_value SUPABASE_PROJECT_ID)"
}

test_up_db_only_starts_only_the_database() {
  fixture
  cmd_up --db-only >/dev/null 2>&1 || fail "up --db-only: it failed"
  [[ "$(count_calls "${REPO}|db start")" == 1 && "$(count_calls "${REPO}|start")" == 0 ]] ||
    fail "up --db-only runs supabase db start alone: calls were $(calls)"
}

test_up_leaves_a_running_stack_alone() {
  fixture
  cmd_up >/dev/null 2>&1
  local id
  id="$(session_value SUPABASE_PROJECT_ID)"
  RUNNING="supabase_db_${id} supabase_kong_${id}"
  cmd_up >/dev/null 2>&1 || fail "up on a running stack: it failed"
  [[ "$(count_calls "${REPO}|start")" == 1 ]] ||
    fail "up leaves a running stack alone: calls were $(calls)"
}

test_up_restarts_a_database_only_stack_as_a_full_stack() {
  fixture
  cmd_up --db-only >/dev/null 2>&1
  RUNNING="supabase_db_$(session_value SUPABASE_PROJECT_ID)"
  cmd_up >/dev/null 2>&1 || fail "up on a database-only stack: it failed"
  [[ "$(count_calls "${REPO}|stop")" == 1 && "$(count_calls "${REPO}|start")" == 1 ]] ||
    fail "up stops a database-only stack, keeping its data, then starts it whole: calls were $(calls)"
}

test_up_retries_a_taken_port_with_new_ports() {
  fixture
  printf '1' >"${REPO}/start-failures"
  cmd_up >/dev/null 2>&1 || fail "up retries a taken port: it failed"
  [[ "$(count_calls "${REPO}|start")" == 2 ]] ||
    fail "up starts again after a taken port: calls were $(calls)"
}

test_up_gives_up_at_once_on_any_other_failure() {
  fixture
  printf '1' >"${REPO}/start-failures"
  START_ERROR='Cannot connect to the Docker daemon'
  if (cmd_up >/dev/null 2>&1); then
    fail "up fails when the stack cannot start: it passed"
  fi
  [[ "$(count_calls "${REPO}|start")" == 1 ]] ||
    fail "up does not retry what a new port cannot fix: calls were $(calls)"
}

test_up_registers_the_stack_machine_wide() {
  fixture
  cmd_up >/dev/null 2>&1
  [[ "$(readlink "${STACKS_DIR}/$(session_value SUPABASE_PROJECT_ID)")" == "${REPO}" ]] ||
    fail "up registers the stack under its name, pointing at the checkout"
}

test_down_deletes_the_stack_its_data_and_the_session() {
  fixture
  cmd_up >/dev/null 2>&1
  local id
  id="$(session_value SUPABASE_PROJECT_ID)"
  cmd_down >/dev/null 2>&1 || fail "down: it failed"
  [[ "$(count_calls "${REPO}|stop --project-id ${id} --no-backup")" == 1 ]] ||
    fail "down stops the stack and deletes its volumes: calls were $(calls)"
  [[ ! -e "${REPO}/supabase/.env.development.local" ]] || fail "down removes the session file"
  [[ ! -L "${STACKS_DIR}/${id}" ]] || fail "down unregisters the stack"
}

test_down_without_a_stack_does_nothing() {
  fixture
  cmd_down >/dev/null 2>&1 || fail "down without a stack: it failed"
  [[ -z "$(calls)" ]] || fail "down without a stack calls nothing: calls were $(calls)"
}

test_up_prunes_the_stacks_of_deleted_checkouts_and_only_those() {
  fixture
  mkdir -p "${STACKS_DIR}"
  ln -s "${work}/deleted-checkout" "${STACKS_DIR}/emotely-deleted-aaaaaa"
  local live="${work}/live-checkout"
  mkdir -p "${live}/supabase"
  printf 'SUPABASE_PROJECT_ID=emotely-live-bbbbbb\n' >"${live}/supabase/.env.development.local"
  ln -s "${live}" "${STACKS_DIR}/emotely-live-bbbbbb"
  cmd_up >/dev/null 2>&1
  [[ "$(count_calls "${REPO}|stop --project-id emotely-deleted-aaaaaa --no-backup")" == 1 ]] ||
    fail "up deletes the stack of a deleted checkout: calls were $(calls)"
  [[ ! -L "${STACKS_DIR}/emotely-deleted-aaaaaa" ]] || fail "up unregisters the pruned stack"
  [[ "$(grep -c -F 'emotely-live-bbbbbb' "${REPO}/calls" || true)" == 0 && -L "${STACKS_DIR}/emotely-live-bbbbbb" ]] ||
    fail "up leaves another checkout's live stack alone: calls were $(calls)"
}

test_prunes_a_stack_its_checkout_has_replaced() {
  fixture
  mkdir -p "${STACKS_DIR}" "${work}/moved-on/supabase"
  printf 'SUPABASE_PROJECT_ID=emotely-moved-on-dddddd\n' >"${work}/moved-on/supabase/.env.development.local"
  ln -s "${work}/moved-on" "${STACKS_DIR}/emotely-moved-on-cccccc"
  cmd_prune >/dev/null 2>&1 || fail "prune: it failed"
  [[ "$(count_calls "${REPO}|stop --project-id emotely-moved-on-cccccc --no-backup")" == 1 ]] ||
    fail "prune deletes a stack its checkout no longer names: calls were $(calls)"
}

test_git_ignores_the_session_file() {
  git -C "${REAL_REPO}" check-ignore -q "${REAL_REPO}/supabase/.env.development.local" ||
    fail "git ignores supabase/.env.development.local"
}

for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "${test}"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "${failures}" >&2
  exit 1
fi
printf 'all stack tests passed\n'
