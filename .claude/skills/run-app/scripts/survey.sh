#!/usr/bin/env bash
# The performance survey (#242): every screen of the feature map walked in
# profile mode on real phones in Firebase Test Lab, each run's numbers kept
# in a history, and findings filed as one issue per screen and metric, by
# severity. `survey.sh help` for usage; the reference is
# .claude/skills/run-app/references/performance-survey.md.
#
# The walk is apps/mobile/app/integration_test/survey_test.dart; what it
# walks, where and how findings are judged is
# apps/mobile/app/integration_test/survey.yaml.
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPTS_DIR" rev-parse --show-toplevel)"
APP_DIR="$REPO/apps/mobile/app"
CONFIG="$APP_DIR/integration_test/survey.yaml"
# The data branch that holds the history, one record per line.
HISTORY_BRANCH="perf-survey"
HISTORY_FILE="survey.jsonl"
# Where the walk leaves survey.json on the device (survey_test.dart), and
# so where Test Lab pulls it from.
ANDROID_PULL="/sdcard/Android/data/de.emotely.emotely/files/survey"
IOS_PULL="de.emotely.emotely:/Documents/survey"

STEP="setup"
log() { printf '[%s] %s\n' "$STEP" "$*" >&2; }
die() {
  printf 'survey: step "%s" failed: %s\n' "$STEP" "$*" >&2
  exit 2
}

usage() {
  cat <<'EOF'
Usage: survey.sh <command>

Measure:
  ftl --device <device> [--screens a,b] [--out <dir>] [--app <apk> --test <apk> | --zip <zip>]
                   Build the survey (unless given the build), run it on one
                   Test Lab device, pull survey.json back and turn it into
                   history records (<out>/records.jsonl), then judge them
                   against the history and print the findings. <device> is a
                   key of survey.yaml's devices or <model>:<version> (Test
                   Lab ids). One physical device is one of the project's 5
                   physical test runs a day (10 virtual), shared with
                   every other run: use them on purpose.
  local --device <adb id> [--screens a,b] [--out <dir>]
                   The same walk on a phone or emulator attached here,
                   through flutter drive.
  build android|ios [--screens a,b] [--out <dir>] [--profile <.mobileprovision>]
                   Only build: app.apk and test.apk, or survey-ios.zip,
                   signed with the certificate the App Store profile names
                   (match's; SURVEY_PROFILE, see the reference).

Judge and keep:
  record <survey.json> --device <device> [--screens a,b] [--run id] [--at time]
         [--commit sha] [--source name] [--form physical|virtual] [--platform p]
                   One run's history records, one JSON object per line.
  from-log <device log>
                   survey.json put back together from the chunks the walk
                   logs, for a run whose file Test Lab did not pull (ftl
                   falls back to it by itself).
  classify <records.jsonl> [--history <file>]
                   The run's findings by severity, as JSON. Without
                   --history, against the history branch.
  issues <findings.json> [--run-url url] [--tag text]
                   File each finding as an issue, or update the open one of
                   the same screen and metric (a comment, and the title when
                   the severity changed). --tag keeps test issues apart.
  append <records.jsonl>
                   Add the records to the history (the perf-survey branch).
  history [--device d] [--screen s] [--days n] [--json] [--from file]
                   The history, narrowed: e.g. the journal on the Galaxy A14
                   over the last 30 days:
                     survey.sh history --device a14m --screen journal
  plan             The devices a full survey runs (survey.yaml's
                   `default: true`), as a JSON list.

Options everywhere: --config <file> instead of survey.yaml.
EOF
}

# --- config -----------------------------------------------------------------------

config_json() { yq -o json "$1"; }

# The survey.yaml entry of a device given as a key or <model>:<version>, as
# JSON, or nothing.
device_entry() {
  config_json "$1" | jq -c --arg device "$2" '.devices | to_entries
    | map(select(.key == $device or "\(.value.model):\(.value.version)" == $device))
    | .[0] // empty | {key} + .value'
}

# --- gcloud -----------------------------------------------------------------------

# gcloud for emotely only ever runs with its own configuration: on a
# maintainer's machine the default one belongs to another organization. In
# CI, google-github-actions/auth signs in keylessly instead.
gcloud_emotely() {
  if [[ -z "${CLOUDSDK_CONFIG:-}" && -z "${GITHUB_ACTIONS:-}" ]]; then
    [[ -d "$HOME/.config/emotely/gcloud" ]] ||
      die "no gcloud configuration for emotely: set CLOUDSDK_CONFIG (never use the default one)"
    CLOUDSDK_CONFIG="$HOME/.config/emotely/gcloud" gcloud "$@"
  else
    gcloud "$@"
  fi
}

ftl_project() { printf '%s' "${FTL_PROJECT_ID:-emotely-ci}"; }

# --- build ------------------------------------------------------------------------

flutter_cmd() {
  if command -v fvm >/dev/null; then
    printf 'fvm flutter'
  else
    printf 'flutter'
  fi
}

# build android <out> <screens>: the profile build of the walk, and the
# instrumentation APK that runs it on a device with no host attached.
build_android() {
  STEP="build"
  local out="$1" screens="$2" flutter define defines=() gradle_defines=()
  read -r -a flutter <<<"$(flutter_cmd)"
  for define in SURVEY_ON_DEVICE=true ${screens:+"SURVEY_SCREENS=$screens"}; do
    defines+=(--dart-define="$define")
    # Gradle takes them base64-encoded, comma-separated.
    gradle_defines+=("$(printf '%s' "$define" | base64 | tr -d '\n')")
  done
  mkdir -p "$out"
  log "profile build of the walk (a few minutes)"
  (cd "$APP_DIR" && "${flutter[@]}" build apk --profile \
    --target=integration_test/survey_test.dart "${defines[@]}") >"$out/build.log" 2>&1 ||
    die "flutter build apk failed; see $out/build.log"
  cp "$APP_DIR/build/app/outputs/flutter-apk/app-profile.apk" "$out/app.apk"
  log "the instrumentation APK"
  (cd "$APP_DIR/android" && ./gradlew --quiet app:assembleAndroidTest -PtestBuildType=profile \
    -Ptarget="$APP_DIR/integration_test/survey_test.dart" \
    -Pdart-defines="$(IFS=,; printf '%s' "${gradle_defines[*]}")") \
    >>"$out/build.log" 2>&1 || die "gradle assembleAndroidTest failed; see $out/build.log"
  cp "$APP_DIR/build/app/outputs/apk/androidTest/profile/app-profile-androidTest.apk" "$out/test.apk"
}

# build ios <out> <screens> <profile>: the XCTest bundle Test Lab runs on
# an iPhone: a profile build of the walk and its RunnerTests for devices,
# signed (sign_ios) and zipped with its .xctestrun.
build_ios() {
  STEP="build"
  local out="$1" screens="$2" profile="$3" flutter defines=(--dart-define=SURVEY_ON_DEVICE=true) derived
  [[ -f "$profile" ]] || die "build ios needs --profile <.mobileprovision> (or SURVEY_PROFILE): see the reference"
  read -r -a flutter <<<"$(flutter_cmd)"
  [[ -n "$screens" ]] && defines+=(--dart-define="SURVEY_SCREENS=$screens")
  mkdir -p "$out"
  derived="$APP_DIR/build/ios_survey"
  rm -rf "$derived/Build/Products"
  log "profile build of the walk for iOS"
  # CocoaPods fails under a locale that is not UTF-8.
  (cd "$APP_DIR" && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 "${flutter[@]}" build ios --profile --config-only \
    --target=integration_test/survey_test.dart "${defines[@]}") >"$out/build.log" 2>&1 ||
    die "flutter build ios --config-only failed; see $out/build.log"
  # Built unsigned, then signed below: signing settings passed to xcodebuild
  # would reach every Pods target too, and the project's own stay automatic
  # for local development.
  (cd "$APP_DIR/ios" && xcodebuild build-for-testing -workspace Runner.xcworkspace -scheme Runner \
    -configuration Profile -sdk iphoneos -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO) \
    >>"$out/build.log" 2>&1 || die "xcodebuild build-for-testing failed; see $out/build.log"
  sign_ios "$derived/Build/Products/Profile-iphoneos/Runner.app" "$profile"
  (cd "$derived/Build/Products" && rm -f survey-ios.zip &&
    zip -qry survey-ios.zip Profile-iphoneos ./*.xctestrun) || die "could not zip the XCTest bundle"
  cp "$derived/Build/Products/survey-ios.zip" "$out/survey-ios.zip"
}

# sign_ios <Runner.app> <profile>: signs the app, its frameworks and its
# test bundle with the profile's certificate, as Test Lab requires ("all
# artifacts in the app and test are signed"; it re-signs them with its
# own). The profile is match's App Store one: Test Lab needs no development
# profile or registered device. The identity is the keychain's certificate
# that the profile names, by fingerprint, since a keychain can hold two of
# the same name.
sign_ios() {
  STEP="sign"
  local app="$1" profile="$2" tmp identity="" i sha
  tmp="$(mktemp -d)"
  security cms -D -i "$profile" >"$tmp/profile.plist" || die "could not read $profile"
  for ((i = 0; ; i++)); do
    plutil -extract "DeveloperCertificates.$i" raw "$tmp/profile.plist" >"$tmp/cert.b64" 2>/dev/null || break
    sha="$(base64 -D -i "$tmp/cert.b64" | openssl x509 -inform der -noout -fingerprint -sha1 |
      sed 's/.*=//; s/://g')"
    if security find-identity -v -p codesigning | grep -q "$sha"; then
      identity="$sha"
      break
    fi
  done
  [[ -n "$identity" ]] || die "the keychain has no certificate that $profile names"
  plutil -extract Entitlements xml1 -o "$tmp/entitlements.plist" "$tmp/profile.plist"
  cp "$profile" "$app/embedded.mobileprovision"
  # Inside out: whatever is nested is signed before what contains it.
  find "$app/Frameworks" "$app/PlugIns" -depth \( -name '*.framework' -o -name '*.dylib' -o -name '*.xctest' \) \
    -print0 2>/dev/null | while IFS= read -r -d '' bundle; do
    codesign --force --sign "$identity" --timestamp=none "$bundle" >/dev/null 2>&1 ||
      die "could not sign $bundle"
  done
  codesign --force --sign "$identity" --timestamp=none --entitlements "$tmp/entitlements.plist" "$app" \
    >/dev/null 2>&1 || die "could not sign $app"
  codesign --verify --deep "$app" || die "$app does not verify"
  rm -rf "$tmp"
}

# --- run on Test Lab --------------------------------------------------------------

# ftl_run <platform> <model> <version> <out> <build args...>: one Test Lab
# test run, then survey.json pulled from its results into <out>.
ftl_run() {
  STEP="ftl"
  local platform="$1" model="$2" version="$3" out="$4" results_dir status=0 bucket
  shift 4
  results_dir="survey/$(date -u +%Y%m%dT%H%M%SZ)-$model-$version-$(od -An -N3 -tx1 /dev/urandom | tr -d ' \n')"
  local common=(
    --device "model=$model,version=$version,locale=en,orientation=portrait"
    --timeout 20m
    --results-dir "$results_dir"
    --client-details "matrixLabel=perf-survey"
    --project "$(ftl_project)"
    --format json
  )
  log "Test Lab: $model $version (results in $results_dir)"
  if [[ "$platform" == ios ]]; then
    # --directories-to-pull is a beta flag for iOS.
    gcloud_emotely beta firebase test ios run --test "$1" "${common[@]}" \
      --directories-to-pull "$IOS_PULL" >"$out/ftl.json" 2>"$out/ftl.log" || status=$?
  else
    # No video and no sampled performance metrics: both take the phone's
    # time from the frames being measured.
    gcloud_emotely firebase test android run --type instrumentation --app "$1" --test "$2" \
      "${common[@]}" --no-record-video --no-performance-metrics --no-auto-google-login \
      --directories-to-pull "$ANDROID_PULL" >"$out/ftl.json" 2>"$out/ftl.log" || status=$?
  fi
  bucket="$(sed -n 's#.*storage/browser/\([^/]*\)/.*#\1#p' "$out/ftl.log" | head -1)"
  printf '%s\n' "gs://$bucket/$results_dir" >"$out/results.txt"
  ((status == 0)) || die "the Test Lab run failed (exit $status): see $out/ftl.log and the results in gs://$bucket/$results_dir"
  [[ -n "$bucket" ]] || die "no results bucket in $out/ftl.log"
  local listing found device_log
  listing="$(gcloud_emotely storage ls --recursive "gs://$bucket/$results_dir/**" 2>/dev/null)" || true
  found="$(grep '/survey\.json$' <<<"$listing" | head -1)" || true
  if [[ -n "$found" ]]; then
    gcloud_emotely storage cp "$found" "$out/survey.json" >/dev/null 2>&1 ||
      die "could not download $found"
    return
  fi
  # Test Lab left the file on the device (an iPhone's Documents were never
  # pulled back in the runs so far): the walk logged it too.
  device_log="$(grep -E '/(syslog\.txt|logcat)$' <<<"$listing" | head -1)" || true
  [[ -n "$device_log" ]] ||
    die "the run left neither survey.json nor a device log in gs://$bucket/$results_dir"
  gcloud_emotely storage cp "$device_log" "$out/device.log" >/dev/null 2>&1 ||
    die "could not download $device_log"
  log "no survey.json pulled; reading it from the device log"
  cmd_from_log "$out/device.log" >"$out/survey.json"
}

cmd_ftl() {
  local device="" screens="" out="" app="" test="" zip="" config="$CONFIG" source="adhoc" judge=1
  local profile="${SURVEY_PROFILE:-}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device) device="${2:?}"; shift 2 ;;
      --screens) screens="${2-}"; shift 2 ;;
      --out) out="${2:?}"; shift 2 ;;
      --app) app="${2:?}"; shift 2 ;;
      --test) test="${2:?}"; shift 2 ;;
      --zip) zip="${2:?}"; shift 2 ;;
      --profile) profile="${2:?}"; shift 2 ;;
      --config) config="${2:?}"; shift 2 ;;
      --source) source="${2:?}"; shift 2 ;;
      --no-judge) judge=0; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  [[ -n "$device" ]] || die "ftl needs --device (a key of survey.yaml's devices, or <model>:<version>)"
  local entry platform model version form
  entry="$(device_entry "$config" "$device")"
  if [[ -n "$entry" ]]; then
    platform="$(jq -r .platform <<<"$entry")"
    model="$(jq -r .model <<<"$entry")"
    version="$(jq -r .version <<<"$entry")"
    form="$(jq -r .form <<<"$entry")"
  else
    model="${device%%:*}"
    version="${device#*:}"
    [[ "$model" != "$device" ]] || die "an unlisted device is <model>:<version>, e.g. SC-51E:36"
    platform=android
    if gcloud_emotely firebase test ios models describe "$model" --format='value(id)' >/dev/null 2>&1; then
      platform=ios
    fi
    form="$(gcloud_emotely firebase test "$platform" models describe "$model" --format='value(form)' |
      tr '[:upper:]' '[:lower:]')"
  fi
  out="${out:-$APP_DIR/build/survey/$(date +%Y%m%d-%H%M%S)-$model-$version}"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  if [[ "$platform" == ios ]]; then
    if [[ -z "$zip" ]]; then
      build_ios "$out" "$screens" "$profile"
      zip="$out/survey-ios.zip"
    fi
    ftl_run ios "$model" "$version" "$out" "$zip"
  else
    if [[ -z "$app" || -z "$test" ]]; then
      build_android "$out" "$screens"
      app="$out/app.apk"
      test="$out/test.apk"
    fi
    ftl_run android "$model" "$version" "$out" "$app" "$test"
  fi
  record_run "$out" "$config" "$model:$version" "$screens" "$source" --form "$form" --platform "$platform"
  if ((judge)); then
    judge_run "$out" "$config"
  fi
}

# --- run here ---------------------------------------------------------------------

cmd_local() {
  local device="" screens="" out="" config="$CONFIG" flutter defines=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device) device="${2:?}"; shift 2 ;;
      --screens) screens="${2-}"; shift 2 ;;
      --out) out="${2:?}"; shift 2 ;;
      --config) config="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  [[ -n "$device" ]] || die "local needs --device (fvm flutter devices)"
  read -r -a flutter <<<"$(flutter_cmd)"
  [[ -n "$screens" ]] && defines=(--dart-define="SURVEY_SCREENS=$screens")
  out="${out:-$APP_DIR/build/survey/$(date +%Y%m%d-%H%M%S)-local}"
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  STEP="drive"
  log "profile build and the walk on $device (a few minutes)"
  (cd "$APP_DIR" && PERF_OUT="$out" "${flutter[@]}" drive --profile --no-dds -d "$device" \
    --driver=test_driver/survey_driver.dart --target=integration_test/survey_test.dart \
    ${defines[@]+"${defines[@]}"}) >"$out/drive.log" 2>&1 || die "the walk failed; see $out/drive.log"
  local form=physical model version
  [[ "$device" == emulator-* ]] && form=virtual
  model="$(adb -s "$device" shell getprop ro.product.model 2>/dev/null | tr -d '\r' | tr ' ' '-')" || true
  version="$(adb -s "$device" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')" || true
  record_run "$out" "$config" "${model:-$device}:${version:-local}" "$screens" local --form "$form"
  judge_run "$out" "$config"
}

# record_run <out> <config> <device> <screens> <source> [record args]:
# <out>/survey.json into <out>/records.jsonl, and the run's table.
record_run() {
  local out="$1" config="$2" device="$3" screens="$4" source="$5"
  shift 5
  cmd_record "$out/survey.json" --config "$config" --device "$device" --source "$source" \
    ${screens:+--screens "$screens"} "$@" >"$out/records.jsonl"
  cmd_history --from "$out/records.jsonl" --days 36500
}

# judge_run <out> <config>: the run's findings against the history.
judge_run() {
  local out="$1" config="$2"
  STEP="judge"
  if cmd_classify "$out/records.jsonl" --config "$config" >"$out/findings.json" 2>"$out/judge.log"; then
    printf '\n%s finding(s): %s\n' "$(jq length "$out/findings.json")" \
      "$(jq -r 'map("\(.severity) \(.key)") | join(", ")' "$out/findings.json")" >&2
  else
    log "could not judge against the history: $(cat "$out/judge.log")"
  fi
  printf 'survey: run in %s\n' "$out" >&2
}

# from-log <device log>: survey.json put back together from the chunks the
# walk logs (`survey.json <i>/<n> |<chunk>|`, survey_test.dart), for a run
# whose file Test Lab did not pull. Fails unless every chunk is there and
# the whole is JSON.
cmd_from_log() {
  STEP="from-log"
  local log="${1:?from-log needs a device log}" chunks total count
  # `flutter: ` in an iPhone's syslog, `flutter : ` in logcat.
  chunks="$(sed -n 's/.*flutter *: survey\.json \([0-9][0-9]*\)\/\([0-9][0-9]*\) |\(.*\)|$/\1 \2 \3/p' "$log" |
    sort -n -k1,1 -u)"
  [[ -n "$chunks" ]] || die "no survey.json in $log"
  total="$(head -1 <<<"$chunks" | cut -d' ' -f2)"
  count="$(wc -l <<<"$chunks" | tr -d ' ')"
  [[ "$count" == "$total" && "$(tail -1 <<<"$chunks" | cut -d' ' -f1)" == "$total" ]] ||
    die "$log holds $count of survey.json's $total chunks"
  local json
  json="$(cut -d' ' -f3- <<<"$chunks" | tr -d '\n')"
  jq -e . <<<"$json" >/dev/null 2>&1 || die "survey.json from $log is not JSON"
  printf '%s\n' "$json"
}

# --- record, classify, issues -----------------------------------------------------

cmd_record() {
  STEP="record"
  local file="${1:?record needs a survey.json}" config="$CONFIG" device="" screens="null"
  local run="" at="" commit="" source="adhoc" form="physical" platform="android"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config) config="${2:?}"; shift 2 ;;
      --device) device="${2:?}"; shift 2 ;;
      --screens) screens="$(jq -cn --arg s "${2:?}" '$s | split(",") | map(select(. != ""))')"; shift 2 ;;
      --run) run="${2:?}"; shift 2 ;;
      --at) at="${2:?}"; shift 2 ;;
      --commit) commit="${2:?}"; shift 2 ;;
      --source) source="${2:?}"; shift 2 ;;
      --form) form="${2:?}"; shift 2 ;;
      --platform) platform="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  [[ -n "$device" ]] || die "record needs --device"
  [[ -f "$file" ]] || die "no $file"
  at="${at:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  commit="${commit:-$(git -C "$REPO" rev-parse --short HEAD)}"
  run="${run:-${GITHUB_RUN_ID:-local}-$(date -u +%Y%m%dT%H%M%SZ)-$device}"
  local cfg
  cfg="$(mktemp)"
  config_json "$config" >"$cfg"
  local status=0
  jq -c --slurpfile config "$cfg" --arg device "$device" --arg form "$form" \
    --arg platform "$platform" --argjson screens "$screens" --arg run "$run" --arg at "$at" \
    --arg commit "$commit" --arg source "$source" -f "$SCRIPTS_DIR/survey-record.jq" "$file" || status=$?
  rm -f "$cfg"
  ((status == 0)) || die "could not record $file"
}

cmd_classify() {
  STEP="classify"
  local records="${1:?classify needs records}" history="" config="$CONFIG"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --history) history="${2:?}"; shift 2 ;;
      --config) config="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  local tmp status=0
  tmp="$(mktemp -d)"
  config_json "$config" >"$tmp/config.json"
  if [[ -z "$history" ]]; then
    history_source >"$tmp/history.jsonl" || die "could not read the history"
    history="$tmp/history.jsonl"
  fi
  jq -n --slurpfile records "$records" --slurpfile history "$history" \
    --slurpfile config "$tmp/config.json" -f "$SCRIPTS_DIR/survey-classify.jq" || status=$?
  rm -rf "$tmp"
  ((status == 0)) || die "could not classify $records"
}

# issues <findings.json>: each finding as the one open issue of its screen
# and metric. The name after the severity identifies it: an open issue of
# that name is updated (a comment with the run's numbers, and the title
# when the severity changed); without one, a new issue is filed. No labels.
cmd_issues() {
  STEP="issues"
  local findings="${1:?issues needs findings}" tag="" run_url=""
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag) tag="${2:?}"; shift 2 ;;
      --run-url) run_url="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  run_url="${run_url:-${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-trost-systems/emotely}/actions/runs/${GITHUB_RUN_ID:-local}}"
  local open tmp count i issue name title number current
  open="$(gh issue list --state open --limit 1000 --json number,title)" || die "could not list the open issues"
  tmp="$(mktemp -d)"
  count="$(jq length "$findings")"
  for ((i = 0; i < count; i++)); do
    issue="$(jq --argjson i "$i" '.[$i]' "$findings" |
      jq --arg tag "$tag" --arg run_url "$run_url" -f "$SCRIPTS_DIR/survey-issue.jq")"
    name="$(jq -r .name <<<"$issue")"
    title="$(jq -r .title <<<"$issue")"
    jq -r .body <<<"$issue" >"$tmp/body.md"
    jq -r .comment <<<"$issue" >"$tmp/comment.md"
    number="$(jq -r --arg name "$name" \
      'map(select((.title | sub("^\\[(critical|major|minor)\\] "; "")) == $name)) | .[0].number // empty' <<<"$open")"
    if [[ -n "$number" ]]; then
      current="$(jq -r --argjson n "$number" 'map(select(.number == $n)) | .[0].title' <<<"$open")"
      if [[ "$current" != "$title" ]]; then
        gh issue edit "$number" --title "$title" >/dev/null || die "could not retitle #$number"
      fi
      gh issue comment "$number" --body-file "$tmp/comment.md" >/dev/null || die "could not comment on #$number"
      log "updated #$number: $title"
    else
      gh issue create --title "$title" --body-file "$tmp/body.md" >"$tmp/created" ||
        die "could not file $title"
      log "filed $(cat "$tmp/created"): $title"
    fi
  done
  rm -rf "$tmp"
}

# --- history ----------------------------------------------------------------------

repo_name() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s' "$GITHUB_REPOSITORY"
  else
    gh repo view --json nameWithOwner --jq .nameWithOwner
  fi
}

# The whole history, one record per line (nothing before the first run).
history_source() {
  local repo
  repo="$(repo_name)"
  gh api -H 'Accept: application/vnd.github.raw+json' \
    "repos/$repo/contents/$HISTORY_FILE?ref=$HISTORY_BRANCH" 2>/dev/null || true
}

cmd_history() {
  STEP="history"
  local device="" screen="" days=30 json=false from=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device) device="${2:?}"; shift 2 ;;
      --screen) screen="${2:?}"; shift 2 ;;
      --days) days="${2:?}"; shift 2 ;;
      --json) json=true; shift ;;
      --from) from="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  local query=(jq -r -s --arg device "$device" --arg screen "$screen" --argjson days "$days"
    --arg now "${SURVEY_NOW:-}" --argjson json "$json" -f "$SCRIPTS_DIR/survey-history.jq")
  if [[ -n "$from" ]]; then
    "${query[@]}" "$from"
  else
    history_source | "${query[@]}"
  fi | if [[ "$json" == false ]] && command -v column >/dev/null; then column -t -s $'\t'; else cat; fi
}

# append <records.jsonl>: the records added to the history branch, as one
# commit through the API (no checkout). The branch holds the history and a
# vercel.json per Vercel project root, as the status branch does
# (app-release.yml), so that pushing it deploys nothing. A push that lost a
# race with another run's is retried on the new head.
cmd_append() {
  STEP="append"
  local records="${1:?append needs records}" repo attempt head tmp tree commit
  repo="$(repo_name)"
  tmp="$(mktemp -d)"
  for attempt in 1 2 3 4 5; do
    head="$(gh api "repos/$repo/git/matching-refs/heads/$HISTORY_BRANCH" \
      --jq ".[] | select(.ref == \"refs/heads/$HISTORY_BRANCH\") | .object.sha")"
    : >"$tmp/history.jsonl"
    if [[ -n "$head" ]]; then
      gh api -H 'Accept: application/vnd.github.raw+json' \
        "repos/$repo/contents/$HISTORY_FILE?ref=$head" >"$tmp/history.jsonl" 2>/dev/null || : >"$tmp/history.jsonl"
    fi
    cat "$records" >>"$tmp/history.jsonl"
    tree="$(jq -n --rawfile content "$tmp/history.jsonl" --arg file "$HISTORY_FILE" '
      {tree: (
        [{path: $file, mode: "100644", type: "blob", content: $content}] +
        (["apps/agent", "apps/web"] | map({
          path: "\(.)/vercel.json", mode: "100644", type: "blob",
          content: "{\"git\":{\"deploymentEnabled\":false}}\n"
        }))
      )}' | gh api "repos/$repo/git/trees" --input - --jq .sha)"
    commit="$(jq -n --arg tree "$tree" --arg head "$head" \
      --arg message "survey: $(jq -s -r 'map("\(.device.model):\(.device.version)") | unique | join(", ")' "$records") (run ${GITHUB_RUN_ID:-local})" \
      '{message: $message, tree: $tree, parents: [$head | select(. != "")]}' |
      gh api "repos/$repo/git/commits" --input - --jq .sha)"
    if [[ -n "$head" ]]; then
      gh api --method PATCH "repos/$repo/git/refs/heads/$HISTORY_BRANCH" \
        -f sha="$commit" -F force=false >/dev/null 2>&1 && break
    else
      gh api "repos/$repo/git/refs" -f ref="refs/heads/$HISTORY_BRANCH" -f sha="$commit" >/dev/null 2>&1 && break
    fi
    log "the history moved under this run (attempt $attempt); again on the new head"
    ((attempt < 5)) || die "could not append to $HISTORY_BRANCH"
    sleep $((attempt * 2))
  done
  rm -rf "$tmp"
  log "$(wc -l <"$records" | tr -d ' ') record(s) added to $HISTORY_BRANCH"
}

# plan: the devices a full survey runs (survey.yaml's `default: true`), as
# a JSON list of survey.yaml's entries (with their key).
cmd_plan() {
  local config="$CONFIG"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config) config="${2:?}"; shift 2 ;;
      *) die "unknown option $1" ;;
    esac
  done
  config_json "$config" | jq -c '.devices | to_entries
    | map(select(.value.default == true) | {key} + .value)'
}

main() {
  case "${1:-help}" in
    ftl) shift; cmd_ftl "$@" ;;
    local) shift; cmd_local "$@" ;;
    build)
      shift
      local platform="${1:-}" screens="" out="" profile="${SURVEY_PROFILE:-}"
      shift || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --screens) screens="${2-}"; shift 2 ;;
          --out) out="${2:?}"; shift 2 ;;
          --profile) profile="${2:?}"; shift 2 ;;
          *) die "unknown option $1" ;;
        esac
      done
      out="${out:-$APP_DIR/build/survey/build-$platform}"
      case "$platform" in
        android) build_android "$out" "$screens" ;;
        ios) build_ios "$out" "$screens" "$profile" ;;
        *) die "build android or build ios" ;;
      esac
      printf 'survey: built into %s\n' "$out" >&2
      ;;
    record) shift; cmd_record "$@" ;;
    from-log) shift; cmd_from_log "$@" ;;
    classify) shift; cmd_classify "$@" ;;
    issues) shift; cmd_issues "$@" ;;
    append) shift; cmd_append "$@" ;;
    history) shift; cmd_history "$@" ;;
    plan) shift; cmd_plan "$@" ;;
    help | -h | --help) usage ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
}

main "$@"
