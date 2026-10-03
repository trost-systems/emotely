#!/usr/bin/env bash
# Tests for the performance survey's data side (`survey.sh`, #242): a
# device's survey.json into history records, records into findings by
# severity, findings into one issue per screen and metric, and the history
# query. No device, no Test Lab, no GitHub: `gh` is a fake on PATH.
# Run from anywhere:
#   bash .claude/skills/run-app/scripts/survey.test.sh
set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SURVEY="$SCRIPTS/survey.sh"
REPO="$(git -C "$SCRIPTS" rev-parse --show-toplevel)"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# --- fixtures ---------------------------------------------------------------------

# A config of two screens (journal gated, more not), a 120 Hz phone, a 60 Hz
# phone and a virtual device that judges build times only.
cat >"$work/survey.yaml" <<'EOF'
screens:
  journal: { route: JournalRoute, gated: true }
  more: { route: MoreRoute }
devices:
  fast-phone:
    platform: android
    model: FAST
    version: "36"
    name: Fast Phone
    form: physical
    default: true
  slow-phone:
    platform: android
    model: slow
    version: "34"
    name: Slow Phone
    form: physical
    default: false
  virtual:
    platform: android
    model: Virtual.arm
    version: "34"
    name: Virtual
    form: virtual
    default: false
    judges: [build_p90]
severity:
  floor_ms: 16.7
  max_missed_percent: 1
  target_ms: 8.3
  major_drift_percent: 20
  minor_drift_percent: 10
  min_drift_ms: 0.5
  baseline_runs: 7
  baseline_days: 30
  min_baseline_runs: 3
  high_refresh_hz: 110
  min_frames: 60
EOF

# screen <frames> <build ms> <raster ms> [requests JSON]: one screen of a
# survey.json, every frame taking those times (in microseconds, as the
# engine reports them).
screen() {
  jq -n --argjson n "$1" --argjson build "$2" --argjson raster "$3" \
    --argjson requests "${4:-[\"supabase GET /rest/v1/entries\"]}" '{
      frame_count: $n,
      frame_build_times: [range($n) | $build * 1000 | round],
      frame_rasterizer_times: [range($n) | $raster * 1000 | round],
      requests: $requests
    }'
}

# survey <file> <refresh hz> <journal screen JSON> <more screen JSON>: each
# screen's frames one vsync apart at that rate, as the engine timed them.
survey() {
  jq -n --argjson hz "$2" --argjson journal "$3" --argjson more "$4" '
    def vsynced: . + {frame_vsync_starts: [range(.frame_count) | . * 1000000 / $hz | round]};
    {
      schema: 1, startup_ms: 812, refresh_hz: $hz,
      screens: {journal: ($journal | vsynced), more: ($more | vsynced)}
    }' >"$1"
}

# record <survey.json> <device> <run> <at> [args]: the history records of
# one run, into $out, with the exit status in $status.
record() {
  local file="$1" device="$2" run="$3" at="$4"
  shift 4
  status=0
  out="$(bash "$SURVEY" record "$file" --config "$work/survey.yaml" --device "$device" \
    --run "$run" --at "$at" --commit abc1234 --source test "$@" 2>"$work/err")" || status=$?
}

# history_of <device> <journal build ms> <count> [source]: <count> earlier
# full surveys (or runs of [source]) of both screens on <device>, a day apart
# before 2026-09-20, each at those journal build times and a fast More.
history_of() {
  local device="$1" build="$2" count="$3" source="${4:-survey}" i
  for ((i = 1; i <= count; i++)); do
    survey "$work/h.json" 120 "$(screen 200 "$build" 3)" "$(screen 200 2 3)"
    record "$work/h.json" "$device" "earlier-$device-$i" \
      "2026-09-$(printf '%02d' $((20 - i)))T04:00:00Z" --source "$source"
    printf '%s\n' "$out"
  done
}

# classify <records> <history>: the findings, into $findings.
classify() {
  printf '%s\n' "$1" >"$work/records.jsonl"
  printf '%s\n' "$2" >"$work/history.jsonl"
  status=0
  findings="$(bash "$SURVEY" classify "$work/records.jsonl" --history "$work/history.jsonl" \
    --config "$work/survey.yaml" 2>"$work/err")" || status=$?
}

# today <device> <hz> <journal screen> <more screen>: today's records.
today() {
  survey "$work/t.json" "$2" "$3" "$4"
  record "$work/t.json" "$1" "today" "2026-09-29T04:00:00Z"
  printf '%s\n' "$out"
}

# finding <key>: the finding filed under that screen/metric, or null.
finding() { jq -c --arg key "$1" 'map(select(.key == $key)) | .[0]' <<<"$findings"; }

# --- records ----------------------------------------------------------------------

test_records_one_line_per_screen_with_percentiles_and_missed_frames() {
  # Builds of 1, 2, ... 100 ms: nearest-rank p50 50, p90 90, p99 99; 84 of
  # the 100 over 16.7 ms and 92 over 8.3 ms.
  jq -n '{schema: 1, startup_ms: 640, refresh_hz: 120.0, screens: {journal: {
      frame_count: 100,
      frame_build_times: [range(1; 101) | . * 1000],
      frame_rasterizer_times: [range(100) | 2000],
      requests: ["config GET /api/config", "supabase GET /rest/v1/entries", "supabase GET /rest/v1/sessions"]
    }, more: {frame_count: 0, frame_build_times: [], frame_rasterizer_times: [], requests: []}}}' >"$work/p.json"
  record "$work/p.json" FAST:36 run-1 2026-09-29T04:00:00Z
  ((status == 0)) || fail "records a run: exit $status, $(cat "$work/err")"
  [[ "$(wc -l <<<"$out" | tr -d ' ')" == 2 ]] || fail "records one line per screen: got $out"
  jq -e 'select(.screen == "journal")
    | .build_ms == {p50: 50, p90: 90, p99: 99}
      and .raster_ms == {p50: 2, p90: 2, p99: 2}
      and .frames == 100
      and .missed_60_percent == 84 and .missed_120_percent == 92
      and .requests == {config: 1, supabase: 2}' <<<"$out" >/dev/null ||
    fail "records percentiles, missed frames and requests: got $(grep journal <<<"$out")"
}

test_records_the_run_and_the_device_beside_the_numbers() {
  survey "$work/r.json" 120 "$(screen 200 2 3)" "$(screen 200 2 3)"
  record "$work/r.json" FAST:36 run-2 2026-09-29T04:00:00Z
  jq -e 'select(.screen == "more")
    | .run == "run-2" and .at == "2026-09-29T04:00:00Z" and .commit == "abc1234"
      and .source == "test" and .startup_ms == 812 and .refresh_hz == 120
      and .device == {key: "fast-phone", model: "FAST", version: "36", name: "Fast Phone",
                      platform: "android", form: "physical"}' <<<"$out" >/dev/null ||
    fail "records the run and the device: got $(grep '"more"' <<<"$out")"
}

test_records_the_refresh_rate_the_frames_ran_at_not_the_one_the_display_reported() {
  # A phone with an adaptive display reports 24 Hz at start, then draws a
  # fling at 120 Hz: 8333 µs between most frames, and a pause between
  # gestures.
  jq -n '{schema: 1, startup_ms: 1, refresh_hz: 24.000001, screens: {
      journal: {frame_count: 5, frame_build_times: [1000, 1000, 1000, 1000, 1000],
        frame_rasterizer_times: [1000, 1000, 1000, 1000, 1000],
        frame_vsync_starts: [0, 8333, 16667, 25000, 900000], requests: []},
      more: {frame_count: 0, frame_build_times: [], frame_rasterizer_times: [],
        frame_vsync_starts: [], requests: []}}}' >"$work/hz.json"
  record "$work/hz.json" FAST:36 run-hz 2026-09-29T04:00:00Z
  jq -e 'select(.screen == "journal") | .refresh_hz == 120 and .display_hz == 24' <<<"$out" >/dev/null ||
    fail "records the refresh rate of the frames: got $(grep journal <<<"$out")"
  jq -e 'select(.screen == "more") | .refresh_hz == 24' <<<"$out" >/dev/null ||
    fail "falls back to the display's rate without frames: got $(grep '"more"' <<<"$out")"
}

test_records_a_device_the_config_does_not_list() {
  survey "$work/u.json" 60 "$(screen 200 2 3)" "$(screen 200 2 3)"
  record "$work/u.json" OTHER:33 run-3 2026-09-29T04:00:00Z --form virtual
  ((status == 0)) || fail "records an unlisted device: exit $status, $(cat "$work/err")"
  jq -e 'select(.screen == "journal") | .device == {key: "OTHER:33", model: "OTHER",
      version: "33", name: "OTHER", platform: "android", form: "virtual"}' <<<"$out" >/dev/null ||
    fail "records an unlisted device: got $(grep journal <<<"$out")"
}

test_refuses_a_full_walk_that_missed_a_screen() {
  jq -n --argjson journal "$(screen 200 2 3)" \
    '{schema: 1, startup_ms: 1, refresh_hz: 60, screens: {journal: $journal}}' >"$work/m.json"
  record "$work/m.json" FAST:36 run-4 2026-09-29T04:00:00Z
  ((status != 0)) || fail "refuses a walk that missed a screen: exit 0"
  grep -q 'more' "$work/err" || fail "refuses a walk that missed a screen: the error does not name it"
  # An ad-hoc run of one screen is not a full walk.
  record "$work/m.json" FAST:36 run-4 2026-09-29T04:00:00Z --screens journal
  ((status == 0)) || fail "records an ad-hoc run of one screen: exit $status, $(cat "$work/err")"
}

# --- survey.json from the device's log --------------------------------------------

test_reassembles_survey_json_from_the_device_log() {
  # The walk also logs survey.json in numbered chunks between bars; a log
  # interleaves other lines, repeats a line now and then, and a chunk may
  # end in a space.
  cat >"$work/syslog.txt" <<'EOF'
Sep 29 15:29:12 iPhone Runner(Flutter)[716] <Notice>: flutter: survey.json 2/3 |"b": "x |
Sep 29 15:29:12 iPhone SpringBoard[33] <Notice>: something else
Sep 29 15:29:12 iPhone Runner(Flutter)[716] <Notice>: flutter: survey.json 1/3 |{"a": 1, |
Sep 29 15:29:12 iPhone Runner(Flutter)[716] <Notice>: flutter: survey.json 3/3 |y"}|
Sep 29 15:29:12 iPhone Runner(Flutter)[716] <Notice>: flutter: survey.json 1/3 |{"a": 1, |
EOF
  local got status=0
  got="$(bash "$SURVEY" from-log "$work/syslog.txt")" || status=$?
  ((status == 0)) || fail "reassembles survey.json from the log: exit $status"
  [[ "$(jq -c . <<<"$got" 2>/dev/null)" == '{"a":1,"b":"x y"}' ]] ||
    fail "reassembles survey.json from the log: got $got"
}

test_reassembles_survey_json_from_logcat() {
  cat >"$work/logcat.txt" <<'EOF'
09-30 01:38:13.703  5836  5836 I flutter : survey.json 1/2 |{"a": |
09-30 01:38:13.723  5836  5836 I flutter : survey.json 2/2 |2}|
EOF
  local got
  got="$(bash "$SURVEY" from-log "$work/logcat.txt" 2>/dev/null)" || true
  [[ "$(jq -c . <<<"$got" 2>/dev/null)" == '{"a":2}' ]] ||
    fail "reassembles survey.json from logcat: got $got"
}

test_refuses_a_log_that_lost_a_chunk() {
  printf '%s\n' 'x flutter: survey.json 1/2 |{"a": |' >"$work/partial.txt"
  local status=0
  bash "$SURVEY" from-log "$work/partial.txt" >/dev/null 2>&1 || status=$?
  ((status != 0)) || fail "refuses a log that lost a chunk: exit 0"
}

# --- severity ---------------------------------------------------------------------

test_files_nothing_for_fast_screens() {
  classify "$(today FAST:36 120 "$(screen 200 2 3)" "$(screen 200 2 3)")" ""
  ((status == 0)) || fail "files nothing for fast screens: exit $status, $(cat "$work/err")"
  [[ "$findings" == "[]" ]] || fail "files nothing for fast screens: got $findings"
}

test_a_p90_over_the_60_fps_floor_is_critical() {
  classify "$(today slow:34 60 "$(screen 200 18 3)" "$(screen 200 2 3)")" ""
  jq -e '.severity == "critical" and .screen == "journal" and .metric == "build_p90"
    and (.observations | length == 1)
    and (.observations[0] | .device.key == "slow-phone" and .value == 18 and .limit == 16.7)' \
    <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "a p90 over the floor is critical: got $findings"
}

test_one_percent_of_frames_over_the_floor_is_critical() {
  # 2 of 200 frames at 20 ms of raster: 1%, the p90 still fast.
  local more
  more="$(screen 200 2 3 | jq '.frame_rasterizer_times[0] = 20000 | .frame_rasterizer_times[1] = 20000')"
  classify "$(today slow:34 60 "$(screen 200 2 3)" "$more")" ""
  jq -e '.severity == "critical" and .metric == "missed_frames"
    and .observations[0].value == 1 and .observations[0].limit == 1' \
    <<<"$(finding more/missed_frames)" >/dev/null ||
    fail "1% missed frames is critical: got $findings"
  [[ "$(finding more/raster_p90)" == null ]] || fail "1% missed frames: the p90 is fast, yet filed"
}

test_more_than_20_percent_over_the_baseline_is_major() {
  # Three earlier runs at 4 ms on a 60 Hz phone; today 5 ms: 25% slower.
  local history
  history="$(history_of slow:34 4 3)"
  classify "$(today slow:34 60 "$(screen 200 5 3)" "$(screen 200 2 3)")" "$history"
  jq -e '.severity == "major" and (.observations[0] | .baseline == 4 and .drift_percent == 25)' \
    <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "20%+ over the baseline is major: got $findings"
}

test_10_to_20_percent_over_the_baseline_is_minor() {
  local history
  history="$(history_of slow:34 4 3)"
  classify "$(today slow:34 60 "$(screen 200 4.6 3)" "$(screen 200 2 3)")" "$history"
  jq -e '.severity == "minor" and .observations[0].drift_percent == 15' \
    <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "10-20% over the baseline is minor: got $findings"
}

test_the_baseline_is_the_median_of_the_trailing_runs() {
  # Seven runs at 4 ms and one outlier at 9 ms: the median is still 4.
  local history
  history="$(history_of slow:34 4 7)
$(history_of slow:34 9 1 | sed 's/earlier-slow:34-1/outlier/g')"
  classify "$(today slow:34 60 "$(screen 200 5 3)" "$(screen 200 2 3)")" "$history"
  jq -e '.observations[0].baseline == 4' <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "the baseline is the median: got $findings"
}

test_judges_no_drift_before_three_earlier_runs() {
  local history
  history="$(history_of slow:34 4 2)"
  classify "$(today slow:34 60 "$(screen 200 6 3)" "$(screen 200 2 3)")" "$history"
  [[ "$findings" == "[]" ]] || fail "judges no drift before three runs: got $findings"
}

test_the_baseline_is_the_full_surveys_alone() {
  # Ad-hoc runs chase a regression or prove a fix on a branch; the baseline
  # is what the full surveys of the default devices measured.
  local history
  history="$(history_of slow:34 4 3 adhoc)"
  classify "$(today slow:34 60 "$(screen 200 6 3)" "$(screen 200 2 3)")" "$history"
  [[ "$findings" == "[]" ]] || fail "the baseline is the full surveys alone: got $findings"
}

test_judges_no_drift_under_half_a_millisecond() {
  # 1 ms to 1.4 ms is 40%, but 0.4 ms of it: noise.
  local history
  history="$(history_of slow:34 1 3)"
  classify "$(today slow:34 60 "$(screen 200 1.4 3)" "$(screen 200 1 3)")" "$history"
  [[ "$findings" == "[]" ]] || fail "judges no drift under 0.5 ms: got $findings"
}

test_compares_only_with_the_same_device() {
  # The fast phone's history says nothing about the slow phone.
  local history
  history="$(history_of FAST:36 2 3)"
  classify "$(today slow:34 60 "$(screen 200 5 3)" "$(screen 200 2 3)")" "$history"
  [[ "$findings" == "[]" ]] || fail "compares only with the same device: got $findings"
}

test_missing_120_fps_on_a_120_hz_phone_is_major_on_a_gated_screen_and_minor_elsewhere() {
  classify "$(today FAST:36 120 "$(screen 200 9 3)" "$(screen 200 9 3)")" ""
  jq -e '.severity == "major" and .observations[0].limit == 8.3' \
    <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "over 8.3 ms at 120 Hz on a gated screen is major: got $findings"
  jq -e '.severity == "minor"' <<<"$(finding more/build_p90)" >/dev/null ||
    fail "over 8.3 ms at 120 Hz elsewhere is minor: got $findings"
  # The same frames on a 60 Hz phone are within its floor.
  classify "$(today slow:34 60 "$(screen 200 9 3)" "$(screen 200 9 3)")" ""
  [[ "$findings" == "[]" ]] || fail "over 8.3 ms at 60 Hz is fine: got $findings"
}

test_a_virtual_device_is_judged_on_build_times_only() {
  # Software rendering: raster over the floor says nothing about the app.
  classify "$(today Virtual.arm:34 60 "$(screen 200 2 40)" "$(screen 200 18 40)")" ""
  [[ "$(jq 'length' <<<"$findings")" == 1 ]] || fail "a virtual device judges build only: got $findings"
  jq -e '.severity == "critical"' <<<"$(finding more/build_p90)" >/dev/null ||
    fail "a virtual device still judges build: got $findings"
}

test_judges_nothing_on_too_few_frames() {
  classify "$(today slow:34 60 "$(screen 30 30 30)" "$(screen 200 2 3)")" ""
  [[ "$findings" == "[]" ]] || fail "judges nothing on too few frames: got $findings"
}

test_one_finding_per_screen_and_metric_with_the_worst_severity() {
  # Critical on the slow phone, major on the fast one: one finding, critical,
  # naming both.
  classify "$(today slow:34 60 "$(screen 200 18 3)" "$(screen 200 2 3)")
$(today FAST:36 120 "$(screen 200 9 3)" "$(screen 200 2 3)")" ""
  [[ "$(jq 'map(select(.key == "journal/build_p90")) | length' <<<"$findings")" == 1 ]] ||
    fail "one finding per screen and metric: got $findings"
  jq -e '.severity == "critical" and (.observations | map(.severity) | sort == ["critical", "major"])' \
    <<<"$(finding journal/build_p90)" >/dev/null ||
    fail "the worst severity wins: got $findings"
}

# --- issues -----------------------------------------------------------------------

# A fake `gh` that keeps the open issues in $work/gh/issues.json and logs
# every call that writes to $work/gh/calls.
fake_gh() {
  mkdir -p "$work/bin" "$work/gh"
  printf '[]\n' >"$work/gh/issues.json"
  : >"$work/gh/calls"
  cat >"$work/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
dir="$FAKE_GH"
arg() { local want="$1"; shift; while [[ $# -gt 0 ]]; do [[ "$1" == "$want" ]] && { printf '%s' "$2"; return; }; shift; done; }
case "$1 $2" in
  "issue list")
    jq '[.[] | {number, title}]' "$dir/issues.json" ;;
  "issue create")
    title="$(arg --title "$@")"
    number=$(( $(jq 'length' "$dir/issues.json") + 100 ))
    jq --arg t "$title" --argjson n "$number" '. + [{number: $n, title: $t}]' "$dir/issues.json" >"$dir/i" && mv "$dir/i" "$dir/issues.json"
    printf 'create %s %s\n' "$number" "$title" >>"$dir/calls"
    cp "$(arg --body-file "$@")" "$dir/body-$number"
    printf 'https://github.com/o/r/issues/%s\n' "$number" ;;
  "issue edit")
    title="$(arg --title "$@")"
    jq --arg t "$title" --argjson n "$3" 'map(if .number == $n then .title = $t else . end)' "$dir/issues.json" >"$dir/i" && mv "$dir/i" "$dir/issues.json"
    printf 'edit %s %s\n' "$3" "$title" >>"$dir/calls" ;;
  "issue comment")
    printf 'comment %s\n' "$3" >>"$dir/calls"
    cp "$(arg --body-file "$@")" "$dir/comment-$3" ;;
  *) printf 'fake gh: unexpected %s\n' "$*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$work/bin/gh"
}

# issues <findings> [args]: files them through the fake gh.
issues() {
  printf '%s\n' "$1" >"$work/findings.json"
  shift
  status=0
  PATH="$work/bin:$PATH" FAKE_GH="$work/gh" bash "$SURVEY" issues "$work/findings.json" \
    --run-url https://example.test/run/1 "$@" >"$work/issues.out" 2>&1 || status=$?
}

test_files_one_issue_per_finding_with_the_severity_first_in_the_title() {
  fake_gh
  classify "$(today slow:34 60 "$(screen 200 18 3)" "$(screen 200 2 3)")" ""
  issues "$findings"
  ((status == 0)) || fail "files an issue: exit $status, $(cat "$work/issues.out")"
  grep -qx 'create 100 \[critical\] Perf survey: journal build p90' "$work/gh/calls" ||
    fail "files an issue titled with its severity: calls were $(cat "$work/gh/calls")"
  # 18 ms frames also miss the floor: that metric is an issue of its own.
  [[ "$(grep -c '^create' "$work/gh/calls")" == 2 ]] ||
    fail "files one issue per metric: calls were $(cat "$work/gh/calls")"
  grep -qF '| Slow Phone (slow, 34) | 18 ms |' "$work/gh/body-100" ||
    fail "the issue names the device and the value: $(cat "$work/gh/body-100")"
  grep -qF 'survey.sh ftl --device slow:34 --screens journal' "$work/gh/body-100" ||
    fail "the issue says how to reproduce it on the same device"
}

test_a_second_run_updates_the_issue_instead_of_filing_another() {
  fake_gh
  classify "$(today FAST:36 120 "$(screen 200 9 3)" "$(screen 200 2 3)")" ""
  issues "$findings" # major
  classify "$(today slow:34 60 "$(screen 200 18 3)" "$(screen 200 2 3)")" ""
  issues "$findings" # now critical
  ((status == 0)) || fail "updates the issue: exit $status, $(cat "$work/issues.out")"
  # (18 ms frames also miss the floor: missed frames is an issue of its own.)
  [[ "$(grep -c '^create .* build p90$' "$work/gh/calls")" == 1 ]] ||
    fail "a second run files no duplicate: calls were $(cat "$work/gh/calls")"
  grep -qx 'edit 100 \[critical\] Perf survey: journal build p90' "$work/gh/calls" ||
    fail "a second run retitles the issue with the new severity: $(cat "$work/gh/calls")"
  grep -qx 'comment 100' "$work/gh/calls" || fail "a second run comments its numbers"
  # The same severity again: a comment each, no retitle, nothing new.
  : >"$work/gh/calls"
  issues "$findings"
  [[ "$(sort "$work/gh/calls" | tr '\n' ' ')" == "comment 100 comment 101 " ]] ||
    fail "the same severity only comments: $(cat "$work/gh/calls")"
}

test_a_tag_keeps_test_issues_apart_from_real_ones() {
  fake_gh
  classify "$(today slow:34 60 "$(screen 200 18 3)" "$(screen 200 2 3)")" ""
  issues "$findings"
  issues "$findings" --tag '[TEST #242]'
  grep -qE '^create [0-9]+ \[critical\] \[TEST #242\] Perf survey: journal build p90$' "$work/gh/calls" ||
    fail "a tagged run files its own issue: $(cat "$work/gh/calls")"
}

# --- history ----------------------------------------------------------------------

test_the_history_query_filters_by_device_screen_and_days() {
  {
    history_of slow:34 4 3
    history_of FAST:36 2 2
    survey "$work/o.json" 60 "$(screen 200 4 3)" "$(screen 200 2 3)"
    record "$work/o.json" slow:34 long-ago 2026-07-01T04:00:00Z
    printf '%s\n' "$out"
  } >"$work/all.jsonl"
  status=0
  out="$(SURVEY_NOW=2026-09-29T12:00:00Z bash "$SURVEY" history --from "$work/all.jsonl" \
    --device 'slow phone' --screen journal --days 30 --json)" || status=$?
  ((status == 0)) || fail "the history query: exit $status"
  jq -e -s 'length == 3 and all(.device.key == "slow-phone" and .screen == "journal")
    and (map(.at) == (map(.at) | sort))' <<<"$out" >/dev/null ||
    fail "the history query filters device, screen and days: got $out"
  out="$(SURVEY_NOW=2026-09-29T12:00:00Z bash "$SURVEY" history --from "$work/all.jsonl" \
    --device slow --screen journal --days 30)"
  if ! grep -qF '2026-09-19T04:00:00Z' <<<"$out" || ! grep -qF 'abc1234' <<<"$out"; then
    fail "the history table lists each run: got $out"
  fi
}

# --- the default devices ----------------------------------------------------------

test_a_full_survey_runs_the_default_devices() {
  local plan
  plan="$(bash "$SURVEY" plan --config "$work/survey.yaml" | jq -c 'map(.key)')"
  [[ "$plan" == '["fast-phone"]' ]] || fail "a full survey runs the default devices: got $plan"
}

test_a_full_survey_stays_within_the_physical_quota() {
  # 5 physical runs a day on the Spark plan, shared with ad-hoc runs: a
  # full survey leaves at least 2 of them, so one a day still leaves room
  # to chase a regression.
  local config="$REPO/apps/mobile/app/integration_test/survey.yaml" n
  n="$(bash "$SURVEY" plan --config "$config" | jq 'map(select(.form == "physical")) | length')"
  ((n >= 1 && n <= 3)) || fail "a full survey takes 1 to 3 physical runs: it takes $n"
}

# --- the screens ------------------------------------------------------------------

test_the_survey_walks_every_route_of_the_feature_map() {
  local map="$REPO/.claude/skills/run-app/references/feature-map.yaml"
  local config="$REPO/apps/mobile/app/integration_test/survey.yaml"
  local routes surveyed
  routes="$(yq '.screens[].route' "$map" | sort)"
  surveyed="$(yq '.screens[].route' "$config" | sort)"
  [[ "$routes" == "$surveyed" ]] ||
    fail "survey.yaml covers the feature map: routes $(tr '\n' ' ' <<<"$routes"), surveyed $(tr '\n' ' ' <<<"$surveyed")"
}

test_the_walk_knows_every_screen_of_the_config() {
  local config="$REPO/apps/mobile/app/integration_test/survey.yaml"
  local walk="$REPO/apps/mobile/app/integration_test/survey/survey_walk.dart"
  local configured walked
  configured="$(yq '.screens | keys | .[]' "$config" | sort)"
  walked="$(sed -n '/^const surveyScreens = \[/,/^\];/p' "$walk" | sed -n "s/^  '\([a-z_]*\)',$/\1/p" | sort)"
  [[ "$configured" == "$walked" ]] ||
    fail "the walk covers survey.yaml: config $(tr '\n' ' ' <<<"$configured"), walk $(tr '\n' ' ' <<<"$walked")"
}

for test in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
  "$test"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'survey.test.sh: all passed\n'
