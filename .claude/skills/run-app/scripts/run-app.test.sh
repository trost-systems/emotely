#!/usr/bin/env bash
# Tests for the parts of run-app.sh that need no simulator: the smoke-domain
# allowlist, the session id, the machine-wide smoke-account lock and the
# posting copies. Sources the script (its `main` runs only when executed).
# Run from anywhere:
#   bash .claude/skills/run-app/scripts/run-app.test.sh
set -euo pipefail

# shellcheck source=SCRIPTDIR/run-app.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-app.sh"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A process that is certainly dead: a finished background job.
dead_pid() {
  true &
  local pid=$!
  wait "${pid}"
  printf '%s' "${pid}"
}

# --- the smoke-domain allowlist ---------------------------------------------------

test_allows_an_address_on_a_listed_domain() {
  smoke_domain_allowed 'smoke@getemotely.com' 'example.com,getemotely.com' ||
    fail "allows an address on a listed domain"
}

test_allows_a_listed_domain_whatever_its_case_and_spacing() {
  smoke_domain_allowed 'Smoke@GetEmotely.com' ' example.com , GETEMOTELY.COM ' ||
    fail "allows a listed domain whatever its case and spacing"
}

test_refuses_an_address_on_an_unlisted_domain() {
  if smoke_domain_allowed 'someone@gmail.com' 'example.com,getemotely.com'; then
    fail "refuses an address on an unlisted domain"
  fi
}

test_refuses_a_subdomain_of_a_listed_domain() {
  if smoke_domain_allowed 'smoke@mail.getemotely.com' 'getemotely.com'; then
    fail "refuses a subdomain of a listed domain"
  fi
}

test_refuses_every_address_when_the_list_is_empty() {
  if smoke_domain_allowed 'smoke@example.com' ''; then
    fail "refuses every address when the list is empty"
  fi
}

test_read_smoke_account_refuses_a_missing_domain_list() {
  local env="${work}/no-domains.env" err
  printf 'SMOKE_EMAIL=smoke@example.com\nSMOKE_PASSWORD=made-up\n' >"${env}"
  if err="$(ENV_FILE="${env}" read_smoke_account 2>&1)"; then
    fail "read_smoke_account refuses a missing domain list: it passed"
  fi
  [[ "${err}" == *SMOKE_EMAIL_DOMAINS* ]] ||
    fail "read_smoke_account names SMOKE_EMAIL_DOMAINS: got ${err}"
}

test_read_smoke_account_refuses_an_unlisted_address() {
  local env="${work}/unlisted.env" err
  printf 'SMOKE_EMAIL=someone@gmail.com\nSMOKE_PASSWORD=made-up\nSMOKE_EMAIL_DOMAINS=example.com\n' >"${env}"
  if err="$(ENV_FILE="${env}" read_smoke_account 2>&1)"; then
    fail "read_smoke_account refuses an unlisted address: it passed"
  fi
  [[ "${err}" == *SMOKE_EMAIL_DOMAINS* ]] ||
    fail "read_smoke_account says which list refused it: got ${err}"
}

test_read_smoke_account_accepts_a_listed_address() {
  local env="${work}/listed.env"
  printf 'SMOKE_EMAIL="smoke@example.com"\nSMOKE_PASSWORD=made-up\nSMOKE_EMAIL_DOMAINS=getemotely.com,example.com\n' >"${env}"
  (ENV_FILE="${env}" read_smoke_account) 2>/dev/null ||
    fail "read_smoke_account accepts a listed address"
}

# --- the session id ---------------------------------------------------------------

test_a_session_id_is_the_checkout_name_and_a_random_suffix() {
  local id
  id="$(new_session_id /some/where/agent-a01f)"
  [[ "${id}" =~ ^agent-a01f-[0-9a-f]{6}$ ]] ||
    fail "a session id is the checkout name and a random suffix: got ${id}"
}

test_a_session_id_is_a_valid_marionette_instance_name() {
  local id
  id="$(new_session_id '/some/where/my checkout.v2')"
  [[ "${id}" =~ ^[a-zA-Z0-9_-]+$ ]] ||
    fail "a session id is a valid marionette instance name: got ${id}"
}

test_two_session_ids_of_one_checkout_differ() {
  [[ "$(new_session_id /x/emotely)" != "$(new_session_id /x/emotely)" ]] ||
    fail "two session ids of one checkout differ"
}

# --- the smoke-account lock -------------------------------------------------------

test_takes_a_free_lock() {
  local lock="${work}/free.lock"
  lock_take "${lock}" "$$" session-a /checkout/a ||
    fail "takes a free lock"
  [[ "$(lock_field "${lock}" session)" == session-a ]] ||
    fail "the lock records its session: got $(lock_field "${lock}" session)"
}

test_refuses_a_lock_whose_holder_is_alive_and_names_its_checkout() {
  local lock="${work}/held.lock"
  lock_take "${lock}" "$$" session-a /checkout/a
  if lock_take "${lock}" "$$" session-b /checkout/b; then
    fail "refuses a lock whose holder is alive"
  fi
  [[ "$(lock_field "${lock}" checkout)" == /checkout/a ]] ||
    fail "a refused lock still names its holder's checkout: got $(lock_field "${lock}" checkout)"
}

test_takes_over_a_lock_whose_holder_is_dead() {
  local lock="${work}/stale.lock"
  lock_take "${lock}" "$(dead_pid)" session-a /checkout/a
  lock_take "${lock}" "$$" session-b /checkout/b ||
    fail "takes over a lock whose holder is dead"
  [[ "$(lock_field "${lock}" session)" == session-b ]] ||
    fail "the taken-over lock records the new session: got $(lock_field "${lock}" session)"
}

test_a_reused_pid_does_not_keep_a_lock_alive() {
  local lock="${work}/reused.lock"
  # The right pid with a start time it never had: a pid reused by another process.
  ln -s "$(printf '%s\n%s\n%s\n%s' "$$" 'Thu Jan  1 00:00:00 1970' session-a /checkout/a)" "${lock}"
  lock_take "${lock}" "$$" session-b /checkout/b ||
    fail "a reused pid does not keep a lock alive"
}

test_handing_over_keeps_the_lock_and_changes_its_holder() {
  local lock="${work}/handover.lock" holder
  lock_take "${lock}" "$$" session-a /checkout/a
  sleep 60 &
  holder=$!
  lock_handover "${lock}" session-a "${holder}"
  [[ "$(lock_field "${lock}" pid)" == "${holder}" ]] ||
    fail "handing over changes the holder: got $(lock_field "${lock}" pid)"
  [[ "$(lock_field "${lock}" session)" == session-a ]] ||
    fail "handing over keeps the session"
  kill "${holder}"
  wait "${holder}" 2>/dev/null || true
  lock_take "${lock}" "$$" session-b /checkout/b ||
    fail "a lock handed to a process that died is stale"
}

test_releases_its_own_lock_only() {
  local lock="${work}/release.lock"
  lock_take "${lock}" "$$" session-a /checkout/a
  lock_release "${lock}" session-b
  [[ -L "${lock}" ]] || fail "does not release another session's lock"
  lock_release "${lock}" session-a
  [[ ! -L "${lock}" ]] || fail "releases its own lock"
}

test_of_many_concurrent_takers_exactly_one_wins() {
  local lock="${work}/race.lock" i won=0
  lock_take "${lock}" "$(dead_pid)" session-dead /checkout/dead
  for i in 1 2 3 4 5 6 7 8; do
    (lock_take "${lock}" "$$" "session-${i}" "/checkout/${i}" && touch "${work}/won-${i}") &
  done
  wait
  for i in 1 2 3 4 5 6 7 8; do
    [[ -e "${work}/won-${i}" ]] && won=$((won + 1))
  done
  ((won == 1)) || fail "of many concurrent takers exactly one wins: ${won} won"
}

test_take_account_lock_fails_fast_naming_the_other_checkout() {
  local err
  (LOCK_ROOT="${work}/locks" SMOKE_EMAIL=smoke@example.com SESSION=session-a REPO=/checkout/a \
    take_account_lock "$$") 2>/dev/null
  if err="$(LOCK_ROOT="${work}/locks" SMOKE_EMAIL=smoke@example.com SESSION=session-b REPO=/checkout/b \
    take_account_lock "$$" 2>&1)"; then
    fail "take_account_lock fails while another session holds the account"
  fi
  [[ "${err}" == */checkout/a* ]] ||
    fail "take_account_lock names the checkout holding the lock: got ${err}"
  [[ "${err}" != *" )"* ]] ||
    fail "take_account_lock prints the start time without ps's padding: got ${err}"
}

test_the_account_lock_is_per_account() {
  (LOCK_ROOT="${work}/per-account" SMOKE_EMAIL=one@example.com SESSION=session-a REPO=/checkout/a \
    take_account_lock "$$") 2>/dev/null
  (LOCK_ROOT="${work}/per-account" SMOKE_EMAIL=two@example.com SESSION=session-b REPO=/checkout/b \
    take_account_lock "$$") 2>/dev/null ||
    fail "the account lock is per account"
}

# --- posting copies ---------------------------------------------------------------

test_a_screenshot_posting_copy_is_600_px_wide_and_keeps_the_original() {
  command -v ffmpeg >/dev/null || return 0
  local dir="${work}/shots" width
  mkdir -p "${dir}/post"
  ffmpeg -loglevel error -f lavfi -i color=c=orange:s=1206x2622 -frames:v 1 "${dir}/01-journal.png"
  post_screenshots "${dir}"
  width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "${dir}/post/01-journal.png")"
  [[ "${width}" == 600 ]] || fail "a screenshot posting copy is 600 px wide: got ${width}"
  width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "${dir}/01-journal.png")"
  [[ "${width}" == 1206 ]] || fail "the original screenshot keeps its size: got ${width}"
}

test_a_video_posting_copy_is_a_sped_up_h264_mp4() {
  command -v ffmpeg >/dev/null || return 0
  local dir="${work}/video" codec duration
  mkdir -p "${dir}"
  ffmpeg -loglevel error -f lavfi -i testsrc=size=400x800:rate=30 -t 8 -c:v libvpx-vp9 "${dir}/video.webm"
  post_video "${dir}/video.webm" 4
  codec="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "${dir}/post/video-4x.mp4")"
  [[ "${codec}" == h264 ]] || fail "a video posting copy is h264: got ${codec}"
  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${dir}/post/video-4x.mp4")"
  [[ "${duration%%.*}" == 2 ]] || fail "a 4x copy of 8 s lasts 2 s: got ${duration}"
  [[ -e "${dir}/video.webm" ]] || fail "the original video stays"
}

test_a_video_posting_copy_takes_another_speed() {
  command -v ffmpeg >/dev/null || return 0
  local dir="${work}/video-1x" duration
  mkdir -p "${dir}"
  ffmpeg -loglevel error -f lavfi -i testsrc=size=400x800:rate=30 -t 3 -c:v libvpx-vp9 "${dir}/video.webm"
  post_video "${dir}/video.webm" 1
  duration="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "${dir}/post/video-1x.mp4")"
  [[ "${duration%%.*}" == 3 ]] || fail "a 1x copy keeps the length: got ${duration}"
}

test_refuses_a_speed_that_is_not_a_positive_integer() {
  if (valid_speed 0) 2>/dev/null || (valid_speed fast) 2>/dev/null; then
    fail "refuses a speed that is not a positive integer"
  fi
  (valid_speed 2) || fail "accepts speed 2"
}

command -v ffmpeg >/dev/null ||
  printf 'skip: no ffmpeg here, so the posting-copy tests do not run\n' >&2

for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "${test}"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "${failures}" >&2
  exit 1
fi
printf 'all run-app tests passed\n'
