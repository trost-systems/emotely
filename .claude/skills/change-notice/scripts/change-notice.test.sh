#!/usr/bin/env bash
# Tests for change-notice.sh, with a fake `supabase` on the PATH that logs
# every query it is given and answers with canned JSON. Nothing reaches a
# database. Run from anywhere:
#   bash .claude/skills/change-notice/scripts/change-notice.test.sh
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/change-notice.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# The fake CLI: appends its arguments and the SQL it was handed (inline or
# by --file) to FAKE_LOG, then prints FAKE_ANSWER.
mkdir -p "${work}/bin"
cat >"${work}/bin/supabase" <<'EOF'
#!/usr/bin/env bash
printf 'ARGS %s\n' "$*" >>"${FAKE_LOG}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file | -f) cat "$2" >>"${FAKE_LOG}"; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s\n' "${FAKE_ANSWER}"
EOF
chmod +x "${work}/bin/supabase"

preview_answer='[{"preview": {
  "audience": "both", "effective_on": "2026-12-01", "lead_days": 59,
  "recipients": {"total": 3, "account": 2, "waitlist": 1, "en": 1, "de": 2},
  "pending": 3, "runs_needed": 1, "per_day": 50, "min_lead_days": 30,
  "mails": [
    {"kind": "account", "locale": "en", "recipients": 1,
     "subject": "What changes", "text": "Hi,\n\nSomething changes.\n\n-- \nfooter"},
    {"kind": "waitlist", "locale": "de", "recipients": 1,
     "subject": "Was sich ändert", "text": "Hallo,\n\nEtwas ändert sich."}
  ]}}]'

printf 'What changes\n\nHi,\n\nSomething changes.\n' >"${work}/en.txt"
printf 'Was sich ändert\n\nHallo,\n\nEtwas ändert sich.\n' >"${work}/de.txt"

# Runs the script with the fake CLI and no terminal; sets `status`,
# `output` and `log`.
run() {
  local logfile="${work}/log-${RANDOM}"
  : >"${logfile}"
  set +e
  output="$(FAKE_LOG="${logfile}" FAKE_ANSWER="${FAKE_ANSWER:-${preview_answer}}" \
    PATH="${work}/bin:${PATH}" bash "${script}" "$@" 2>&1 </dev/null)"
  status=$?
  set -e
  log="$(cat "${logfile}")"
}

# What a message file's text looks like in the SQL: base64, so no quote in
# a notice can end a string early.
encoded() { printf '%s' "$1" | base64 | tr -d '\n'; }

test_preview_prints_the_count_and_every_mail() {
  run preview --about both --effective 2026-12-01 \
    --en "${work}/en.txt" --de "${work}/de.txt"
  [[ ${status} -eq 0 ]] || fail "preview: exit ${status}: ${output}"
  [[ "${output}" == *"3 readers"* ]] || fail "preview: no total: ${output}"
  [[ "${output}" == *"59 days"* ]] || fail "preview: no lead time: ${output}"
  [[ "${output}" == *"Subject: Was sich ändert"* ]] ||
    fail "preview: German mail not rendered: ${output}"
  [[ "${output}" == *"Something changes."* ]] ||
    fail "preview: English body not rendered: ${output}"
}

test_preview_hands_the_text_over_encoded() {
  run preview --about both --effective 2026-12-01 \
    --en "${work}/en.txt" --de "${work}/de.txt"
  [[ "${log}" == *"change_notice.preview('both', '2026-12-01'"* ]] ||
    fail "preview: not the dry-run function: ${log}"
  [[ "${log}" == *"$(encoded 'Was sich ändert')"* ]] ||
    fail "preview: German subject not passed encoded: ${log}"
  [[ "${log}" == *"$(encoded $'Hi,\n\nSomething changes.')"* ]] ||
    fail "preview: English body not passed encoded: ${log}"
}

test_preview_runs_against_the_local_stack_unless_told() {
  run preview --about site --effective 2026-12-01 --en "${work}/en.txt"
  [[ "${log}" == *"--local"* && "${log}" != *"--linked"* ]] ||
    fail "default target is not local: ${log}"
  run preview --about site --effective 2026-12-01 \
    --en "${work}/en.txt" --linked
  [[ "${log}" == *"--linked"* ]] || fail "--linked not passed on: ${log}"
}

test_refuses_a_message_without_a_subject_line() {
  printf 'Hi,\nno blank line after the subject\n' >"${work}/bad.txt"
  run preview --about both --effective 2026-12-01 --en "${work}/bad.txt"
  [[ ${status} -ne 0 ]] || fail "a message without a subject passed"
  [[ "${output}" == *"subject"* ]] || fail "refusal does not say why: ${output}"
  [[ -z "${log}" ]] || fail "a refused message reached the database: ${log}"
}

test_an_app_change_reaches_account_holders_and_a_site_change_the_waitlist() {
  run preview --about app --effective 2026-12-01 --en "${work}/en.txt"
  [[ "${log}" == *"change_notice.preview('accounts',"* ]] ||
    fail "an app change does not go to account holders alone: ${log}"
  run preview --about site --effective 2026-12-01 --en "${work}/en.txt"
  [[ "${log}" == *"change_notice.preview('waitlist',"* ]] ||
    fail "a site change does not go to the waitlist alone: ${log}"
}

test_the_audience_follows_the_notice_that_changes() {
  # The sender names which notice changed; there is no flag that picks a
  # set of readers, so an app change cannot be sent to the waitlist.
  run preview --audience both --effective 2026-12-01 --en "${work}/en.txt"
  [[ ${status} -ne 0 && -z "${log}" ]] || fail "--audience is still accepted"
  run preview --effective 2026-12-01 --en "${work}/en.txt"
  [[ ${status} -ne 0 && -z "${log}" ]] || fail "a preview without --about ran"
  [[ "${output}" == *"--about"* ]] || fail "the refusal does not name --about: ${output}"
}

test_preview_says_how_many_daily_runs_it_takes() {
  run preview --about both --effective 2026-12-01 --en "${work}/en.txt"
  [[ "${output}" == *"1 daily run"* && "${output}" == *"30 days"* ]] ||
    fail "preview: no runs and lead time rule: ${output}"
}

test_says_what_the_database_refused() {
  FAKE_ANSWER='{"_tag":"Error","error":{"message":"change_notice: the change must take effect at least 30 days from today"}}' \
    run preview --about app --effective 2026-10-20 --en "${work}/en.txt"
  [[ ${status} -ne 0 ]] || fail "a refusal from the database passed"
  [[ "${output}" == *"at least 30 days"* ]] ||
    fail "the database's refusal is not shown: ${output}"
}

test_refuses_an_audience_or_date_it_cannot_quote() {
  run preview --about "both'); drop table x; --" --effective 2026-12-01 \
    --en "${work}/en.txt"
  [[ ${status} -ne 0 && -z "${log}" ]] || fail "a bad audience reached the database"
  run preview --about both --effective tomorrow --en "${work}/en.txt"
  [[ ${status} -ne 0 && -z "${log}" ]] || fail "a bad date reached the database"
}

test_send_without_a_terminal_sends_nothing() {
  # The gate: an agent's shell has no terminal, so a send stops at the
  # preview and never calls change_notice.send.
  run send --about both --effective 2026-12-01 \
    --en "${work}/en.txt" --linked
  [[ ${status} -ne 0 ]] || fail "send without a terminal succeeded"
  [[ "${output}" == *"Peter"* ]] ||
    fail "the refusal does not say who must run it: ${output}"
  [[ "${log}" != *"change_notice.send("* ]] ||
    fail "send without a terminal called change_notice.send: ${log}"
}

test_check_reads_the_answers_of_one_notice() {
  FAKE_ANSWER='[{"check": {"queued": 3, "accepted": 3, "failed": 0, "unanswered": 0}}]' \
    run check --notice 6f1c1a52-1d7e-4c35-9a35-0f3c6a1d2b7e --linked
  [[ ${status} -eq 0 ]] || fail "check: exit ${status}: ${output}"
  [[ "${log}" == *"change_notice.check('6f1c1a52-1d7e-4c35-9a35-0f3c6a1d2b7e')"* ]] ||
    fail "check: not the check function: ${log}"
  [[ "${output}" == *"3 accepted"* ]] || fail "check: no counts: ${output}"
  run check --notice "x'); select 1; --"
  [[ ${status} -ne 0 ]] || fail "check accepted a notice id that is no uuid"
}

for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "${test}"
done

if [[ ${failures} -gt 0 ]]; then
  printf '%d failure(s)\n' "${failures}" >&2
  exit 1
fi
printf 'change-notice.sh: all tests passed\n'
