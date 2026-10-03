#!/usr/bin/env bash
# The performance budget (#169): runs the app's main paths in profile mode
# (integration_test/perf_test.dart through test_driver/perf_driver.dart),
# optionally measures the real backend's latency, and judges both against
# apps/mobile/app/integration_test/perf_budget.yaml. `perf.sh help` for usage.
#
# Profile mode needs a real Flutter engine: an Android emulator or a
# phone. Flutter runs only debug builds on the iOS simulator. Without
# --device, `run` boots a fresh headless Android emulator of its own, named
# after the session, and deletes it again, so several sessions on one
# machine never share one.
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The account lock and the secrets handling are run-app.sh's;
# sourcing it defines them and runs nothing.
# shellcheck source=SCRIPTDIR/run-app.sh
source "$SCRIPTS_DIR/run-app.sh"

BUDGET="$APP_DIR/integration_test/perf_budget.yaml"
# One run per checkout; its emulator is recorded here for `down`.
PERF_STATE_DIR="$APP_DIR/build/perf-run"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
# The system image a local emulator boots: the host's own architecture, so
# it runs under hardware virtualisation.
AVD_IMAGE="${EMOTELY_AVD_IMAGE:-system-images;android-34;google_apis;$([[ "$(uname -m)" == arm64 ]] && echo arm64-v8a || echo x86_64)}"
# The hosted project, as `lib/app/environment.dart` defaults to it. Both are
# public (ADR 0010); the latency probe signs in and reads with them.
SUPABASE_URL="https://khfkszlujgkfjgnawdlf.supabase.co"
SUPABASE_PUBLISHABLE_KEY="sb_publishable_di6BB76PPuuoDklt7jtI0w_KlwO_8JF"
# The latency probe signs in as this service account in the emotely-ci
# Google Cloud project, with a Google ID token for the web client of
# supabase/config.toml's [auth.external.google] (ADR 0008, #304).
PROBE_SERVICE_ACCOUNT="signin-probe@emotely-ci.iam.gserviceaccount.com"
GOOGLE_WEB_CLIENT_ID="928057308670-ak9h2h5h8s9rpsgcgto30uf5ecg4thq6.apps.googleusercontent.com"
# Supabase reads and agent rounds per latency measurement.
READ_SAMPLES=20
AGENT_SAMPLES=5

STEP="setup"
log() { printf '[%s] %s\n' "$STEP" "$*" >&2; }
die() {
  printf 'perf: step "%s" failed: %s\n' "$STEP" "$*" >&2
  exit 2
}

perf_usage() {
  cat <<EOF
Usage: perf.sh <command>

  run [options]    Build the app in profile mode, run the three main paths
                   (journal scroll, entry open, session round) on a device,
                   and judge the run against the budget. Exits 1 over budget.
                   Prints the verdict; the run directory holds summary.md,
                   result.json, requests.json and each path's timeline.
  latency <dir>    Measure the deployed backend as the probe's account
                   ($PROBE_SERVICE_ACCOUNT, signed in with a Google ID
                   token: PROBE_ID_TOKEN, or minted with the gcloud config
                   in ~/.config/emotely/gcloud): $READ_SAMPLES Supabase reads and
                   $AGENT_SAMPLES agent first rounds, into <dir>/latency.json. Takes that
                   account's lock.
  gate <dir>... --env <name>
                   Judge a run directory again (after editing the budget),
                   or the median of several runs of one commit.
  baseline <dir>...
                   Each path's baseline from several runs on one
                   environment: the slowest p90 seen, for the budget file.
  down             Stop and delete an emulator a crashed \`run\` left behind.

Options for run:
  --device <id>    Run on this device (\`fvm flutter devices\`) instead of a
                   fresh emulator: an emulator that is already up, or a
                   phone, which is what the frame numbers are really about.
                   A phone gets the profile build installed over whatever
                   emotely build it has.
  --env <name>     The budget environment to judge against. Default:
                   local-emulator for the fresh emulator, device for
                   --device.
  --out <dir>      The run directory. Default: apps/mobile/app/build/perf/<time>.
  --latency        Also measure the deployed backend (see latency).

The fake backend inside the app is made up (ADR 0005); the latency probe
reads the probe account's own rows and prints only timings.
EOF
}

# --- the device -------------------------------------------------------------------

EMULATOR_SERIAL=""

# A free console port for an emulator: even, 5554-5680, not taken by one
# already running (any session's) nor by anything else listening.
free_emulator_port() {
  local port taken
  taken="$(adb devices 2>/dev/null | sed -n 's/^emulator-\([0-9]*\).*/\1/p')"
  for ((port = 5554; port <= 5680; port += 2)); do
    grep -qx "$port" <<<"$taken" && continue
    lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && continue
    printf '%s' "$port"
    return
  done
  return 1
}

# Creates this session's AVD and boots it headless; `emulator_down` deletes
# it. The state names both, so `perf.sh down` can clean up after a crash.
emulator_up() {
  STEP="emulator"
  local avd="emotely-perf-$1" port pid deadline
  [[ -x "$ANDROID_SDK/emulator/emulator" ]] || die "no Android emulator in $ANDROID_SDK (ANDROID_HOME)"
  printf 'no\n' | "$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager" create avd \
    -n "$avd" -k "$AVD_IMAGE" -d pixel_7 >/dev/null ||
    die "could not create AVD $avd from $AVD_IMAGE (sdkmanager --install \"$AVD_IMAGE\")"
  printf 'AVD=%s\n' "$avd" >>"$PERF_STATE_DIR/state"
  port="$(free_emulator_port)" || die "no free emulator port"
  "$ANDROID_SDK/emulator/emulator" -avd "$avd" -port "$port" -no-window -no-audio \
    -no-snapshot -no-boot-anim -gpu host >"$PERF_STATE_DIR/emulator.log" 2>&1 &
  pid=$!
  printf 'EMULATOR_PID=%s\n' "$pid" >>"$PERF_STATE_DIR/state"
  EMULATOR_SERIAL="emulator-$port"
  deadline=$((SECONDS + 300))
  until [[ "$(adb -s "$EMULATOR_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; do
    kill -0 "$pid" 2>/dev/null || die "the emulator exited; see $PERF_STATE_DIR/emulator.log"
    ((SECONDS < deadline)) || die "$EMULATOR_SERIAL did not boot within 300s"
    sleep 2
  done
  log "$EMULATOR_SERIAL up ($avd)"
}

emulator_down() {
  [[ -f "$PERF_STATE_DIR/state" ]] || return 0
  local pid avd
  pid="$(sed -n 's/^EMULATOR_PID=//p' "$PERF_STATE_DIR/state" | tail -1)"
  avd="$(sed -n 's/^AVD=//p' "$PERF_STATE_DIR/state" | tail -1)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  if [[ -n "$avd" ]]; then
    "$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager" delete avd -n "$avd" >/dev/null 2>&1 || true
  fi
  rm -rf "$PERF_STATE_DIR"
}

# --- run ------------------------------------------------------------------------

cmd_run() {
  local device="" env="" out="" measure_latency=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device) device="${2:?--device needs an id}"; shift 2 ;;
      --env) env="${2:?--env needs a name}"; shift 2 ;;
      --out) out="${2:?--out needs a directory}"; shift 2 ;;
      --latency) measure_latency=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  STEP="preflight"
  local tool
  for tool in jq yq adb; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
  done
  # FVM pins Flutter locally (apps/mobile/app/.fvmrc); CI installs that
  # version as plain `flutter`.
  local flutter=(flutter)
  command -v fvm >/dev/null && flutter=(fvm flutter)
  command -v "${flutter[0]}" >/dev/null || die "missing tool: fvm (or flutter)"
  out="${out:-$APP_DIR/build/perf/$(date +%Y%m%d-%H%M%S)}"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"

  if [[ -z "$device" ]]; then
    mkdir -p "$(dirname "$PERF_STATE_DIR")"
    mkdir "$PERF_STATE_DIR" 2>/dev/null ||
      die "a run is already going in this checkout (or crashed: perf.sh down)"
    OWN_EMULATOR=1
    emulator_up "$(new_session_id "$REPO")"
    device="$EMULATOR_SERIAL"
    env="${env:-local-emulator}"
  fi
  env="${env:-device}"

  STEP="drive"
  log "profile build and the three paths on $device (a few minutes)"
  # The endless trace buffer: the default ring holds only the last ~300
  # frames of a path and drops the rest without a word, the cold first
  # frames first. The test records only the streams the summary reads, so
  # a path's trace stays under 20 MB.
  (cd "$APP_DIR" && PERF_OUT="$out" "${flutter[@]}" drive --profile --no-dds \
    --endless-trace-buffer -d "$device" \
    --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart) \
    >"$out/drive.log" 2>&1 || die "the profile run failed; see $out/drive.log"

  if ((measure_latency)); then
    cmd_latency "$out"
  fi

  local status=0
  cmd_gate "$out" --env "$env" || status=$?
  cat "$out/summary.md"
  printf '\nperf: run in %s\n' "$out" >&2
  return "$status"
}

# --- latency --------------------------------------------------------------------

# probe_id_token <secrets dir>: a Google ID token for the probe's service
# account, audience our Google web client. CI hands one over (PROBE_ID_TOKEN,
# minted keyless by google-github-actions/auth); locally it is minted through
# IAM Credentials with the emotely gcloud config, whose account needs
# roles/iam.serviceAccountOpenIdTokenCreator on the service account: nobody
# holds that standing, so a local run needs a grant for it first
# (references/performance.md).
probe_id_token() {
  if [[ -n "${PROBE_ID_TOKEN:-}" ]]; then
    printf '%s' "$PROBE_ID_TOKEN"
    return
  fi
  local config="$HOME/.config/emotely/gcloud" token
  [[ -d "$config" ]] ||
    die "no probe token: set PROBE_ID_TOKEN, or sign in to $config (CLOUDSDK_CONFIG) with an account granted roles/iam.serviceAccountOpenIdTokenCreator on $PROBE_SERVICE_ACCOUNT (references/performance.md)"
  printf 'header = "Authorization: Bearer %s"\n' "$(CLOUDSDK_CONFIG="$config" gcloud auth print-access-token)" \
    >"$1/gcp.curl" || die "gcloud could not give an access token from $config"
  token="$(curl -sS --fail -K "$1/gcp.curl" -H 'content-type: application/json' \
    --data "$(jq -cn --arg a "$GOOGLE_WEB_CLIENT_ID" '{audience: $a, includeEmail: true}')" \
    "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/$PROBE_SERVICE_ACCOUNT:generateIdToken" |
    jq -r '.token // empty')" ||
    die "could not mint an ID token for $PROBE_SERVICE_ACCOUNT: the gcloud account needs roles/iam.serviceAccountOpenIdTokenCreator on it (references/performance.md)"
  [[ -n "$token" ]] || die "IAM Credentials returned no ID token for $PROBE_SERVICE_ACCOUNT"
  printf '%s' "$token"
}

# sign_in_probe <secrets dir>: the probe's Supabase access token, through
# Auth's ID-token grant. Not a password grant: under the auth captcha (#94)
# that needs a human check, and the ID-token grant needs none (#304). The
# before-user-created hook lets this one service account have an account.
sign_in_probe() {
  local id_token token
  # A `die` in there ends only the substitution; this ends the probe.
  id_token="$(probe_id_token "$1")" || exit 2
  jq -n --arg t "$id_token" '{provider: "google", id_token: $t}' >"$1/grant.json"
  printf 'header = "apikey: %s"\n' "$SUPABASE_PUBLISHABLE_KEY" >"$1/grant.curl"
  token="$(curl -sS --fail -K "$1/grant.curl" -H 'Content-Type: application/json' \
    --data @"$1/grant.json" "$SUPABASE_URL/auth/v1/token?grant_type=id_token" |
    jq -r '.access_token // empty')" || die "the probe's ID-token grant failed"
  [[ -n "$token" ]] || die "the probe's ID-token grant returned no token"
  printf '%s' "$token"
}

# latency <dir>: the deployed backend as the probe's account, from here. The
# journal list and an entry, read the way the app reads them, and the
# agent's first round of a new session: the time to its first byte (the
# gate) and to its last (tracked). The agent answers a round in one piece,
# so the two differ by the transfer alone. Timings only reach the file.
cmd_latency() {
  STEP="latency"
  local out="${1:?latency needs a run directory}"
  local lock_pid=$$
  # One latency run at a time on the probe's account, as run-app.sh holds
  # the smoke account; account_lock keys on SMOKE_EMAIL.
  SMOKE_EMAIL="$PROBE_SERVICE_ACCOUNT"
  SESSION="perf-$(new_session_id "$REPO")"
  take_account_lock "$lock_pid"
  LOCKED_ACCOUNT="$(account_lock)"
  local secrets
  secrets="$(mktemp -d)"
  SECRETS_DIR="$secrets"
  chmod 700 "$secrets"

  local token
  token="$(sign_in_probe "$secrets")" || exit 2
  printf 'header = "apikey: %s"\n' "$SUPABASE_PUBLISHABLE_KEY" >"$secrets/supabase.curl"
  printf 'header = "Authorization: Bearer %s"\n' "$token" >>"$secrets/supabase.curl"
  printf 'header = "Authorization: Bearer %s"\n' "$token" >"$secrets/agent.curl"

  local journal_url="$SUPABASE_URL/rest/v1/entries?select=*&order=created_at.desc" entry_id i reads=()
  entry_id="$(curl -sS --fail -K "$secrets/supabase.curl" "$journal_url&limit=1" | jq -r '.[0].id // empty')" ||
    die "the journal read failed"
  for ((i = 0; i < READ_SAMPLES; i++)); do
    # Alternately the journal and one entry (the open session's row when the
    # journal is empty), each on a fresh connection.
    local url="$journal_url" took
    if ((i % 2 == 1)); then
      if [[ -n "$entry_id" ]]; then
        url="$SUPABASE_URL/rest/v1/entries?select=*&id=eq.$entry_id"
      else
        url="$SUPABASE_URL/rest/v1/sessions?select=*&status=eq.in_progress"
      fi
    fi
    took="$(curl -sS --fail -o /dev/null -w '%{time_total}' -K "$secrets/supabase.curl" "$url")" ||
      die "a Supabase read failed"
    reads+=("$took")
  done

  local agent_url version first=() whole=() timing
  agent_url="${EMOTELY_AGENT_URL:-https://api.getemotely.com/api/advance-session}"
  version="$(yq '.version' "$APP_DIR/pubspec.yaml" | cut -d+ -f1)"
  for ((i = 0; i < AGENT_SAMPLES; i++)); do
    timing="$(curl -sS --fail -o /dev/null -w '%{time_starttransfer} %{time_total}' \
      -K "$secrets/agent.curl" -H 'content-type: application/json' \
      --data "$(jq -cn --arg v "$version" '{app_version: $v}')" "$agent_url")" ||
      die "an agent round failed"
    first+=("${timing% *}")
    whole+=("${timing#* }")
  done

  jq -n --arg measured "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg reads "${reads[*]}" --arg first "${first[*]}" --arg whole "${whole[*]}" '
    def ms: split(" ") | map(tonumber * 1000 | round);
    {measured_at: $measured,
     supabase_read_ms: ($reads | ms),
     agent_first_byte_ms: ($first | ms),
     agent_round_ms: ($whole | ms)}' >"$out/latency.json"
  log "$READ_SAMPLES Supabase reads and $AGENT_SAMPLES agent rounds in $out/latency.json"
}

# --- gate -----------------------------------------------------------------------

# One run directory as the gate reads it: its paths' timeline summaries and
# its requests.
run_json() {
  [[ -f "$1/requests.json" ]] || die "no requests.json in $1"
  local file
  for file in "$1"/*.timeline_summary.json; do
    [[ -e "$file" ]] || continue
    jq --arg path "$(basename "$file" .timeline_summary.json)" '{($path): .}' "$file"
  done | jq -s --slurpfile requests "$1/requests.json" \
    '{summaries: (add // {}), requests: $requests[0]}'
}

# gate <run dir>... --env <name> [--budget <file>]: judges one run, or the
# median of several of the same commit on one environment (the nightly
# runs three side by side, as one runner can be a quarter slower than the
# next). Writes result.json and summary.md into the first run directory and
# exits 1 over budget.
cmd_gate() {
  STEP="gate"
  local runs=() env="" budget="$BUDGET"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env) env="${2:?--env needs a name}"; shift 2 ;;
      --budget) budget="${2:?--budget needs a file}"; shift 2 ;;
      -*) die "unknown option $1" ;;
      *) runs+=("$1"); shift ;;
    esac
  done
  [[ ${#runs[@]} -gt 0 ]] || die "gate needs a run directory"
  local out="${runs[0]}" run latency="[]"
  # One run per JSON value, through a file: the pooled frame times of a few
  # runs are more than an argument list holds.
  for run in "${runs[@]}"; do run_json "$run"; done >"$out/runs.json"
  # Measured only where a run measured latency (`perf.sh latency`).
  for run in "${runs[@]}"; do
    if [[ -f "$run/latency.json" ]]; then
      latency="$(jq -s . "$run/latency.json")"
      break
    fi
  done
  yq -o json "$budget" >"$out/budget.json"
  jq -n --slurpfile budget "$out/budget.json" \
    --slurpfile runs "$out/runs.json" \
    --argjson latency "$latency" \
    --arg env "$env" \
    -f "$SCRIPTS_DIR/perf-gate.jq" >"$out/result.json"
  rm -f "$out/budget.json" "$out/runs.json"
  jq -r -f "$SCRIPTS_DIR/perf-summary.jq" "$out/result.json" >"$out/summary.md"
  jq -e '.pass' "$out/result.json" >/dev/null || return 1
}

# baseline <run dir>...: each path's baseline over several runs on one
# environment, as the budget file takes it: the slowest p90 seen, so the
# baseline covers the run-to-run noise and only a real slowdown clears the
# headroom above it.
cmd_baseline() {
  STEP="baseline"
  [[ $# -gt 0 ]] || die "baseline needs one or more run directories"
  local run file
  for run in "$@"; do
    for file in "$run"/*.timeline_summary.json; do
      [[ -e "$file" ]] || die "no timeline summaries in $run"
      jq -c --arg path "$(basename "$file" .timeline_summary.json)" '{path: $path,
        build: ."90th_percentile_frame_build_time_millis",
        raster: ."90th_percentile_frame_rasterizer_time_millis"}' "$file"
    done
  done | jq -s 'group_by(.path) | map({key: .[0].path, value: {
      build_p90_ms: (map(.build) | max),
      raster_p90_ms: (map(.raster) | max),
      measured: {build_p90_ms: map(.build), raster_p90_ms: map(.raster)}}}) | from_entries'
}

# Whatever this command took, given back however it ends: the secrets, the
# account lock and the emulator it booted.
OWN_EMULATOR=0
LOCKED_ACCOUNT=""
SECRETS_DIR=""
cleanup() {
  [[ -n "$SECRETS_DIR" ]] && rm -rf "$SECRETS_DIR"
  [[ -n "$LOCKED_ACCOUNT" ]] && lock_release "$LOCKED_ACCOUNT" "$SESSION"
  if ((OWN_EMULATOR)); then
    emulator_down
  fi
}

perf_main() {
  trap cleanup EXIT
  case "${1:-help}" in
    run) shift; cmd_run "$@" ;;
    latency) shift; cmd_latency "$@" ;;
    gate) shift; cmd_gate "$@" ;;
    baseline) shift; cmd_baseline "$@" ;;
    down) STEP="down"; emulator_down ;;
    help | -h | --help) perf_usage ;;
    *)
      perf_usage >&2
      exit 64
      ;;
  esac
}

# Sourced by its tests, it defines everything and runs nothing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  perf_main "$@"
fi
