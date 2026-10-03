#!/usr/bin/env bash
# Tells account holders and the waitlist about a material change to a
# privacy notice, through the change_notice schema
# (supabase/migrations/20261003120000_change_notice.sql).
#
#   change-notice.sh preview --about app|site|both \
#       --effective YYYY-MM-DD --en FILE [--de FILE] [--linked]
#   change-notice.sh send    (the same flags; Peter, at his own terminal)
#   change-notice.sh check   --notice UUID [--linked]
#
# --about names the notice that changes, and that decides who is told: a
# change to the app notice goes to account holders alone, one to the site
# notice to the waitlist alone, and only a change to both notices to both.
# A message file is the subject on its first line, a blank line, then the
# plain-text body. The local stack is the default target; --linked is the
# hosted project, through the maintainer's CLI login.
#
# preview is the dry run: counts and every mail as it would go out, nothing
# sent or recorded. send shows the same, then needs the number of readers
# typed at the terminal it runs in: a shell without one (an agent's) stops
# before anything is queued. check reads Resend's answers into the record.
set -euo pipefail

usage() {
  sed -n '6,9p' "$0" | sed 's/^# *//' >&2
  exit 64
}
die() {
  printf 'change-notice: %s\n' "$1" >&2
  exit 1
}

[[ $# -gt 0 ]] || usage
command="$1"
shift
about='' effective='' en='' de='' notice='' target='--local' sql='' args=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --about) about="${2:-}"; shift 2 ;;
    --effective) effective="${2:-}"; shift 2 ;;
    --en) en="${2:-}"; shift 2 ;;
    --de) de="${2:-}"; shift 2 ;;
    --notice) notice="${2:-}"; shift 2 ;;
    --linked) target='--linked'; shift ;;
    --local) target='--local'; shift ;;
    *) usage ;;
  esac
done

# Runs one SQL file and prints its rows as JSON: one stable shape whoever
# runs it, rather than the CLI's agent-dependent default.
query() {
  local out
  out="$(supabase db query "${target}" --agent no --output-format json --file "$1")" || true
  if ! jq -e 'type == "array"' <<<"${out}" >/dev/null 2>&1; then
    # A refusal (a date too close, no Vault key, the budget spent) comes
    # back as an error object; say what the database said, and stop.
    printf 'change-notice: %s\n' \
      "$(jq -r '.error.message? // .' <<<"${out}" 2>/dev/null || printf '%s' "${out}")" >&2
    exit 1
  fi
  printf '%s\n' "${out}"
}

b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

# One language of the message as SQL, into `sql`: subject and body travel
# base64, so no character in a notice can end a string early. The functions
# set globals rather than print, so a refusal in one ends the script:
# errexit does not reach into a command substitution.
part() {
  local file="$1" subject body
  [[ -r "${file}" ]] || die "cannot read ${file}"
  subject="$(sed -n '1p' "${file}")"
  [[ -n "${subject}" && -z "$(sed -n '2p' "${file}")" ]] ||
    die "${file}: the first line is the subject, the second is blank"
  body="$(tail -n +3 "${file}")"
  [[ -n "${body}" ]] || die "${file}: the body after the subject is empty"
  sql="jsonb_build_object('subject', convert_from(decode('$(b64 "${subject}")', 'base64'), 'utf8'), 'body', convert_from(decode('$(b64 "${body}")', 'base64'), 'utf8'))"
}

# The arguments every preview and send takes, into `args`, checked before
# any reaches SQL.
notice_args() {
  local audience
  case "${about}" in
    app) audience=accounts ;;
    site) audience=waitlist ;;
    both) audience=both ;;
    *) die "--about is the notice that changes: app (account holders), site (the waitlist) or both" ;;
  esac
  [[ "${effective}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    die "--effective is the date the change takes effect, YYYY-MM-DD"
  [[ -n "${en}" ]] || die "--en FILE is required: every notice has an English text"
  part "${en}"
  local message="jsonb_build_object('en', ${sql}"
  if [[ -n "${de}" ]]; then
    part "${de}"
    message="${message}, 'de', ${sql}"
  fi
  args="'${audience}', '${effective}', ${message})"
}

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

preview() {
  printf 'select change_notice.preview(%s) as preview;\n' "${args}" >"${tmp}"
  query "${tmp}" | jq -r '.[0].preview |
    "\(.recipients.total) readers (\(.recipients.account) by account, \(.recipients.waitlist) by the waitlist; \(.recipients.en) in English, \(.recipients.de) in German), \(.pending) not yet told.",
    "The change takes effect on \(.effective_on), \(.lead_days) days from today.",
    "Sending takes \(.runs_needed) daily run(s) of at most \(.per_day); every run must still be \(.min_lead_days) days or more before the change.",
    (.mails[] |
      "", "=== \(.kind) · \(.locale) · readers: \(.recipients) ===",
      "Subject: \(.subject)", "", .text)'
}

case "${command}" in
  preview)
    notice_args
    preview
    ;;
  send)
    notice_args
    pending="$(preview | tee /dev/stderr | sed -n '1s/.*, \([0-9]*\) not yet told\./\1/p')"
    # The gate. A send mails real people, so Peter approves it himself, at
    # a terminal, after reading the preview above. An agent's shell has no
    # terminal and stops here; there is no flag around it.
    if ! [[ -t 0 ]] || ! { : </dev/tty; } 2>/dev/null; then
      die "a send needs Peter at his own terminal, to read the preview and confirm; nothing was sent"
    fi
    [[ "${pending:-0}" -gt 0 ]] || die "nobody is left to tell; nothing was sent"
    printf '\nType %s (the readers not yet told) to send, anything else to stop: ' \
      "${pending}" >/dev/tty
    read -r answer </dev/tty
    [[ "${answer}" == "${pending}" ]] || die "not confirmed; nothing was sent"
    printf 'select change_notice.send(%s) as sent;\n' "${args}" >"${tmp}"
    sent="$(query "${tmp}" | jq -c '.[0].sent')"
    notice="$(jq -r '.notice_id' <<<"${sent}")"
    printf 'Queued %s, %s still to tell (run send again tomorrow). Notice %s.\n' \
      "$(jq -r '.queued' <<<"${sent}")" "$(jq -r '.remaining' <<<"${sent}")" "${notice}"
    # Resend usually answers within seconds; pg_net keeps the answer for
    # six hours, which is how long `check` can still read it.
    for _ in 1 2 3 4 5 6; do
      sleep 5
      printf "select change_notice.check('%s') as check;\n" "${notice}" >"${tmp}"
      result="$(query "${tmp}" | jq -c '.[0].check')"
      [[ "$(jq -r '.unanswered' <<<"${result}")" == 0 ]] && break
    done
    jq -r '"\(.queued) queued, \(.accepted) accepted, \(.failed) failed, \(.unanswered) unanswered."' <<<"${result}"
    ;;
  check)
    [[ "${notice}" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]] ||
      die "--notice is the notice's id (a uuid)"
    printf "select change_notice.check('%s') as check;\n" "${notice}" >"${tmp}"
    query "${tmp}" | jq -r '.[0].check |
      "\(.queued) queued, \(.accepted) accepted, \(.failed) failed, \(.unanswered) unanswered."'
    ;;
  *)
    usage
    ;;
esac
