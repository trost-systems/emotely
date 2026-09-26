#!/usr/bin/env bash
# Sets the Flutter app up on an iOS simulator against the deployed agent,
# signed in as the smoke account and registered with marionette, so an agent
# can drive it with plain marionette commands; then records, collects the
# evidence bundle and tears it all down. `run-app.sh help` for usage.
#
# Signs in as the smoke account and nobody else (ADR 0005: this repository
# and its attachments are public, so evidence holds made-up content only).
# Secrets are read blind from the agent's .env.local, never printed, never
# written into the bundle, and scrubbed from every text file in it.
#
# Several agent sessions on one machine run this at once, so everything
# machine-wide is named after the session (the simulator, the marionette
# instance), everything per checkout lives in the checkout, and the one
# shared thing, the smoke account, is taken under a lock.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(git -C "$SKILL_DIR" rev-parse --show-toplevel)"
APP_DIR="$REPO/apps/mobile/app"
# A worktree has no .env.local of its own; the main checkout does.
MAIN_CHECKOUT="$(dirname "$(git -C "$SKILL_DIR" rev-parse --path-format=absolute --git-common-dir)")"
ENV_FILE="${EMOTELY_ENV_FILE:-$MAIN_CHECKOUT/apps/agent/.env.local}"
DEVICE_TYPE="${EMOTELY_DEVICE_TYPE:-iPhone 17 Pro}"
# One session per checkout; its state lives in the ignored build directory.
STATE_DIR="$APP_DIR/build/run-app"
STATE_FILE="$STATE_DIR/state"
# Machine-wide locks, shared by every checkout and every clone. Not under
# $TMPDIR: a sandboxed agent session may be given a private one.
LOCK_ROOT="${EMOTELY_RUN_APP_LOCKS:-${XDG_STATE_HOME:-$HOME/.local/state}/emotely/run-app}"
POSTHOG_API="https://eu.posthog.com/api/projects/262464"
# The hosted project, as `lib/app/environment.dart` defaults to it. Both are
# public (ADR 0010); the CLI needs them to learn the smoke user's id, which
# is how it finds this session's PostHog events among everyone else's.
SUPABASE_URL="https://khfkszlujgkfjgnawdlf.supabase.co"
SUPABASE_PUBLISHABLE_KEY="sb_publishable_di6BB76PPuuoDklt7jtI0w_KlwO_8JF"
MARIONETTE_DOCS="https://github.com/leancodepl/marionette_mcp/blob/main/docs/cli.md"
# Posting copies: screenshots 600 px wide (shown at 300, sharp on a 2x
# screen), videos sped up this many times.
POST_WIDTH=600
DEFAULT_SPEED=4

# CocoaPods refuses to run under a non-UTF-8 locale.
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

usage() {
  cat <<EOF
Usage: run-app.sh <command>

  up [options]     Build a debug app, launch it on a fresh simulator against
                   the deployed agent, sign in as the smoke account and
                   register it with marionette. Leaves the app on the
                   signed-in journal and prints the marionette instance and
                   the evidence bundle.
  status           Print the session, instance, device and bundle.
  record start     Start recording the app to <bundle>/video[-N].webm.
  record stop [--speed N]
                   Stop and finalise the recording, and write the copy to
                   post: <bundle>/post/video-Nx.mp4 (H.264, N times faster,
                   default $DEFAULT_SPEED).
  collect [--speed N]
                   Write the app log, the flutter run log, the PostHog events
                   since \`up\` and summary.json into the bundle, scrubbed of
                   the smoke account's credentials, and a ${POST_WIDTH} px wide copy
                   of every screenshot into <bundle>/post/. Stops a running
                   recording first (--speed as for record stop).
  down             Stop the app, unregister it, delete the session's
                   simulator and free the smoke account.
  help             This text, then marionette's reference (help-ai).

Options for up:
  --out <dir>      The evidence bundle.
                   Default: apps/mobile/app/build/evidence/<time>/.
  --skip-build     Reuse apps/mobile/app/build/ios/iphonesimulator/Runner.app.
                   Only a build \`up\` made carries marionette and the smoke
                   account; anything else fails at sign-in.

Between up and down, drive the app with marionette:
  marionette -i <instance> get-interactive-elements
  marionette -i <instance> tap --key journal_view.start
  marionette -i <instance> take-screenshots --output <bundle>/01-journal.png
Match by widget key first (Key('journal_view.start')), visible text second,
never coordinates: a widget without a key gets one. Type made-up content
only: evidence is public.

Parallel sessions: each \`up\` gets its own simulator and instance, named
after the checkout plus a random suffix. One session per checkout, and one
per smoke account at a time: a second \`up\` on the same account fails at
once and names the checkout that holds it (locks in $LOCK_ROOT).

Every command exits non-zero naming the step that failed. SMOKE_EMAIL,
SMOKE_PASSWORD, SMOKE_EMAIL_DOMAINS, POSTHOG_KEY and
POSTHOG_PERSONAL_API_KEY are read from
$ENV_FILE
(EMOTELY_ENV_FILE overrides the path). Bring your own smoke account: an
address whose inbox you (and your agents) can read, and its domain in
SMOKE_EMAIL_DOMAINS (comma-separated). The CLI refuses any address outside
that list, and refuses to run without one.

Marionette: $MARIONETTE_DOCS
EOF
}

# --- output ---------------------------------------------------------------------

STEP="setup"
log() { printf '[%s] %s\n' "$STEP" "$*" >&2; }
die() {
  printf 'run-app: step "%s" failed: %s\n' "$STEP" "$*" >&2
  exit 1
}
step() {
  STEP="$1"
  log "..."
}

# --- state ----------------------------------------------------------------------

# The session's facts, one KEY=value per line; no secrets.
state_get() { sed -n "s/^$1=//p" "$STATE_FILE" 2>/dev/null | tail -1; }
state_set() { printf '%s=%s\n' "$1" "$2" >>"$STATE_FILE"; }
require_session() {
  [[ -f "$STATE_FILE" ]] || die "no session: run \`run-app.sh up\` first"
  SESSION="$(state_get SESSION)"
  INSTANCE="$(state_get INSTANCE)"
  OUT="$(state_get OUT)"
}

# The checkout's directory name plus a random suffix: unique on the machine,
# readable in \`xcrun simctl list\` and \`marionette list\`, and a valid
# marionette instance name ([a-zA-Z0-9_-]+).
new_session_id() {
  local name suffix
  name="$(printf '%s' "$(basename "$1")" | tr -c 'a-zA-Z0-9_-' '-')"
  suffix="$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  printf '%s-%s' "$name" "$suffix"
}

# --- locks ----------------------------------------------------------------------

# A lock is a symlink whose target is its holder's record, one field per
# line: pid, that pid's start time, session, checkout. A symlink is created
# with its content in one atomic step, so nobody reads a half-written lock.
# The holder is alive while its pid runs with the same start time, so a
# crashed session's lock is stale and a reused pid does not revive it.
pid_started() { { ps -o lstart= -p "$1" 2>/dev/null || true; } | sed 's/ *$//'; }
lock_record() { printf '%s\n%s\n%s\n%s' "$1" "$(pid_started "$1")" "$2" "$3"; }
lock_read() { readlink "$1" 2>/dev/null || true; }
# record_field <record> pid|started|session|checkout
record_field() {
  local line
  case "$2" in
    pid) line=1 ;;
    started) line=2 ;;
    session) line=3 ;;
    checkout) line=4 ;;
  esac
  sed -n "${line}p" <<<"$1"
}
lock_field() { record_field "$(lock_read "$1")" "$2"; }
record_alive() {
  local pid started
  pid="$(record_field "$1" pid)"
  started="$(record_field "$1" started)"
  [[ -n "$pid" && -n "$started" && "$(pid_started "$pid")" == "$started" ]]
}

# lock_take <lock> <pid> <session> <checkout>: takes the lock for that pid,
# or returns 1 while a live holder has it.
lock_take() {
  local lock="$1" record stale
  mkdir -p "$(dirname "$lock")"
  record="$(lock_record "$2" "$3" "$4")"
  ln -s "$record" "$lock" 2>/dev/null && return 0
  # One read, both judged and compared below: a second read could already
  # be a new holder's lock.
  stale="$(lock_read "$lock")"
  record_alive "$stale" && return 1
  # Stale. Break it under a mutex, and only while it still holds the record
  # found stale, so of two sessions breaking it at once only one wins. A
  # mutex left by a crash inside these lines expires after a minute.
  find "$lock.break" -maxdepth 0 -mmin +1 -exec rmdir {} \; 2>/dev/null || true
  mkdir "$lock.break" 2>/dev/null || return 1
  [[ "$(lock_read "$lock")" == "$stale" ]] && rm -f "$lock"
  rmdir "$lock.break"
  ln -s "$record" "$lock" 2>/dev/null
}

# lock_handover <lock> <session> <pid>: the session's lock is now held by
# that pid (the long-lived \`flutter run\` instead of the finished \`up\`).
lock_handover() {
  local tmp="$1.$$.tmp"
  [[ "$(lock_field "$1" session)" == "$2" ]] || return 1
  ln -s "$(lock_record "$3" "$2" "$(lock_field "$1" checkout)")" "$tmp"
  mv -f "$tmp" "$1"
}

# lock_release <lock> <session>: frees the lock if that session holds it.
lock_release() {
  if [[ "$(lock_field "$1" session)" == "$2" ]]; then
    rm -f "$1"
  fi
}

# Per account, so the day each run has its own user (#185) runs go parallel.
account_lock() {
  printf '%s/smoke-%s.lock' "$LOCK_ROOT" \
    "$(printf '%s' "$SMOKE_EMAIL" | tr '[:upper:]' '[:lower:]' | shasum -a 256 | cut -c1-12)"
}

# Two sessions on one account collide on its server state (an open session,
# consent), and `collect` could not tell their PostHog events apart.
take_account_lock() {
  local lock
  lock="$(account_lock)"
  lock_take "$lock" "$1" "$SESSION" "$REPO" && return 0
  die "the smoke account is in use by session $(lock_field "$lock" session) in $(lock_field "$lock" checkout) (since $(lock_field "$lock" started)). Wait for its \`run-app.sh down\`, or run that there if the session is abandoned. One smoke account runs one session at a time; parallel runs come with per-run users (#185, #186)."
}

# --- secrets --------------------------------------------------------------------

# Reads KEY's value from the env file without printing it.
env_value() {
  sed -n "s/^$1=//p" "$ENV_FILE" | head -1 | tr -d '\r' | tr -d "\"'"
}

# smoke_domain_allowed <address> <comma-separated domains>: whether the
# address is on one of them, exactly (a subdomain is not the domain).
smoke_domain_allowed() {
  local domain allowed list
  domain="$(printf '%s' "${1##*@}" | tr '[:upper:]' '[:lower:]')"
  IFS=, read -ra list <<<"$2"
  for allowed in ${list[@]+"${list[@]}"}; do
    allowed="$(printf '%s' "$allowed" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
    [[ -n "$allowed" && "$allowed" == "$domain" ]] && return 0
  done
  return 1
}

# Everything secret goes through files in a private directory (mode 700),
# never through the bundle, and away again when the command ends.
PRIVATE_DIR=""
private_dir() {
  PRIVATE_DIR="$(mktemp -d)"
  chmod 700 "$PRIVATE_DIR"
  trap 'rm -rf "$PRIVATE_DIR"' EXIT
}

# The smoke account is the contributor's own: an address whose inbox they
# can read, on a domain they list in SMOKE_EMAIL_DOMAINS.
read_smoke_account() {
  [[ -r "$ENV_FILE" ]] || die "cannot read $ENV_FILE"
  SMOKE_EMAIL="$(env_value SMOKE_EMAIL)"
  SMOKE_PASSWORD="$(env_value SMOKE_PASSWORD)"
  [[ -n "$SMOKE_EMAIL" && -n "$SMOKE_PASSWORD" ]] \
    || die "SMOKE_EMAIL and SMOKE_PASSWORD must be set in $ENV_FILE"
  local domains
  domains="$(env_value SMOKE_EMAIL_DOMAINS)"
  [[ -n "${domains//[, ]/}" ]] \
    || die "SMOKE_EMAIL_DOMAINS is missing or empty in $ENV_FILE: list the domains of the smoke inboxes you control, comma-separated"
  smoke_domain_allowed "$SMOKE_EMAIL" "$domains" \
    || die "SMOKE_EMAIL is not on a domain in SMOKE_EMAIL_DOMAINS; the CLI signs in as your smoke account only"
}

# --- marionette -------------------------------------------------------------------

SESSION=""
INSTANCE=""
OUT=""
m() { marionette -i "$INSTANCE" "$@"; }

# Retries "$@" (quietly) until it succeeds or $1 seconds pass.
retry() {
  local seconds="$1" deadline
  shift
  deadline=$((SECONDS + seconds))
  until "$@" >/dev/null 2>&1; do
    ((SECONDS < deadline)) || return 1
    sleep 1
  done
}

# Whether the widget keyed $1 is on screen. Captured first: under pipefail a
# `grep -q` that stops reading early fails the pipeline through SIGPIPE.
on_screen() {
  local elements
  elements="$(m get-interactive-elements 2>/dev/null)" || return 1
  grep -qF "Key: \"$1\"" <<<"$elements"
}

# --- up -------------------------------------------------------------------------

UDID=""
RUNNER_APP="$APP_DIR/build/ios/iphonesimulator/Runner.app"

preflight() {
  step "preflight"
  local tool
  for tool in fvm xcrun marionette jq yq curl ffmpeg ffprobe plutil shasum; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
  done
  local app_version cli_version
  app_version="$(yq '.packages.marionette_flutter.version' "$REPO/apps/mobile/pubspec.lock")"
  cli_version="$(dart pub global list 2>/dev/null | sed -n 's/^marionette_cli \([0-9.]*\).*/\1/p')"
  [[ "$cli_version" == "$app_version" ]] \
    || die "marionette_cli is ${cli_version:-missing}, the app has marionette_flutter $app_version: dart pub global activate marionette_cli $app_version"
}

# The account, then the checkout: nothing is created until both are free.
claim() {
  step "claim"
  [[ ! -d "$STATE_DIR" ]] \
    || die "a session is already up in this checkout ($(state_get SESSION)): run-app.sh down first"
  read_smoke_account
  SESSION="$(new_session_id "$REPO")"
  INSTANCE="emotely-$SESSION"
  take_account_lock "$$"
  mkdir -p "$(dirname "$STATE_DIR")"
  if ! mkdir "$STATE_DIR" 2>/dev/null; then
    lock_release "$(account_lock)" "$SESSION"
    die "a session is already up in this checkout: run-app.sh down first"
  fi
  : >"$STATE_FILE"
  state_set SESSION "$SESSION"
  state_set INSTANCE "$INSTANCE"
  state_set LOCK "$(account_lock)"
  log "session $SESSION"
}

# The smoke user's id: proves the credentials before a two-minute build,
# and is how `collect` tells this session's PostHog events apart.
check_credentials() {
  step "credentials"
  jq -n --arg email "$SMOKE_EMAIL" --arg key "$(env_value POSTHOG_KEY)" \
    '{SMOKE_EMAIL: $email, POSTHOG_KEY: $key}' >"$PRIVATE_DIR/defines.json"
  jq -n --arg email "$SMOKE_EMAIL" --arg password "$SMOKE_PASSWORD" \
    '{email: $email, password: $password}' >"$PRIVATE_DIR/grant.json"
  printf 'header = "apikey: %s"\n' "$SUPABASE_PUBLISHABLE_KEY" >"$PRIVATE_DIR/supabase.curl"
  local user_id
  user_id="$(curl -sS --fail-with-body -K "$PRIVATE_DIR/supabase.curl" \
    -H 'Content-Type: application/json' --data @"$PRIVATE_DIR/grant.json" \
    "$SUPABASE_URL/auth/v1/token?grant_type=password" | jq -r '.user.id // empty')" \
    || die "the smoke account's password grant failed"
  [[ -n "$user_id" ]] || die "the smoke account's password grant returned no user"
  state_set SMOKE_USER_ID "$user_id"
}

build() {
  step "build"
  if [[ $SKIP_BUILD -eq 1 ]]; then
    [[ -d "$RUNNER_APP" ]] || die "--skip-build, but there is no $RUNNER_APP"
    log "reusing $RUNNER_APP"
    return
  fi
  (cd "$APP_DIR" && bundle check >/dev/null 2>&1) \
    || (cd "$APP_DIR" && bundle config set --local path vendor/bundle >/dev/null && bundle install >/dev/null) \
    || die "bundle install (CocoaPods) failed"
  (cd "$APP_DIR" && fvm flutter build ios --simulator --debug \
    --dart-define-from-file="$PRIVATE_DIR/defines.json") >"$OUT/build.log" 2>&1 \
    || die "flutter build failed; see $OUT/build.log"
}

# A fresh simulator for every session, named after it, so no two sessions
# ever share a device or leave each other's app signed in. `down` deletes it.
simulator() {
  step "simulator"
  local type runtime
  type="$(xcrun simctl list devicetypes -j | jq -r --arg n "$DEVICE_TYPE" '.devicetypes[] | select(.name == $n) | .identifier')"
  [[ -n "$type" ]] || die "no device type \"$DEVICE_TYPE\" (EMOTELY_DEVICE_TYPE)"
  runtime="$(xcrun simctl list runtimes -j | jq -r '[.runtimes[] | select(.platform == "iOS" and .isAvailable)] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')"
  [[ -n "$runtime" ]] || die "no available iOS runtime"
  UDID="$(xcrun simctl create "$INSTANCE" "$type" "$runtime")" || die "could not create a simulator"
  state_set UDID "$UDID"
  xcrun simctl boot "$UDID" || die "could not boot simulator $UDID"
  xcrun simctl bootstatus "$UDID" -b >/dev/null || die "simulator $UDID did not boot"
  log "device $UDID ($INSTANCE)"
}

launch() {
  step "launch"
  local vm_file="$PRIVATE_DIR/vmservice" deadline pid
  state_set BUNDLE_ID "$(plutil -extract CFBundleIdentifier raw "$RUNNER_APP/Info.plist")"
  # Outlives this command: `down` stops it. The VM service and DDS take
  # ports the OS assigns, so parallel sessions never clash on one.
  (cd "$APP_DIR" && exec fvm flutter run -d "$UDID" --debug \
    --use-application-binary="$RUNNER_APP" \
    --dart-define-from-file="$PRIVATE_DIR/defines.json" \
    --vmservice-out-file="$vm_file") </dev/null >"$OUT/flutter-run.log" 2>&1 &
  pid=$!
  state_set RUN_PID "$pid"
  # From here the app holds the account, not this command.
  lock_handover "$(state_get LOCK)" "$SESSION" "$pid" || die "lost the smoke account's lock"
  deadline=$((SECONDS + 240))
  until [[ -s "$vm_file" ]]; do
    kill -0 "$pid" 2>/dev/null || die "flutter run exited; see $OUT/flutter-run.log"
    ((SECONDS < deadline)) || die "no VM service within 240s; see $OUT/flutter-run.log"
    sleep 1
  done
  # Flutter writes the ws:// URI; older releases wrote the http:// one.
  local uri
  uri="$(tr -d '[:space:]' <"$vm_file")"
  case "$uri" in
    ws://*) ;;
    http://*) uri="ws://${uri#http://}" && uri="${uri%/}/ws" ;;
    *) die "unexpected VM service URI in --vmservice-out-file" ;;
  esac
  state_set URI "$uri"
  log "VM service up"
}

# Marionette keeps one file per instance (~/.marionette/instances/<name>.json),
# written atomically, so sessions registering at once do not clash.
register() {
  step "register"
  marionette register "$INSTANCE" "$(state_get URI)" >/dev/null || die "marionette register failed"
  retry 60 m get-interactive-elements || die "marionette cannot reach the app"
}

# Through the app's own screen, which asks a debug build's smoke account for
# its password. Before any recording, and nothing of it reaches the bundle.
sign_in() {
  step "sign-in"
  retry 60 m enter-text --key sign_in_page.email --input "$SMOKE_EMAIL" \
    || die "no email field (a build without SMOKE_EMAIL?)"
  retry 10 m tap --key sign_in_page.send_code || die "could not submit the email"
  retry 20 m enter-text --key sign_in_page.password --input "$SMOKE_PASSWORD" \
    || die "no password step: the build does not name this account (rebuild without --skip-build)"
  retry 10 m tap --key sign_in_page.password_sign_in || die "could not submit the password"
  retry 60 on_screen app_shell.journal || die "not signed in after 60s"
  log "signed in"
}

cmd_up() {
  SKIP_BUILD=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out) OUT="${2:?--out needs a directory}"; shift 2 ;;
      --skip-build) SKIP_BUILD=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  preflight
  claim
  OUT="${OUT:-$APP_DIR/build/evidence/$(date +%Y%m%d-%H%M%S)}"
  mkdir -p "$OUT"
  OUT="$(cd "$OUT" && pwd)"
  state_set OUT "$OUT"
  state_set STARTED_AT "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  private_dir

  # A failed `up` leaves the session for `down` to clean away; the account
  # frees itself, as the lock's holder is gone.
  check_credentials
  build
  simulator
  launch
  register
  sign_in

  STEP="up"
  log "ready: the app is on the signed-in journal"
  cmd_status
}

cmd_status() {
  require_session
  cat <<EOF
session   $SESSION
instance  $INSTANCE
device    $(state_get UDID)
bundle    $OUT
drive     marionette -i $INSTANCE get-interactive-elements
EOF
}

# --- posting copies ---------------------------------------------------------------

valid_speed() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]] || die "--speed takes a whole number from 1 up, not \"$1\""
}

# A screenshot at full size is huge in a pull request: <dir>/post/ gets a
# copy of each, $POST_WIDTH px wide, for <img width="300">.
post_screenshots() {
  local shot
  mkdir -p "$1/post"
  for shot in "$1"/*.png; do
    [[ -e "$shot" ]] || continue
    ffmpeg -loglevel error -y -i "$shot" -vf "scale='min($POST_WIDTH,iw)':-2" \
      "$1/post/$(basename "$shot")" || log "could not scale $shot"
  done
}

# post_video <video> <speed>: <dir>/post/<name>-<speed>x.mp4, H.264 (what
# GitHub recommends for inline playback), no audio, 15 fps, $POST_WIDTH px
# wide, so a few minutes of driving stays well under the 10 MB upload limit.
post_video() {
  local out
  out="$(dirname "$1")/post/$(basename "${1%.*}")-$2x.mp4"
  mkdir -p "$(dirname "$out")"
  ffmpeg -loglevel error -y -i "$1" -an \
    -vf "setpts=PTS/$2,fps=15,scale='min($POST_WIDTH,iw)':-2" \
    -c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p -movflags +faststart "$out" \
    || { log "could not write $out"; return 1; }
  log "posting copy $out"
}

# --- record ---------------------------------------------------------------------

record_start() {
  STEP="record"
  require_session
  local pid file n=1
  pid="$(state_get VIDEO_PID)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    die "already recording to $(state_get VIDEO_FILE)"
  fi
  file="$OUT/video.webm"
  while [[ -e "$file" ]]; do
    n=$((n + 1))
    file="$OUT/video-$n.webm"
  done
  # Outlives this command: `record stop` ends it.
  marionette -i "$INSTANCE" record-video --output "$file" >"$STATE_DIR/video.log" 2>&1 &
  pid=$!
  sleep 2
  kill -0 "$pid" 2>/dev/null || die "record-video exited: $(cat "$STATE_DIR/video.log")"
  state_set VIDEO_PID "$pid"
  state_set VIDEO_FILE "$file"
  log "recording to $file"
}

# record_stop <speed>
record_stop() {
  STEP="record"
  require_session
  local pid deadline
  pid="$(state_get VIDEO_PID)"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    log "not recording"
    return
  fi
  # The recorder finalises the file on SIGINT. `marionette` is a pub wrapper
  # script that does not exec, so the signal goes to its child, the Dart VM;
  # the wrapper then exits with it.
  pkill -INT -P "$pid" 2>/dev/null || kill -INT "$pid" 2>/dev/null
  deadline=$((SECONDS + 30))
  while kill -0 "$pid" 2>/dev/null && ((SECONDS < deadline)); do
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    log "the recorder did not stop on SIGINT; the video may be cut short"
    pkill -KILL -P "$pid" 2>/dev/null || true
    kill -KILL "$pid" 2>/dev/null || true
  fi
  state_set VIDEO_PID ""
  log "saved $(state_get VIDEO_FILE)"
  post_video "$(state_get VIDEO_FILE)" "$1"
}

# Parses [--speed N] into SPEED.
parse_speed() {
  SPEED="$DEFAULT_SPEED"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --speed) SPEED="${2:?--speed needs a number}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  valid_speed "$SPEED"
}

cmd_record() {
  local action="${1:-}"
  shift || true
  case "$action" in
    start) record_start ;;
    stop) parse_speed "$@" && record_stop "$SPEED" ;;
    *) die "record start|stop [--speed N]" ;;
  esac
}

# --- collect --------------------------------------------------------------------

# Replaces the smoke account's address, password and user id in every text
# file of the bundle, whatever wrote them.
scrub_bundle() {
  local file content user_id
  user_id="$(state_get SMOKE_USER_ID)"
  while IFS= read -r -d '' file; do
    content="$(<"$file")"
    content="${content//"$SMOKE_PASSWORD"/[smoke password]}"
    content="${content//"$SMOKE_EMAIL"/[smoke account]}"
    [[ -n "$user_id" ]] && content="${content//"$user_id"/[smoke user id]}"
    printf '%s\n' "$content" >"$file"
  done < <(find "$OUT" -type f \( -name '*.log' -o -name '*.json' -o -name '*.txt' \) -print0)
}

cmd_collect() {
  STEP="collect"
  parse_speed "$@"
  require_session
  read_smoke_account
  private_dir
  record_stop "$SPEED" || log "the recording has no posting copy"
  STEP="collect"
  m get-logs >"$OUT/app.log" 2>&1 || log "get-logs failed"
  post_screenshots "$OUT"

  # PostHog flushes on a timer or when the app goes to the background.
  local udid bundle_id started user_id
  udid="$(state_get UDID)"
  bundle_id="$(state_get BUNDLE_ID)"
  started="$(state_get STARTED_AT)"
  user_id="$(state_get SMOKE_USER_ID)"
  printf 'header = "Authorization: Bearer %s"\n' "$(env_value POSTHOG_PERSONAL_API_KEY)" \
    >"$PRIVATE_DIR/posthog.curl"
  xcrun simctl launch "$udid" com.apple.Preferences >/dev/null 2>&1 || true
  local deadline previous=-1 count=0 events=""
  deadline=$((SECONDS + 150))
  while ((SECONDS < deadline)); do
    sleep 15
    events="$(curl -sS --fail -K "$PRIVATE_DIR/posthog.curl" \
      "$POSTHOG_API/events/?distinct_id=$user_id&after=$started&limit=500")" || continue
    count="$(jq '.results | length' <<<"$events")"
    # Settled: something arrived and nothing more since the last look.
    if ((count > 0 && count == previous)); then
      break
    fi
    previous=$count
  done
  # Back to the app, where the agent left it.
  xcrun simctl launch "$udid" "$bundle_id" >/dev/null 2>&1 || true
  # Ids, types, counts and status codes only (ADR 0005); PostHog's own `$`
  # properties (IP, geo, device) stay out of a public bundle.
  jq '[.results // [] | .[] | {event, timestamp,
        properties: (.properties | with_entries(select(.key | startswith("$") | not)))}]
      | sort_by(.timestamp)' <<<"${events:-"{}"}" >"$OUT/posthog-events.json"
  log "$(jq length "$OUT/posthog-events.json") PostHog event(s)"

  jq -n --arg session "$SESSION" --arg started "$started" \
    --arg collected "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg commit "$(git -C "$REPO" rev-parse --short HEAD)" --arg device "$udid" \
    --argjson files "$(cd "$OUT" && find . -type f ! -name summary.json | sed 's|^\./||' | sort | jq -R . | jq -s .)" \
    '{session: $session, started: $started, collected: $collected, commit: $commit, device: $device, files: $files}' \
    >"$OUT/summary.json"
  scrub_bundle
  printf 'run-app: evidence in %s (copies to post in %s/post)\n' "$OUT" "$OUT" >&2
}

# --- down -----------------------------------------------------------------------

cmd_down() {
  STEP="down"
  [[ -d "$STATE_DIR" ]] || {
    log "no session"
    return
  }
  SESSION="$(state_get SESSION)"
  INSTANCE="$(state_get INSTANCE)"
  OUT="$(state_get OUT)"
  set +e
  [[ -n "$OUT" ]] && record_stop "$DEFAULT_SPEED"
  STEP="down"
  [[ -n "$INSTANCE" ]] && marionette unregister "$INSTANCE" >/dev/null 2>&1
  local pid udid lock
  pid="$(state_get RUN_PID)"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null
  fi
  udid="$(state_get UDID)"
  if [[ -n "$udid" ]]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1
    xcrun simctl delete "$udid" >/dev/null 2>&1
    log "deleted simulator $udid"
  fi
  lock="$(state_get LOCK)"
  [[ -n "$lock" ]] && lock_release "$lock" "$SESSION"
  rm -rf "$STATE_DIR"
  set -e
  log "down; the bundle stays in ${OUT:-(none)}"
}

main() {
  case "${1:-help}" in
    up) shift; cmd_up "$@" ;;
    status) cmd_status ;;
    record) shift; cmd_record "$@" ;;
    collect) shift; cmd_collect "$@" ;;
    down) cmd_down ;;
    help | -h | --help)
      usage
      printf '\n---\n\n'
      marionette help-ai 2>/dev/null || printf 'marionette is not installed: dart pub global activate marionette_cli\n'
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
}

# Sourced by run-app.test.sh, which calls the functions itself.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
