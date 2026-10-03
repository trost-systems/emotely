#!/usr/bin/env bash
# Tests for the performance budget's gate (`perf.sh gate`): the frame limits,
# the request counts and the latency ceilings, judged from a run directory
# as the profile run writes it, against a budget file. No device needed.
# Run from anywhere:
#   bash .claude/skills/run-app/scripts/perf.test.sh
set -euo pipefail

PERF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/perf.sh"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# --- fixtures ---------------------------------------------------------------------

# A budget for one path, `scroll`: two Supabase requests, frames at the
# 60 fps floor with a 20% headroom over the baseline. `test` gates it all;
# `emulator` and `new-emulator` report raster and the floor, as the budget
# does for an emulator; `phone` has no baseline yet.
write_budget() {
  cat >"$1" <<'EOF'
frames:
  floor_ms: 16.7
  target_ms: 8.3
  max_missed_percent: 1
  headroom_percent: 20
  min_frames: 100
requests:
  scroll:
    supabase: 2
latency:
  supabase_read_p95_ms: 1000
  agent_first_byte_p95_ms: 5000
environments:
  test:
    raster: gated
    baseline:
      scroll:
        build_p90_ms: 2.0
        raster_p90_ms: 5.0
  emulator:
    raster: reported
    floor: reported
    baseline:
      scroll:
        build_p90_ms: 15.0
  new-emulator:
    raster: reported
    floor: reported
    baseline: {}
  phone:
    raster: gated
    baseline: {}
EOF
}

# frames <count> <build ms> <raster ms>: a timeline summary of <count>
# frames, every one taking those times, in the shape flutter_driver writes.
frames() {
  jq -n --argjson n "$1" --argjson build "$2" --argjson raster "$3" '{
    frame_count: $n,
    "90th_percentile_frame_build_time_millis": $build,
    "90th_percentile_frame_rasterizer_time_millis": $raster,
    frame_build_times: [range($n) | $build * 1000 | floor],
    frame_rasterizer_times: [range($n) | $raster * 1000 | floor]
  }'
}

# new_run <dir>: a run of `scroll` within the test budget: 200 frames at
# 1.5 ms build and 4 ms raster, and the two Supabase requests.
new_run() {
  mkdir -p "$1"
  frames 200 1.5 4 >"$1/scroll.timeline_summary.json"
  jq -n '{scroll: ["supabase GET /rest/v1/entries", "supabase GET /rest/v1/sessions"]}' \
    >"$1/requests.json"
}

# gate <dir> [args]: runs the gate, capturing its exit status in $status.
gate() {
  status=0
  bash "$PERF" gate "$@" --budget "$work/budget.yaml" >"$work/gate.out" 2>&1 || status=$?
}

# check <dir> <jq filter>: whether result.json satisfies the filter.
check() { jq -e "$2" "$1/result.json" >/dev/null; }

write_budget "$work/budget.yaml"

# --- request counts ---------------------------------------------------------------

test_passes_a_run_within_budget() {
  local run="$work/within"
  new_run "$run"
  gate "$run" --env test
  ((status == 0)) || fail "passes a run within budget: exit $status, $(cat "$work/gate.out")"
  check "$run" '.pass == true' || fail "passes a run within budget: result says it failed"
}

test_fails_an_extra_request_on_a_path() {
  local run="$work/extra-request"
  new_run "$run"
  jq '.scroll += ["supabase GET /rest/v1/entries"]' "$run/requests.json" >"$run/r" && mv "$run/r" "$run/requests.json"
  gate "$run" --env test
  ((status == 1)) || fail "fails an extra request: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "requests.supabase")
    | .status == "fail" and .value == 3 and .limit == 2' ||
    fail "fails an extra request: the supabase count check is not a failure of 3 over 2"
}

test_summarizes_a_failure_for_the_issue_it_opens() {
  local run="$work/summary-failure"
  new_run "$run"
  jq '.scroll += ["supabase GET /rest/v1/entries"]' "$run/requests.json" >"$run/r" && mv "$run/r" "$run/requests.json"
  gate "$run" --env test
  grep -qF "Over budget on \`test\`" "$run/summary.md" ||
    fail "summarizes a failure: no over-budget headline in summary.md"
  grep -qF '| scroll | requests.supabase | 3 | 2 | **fail** |' "$run/summary.md" ||
    fail "summarizes a failure: no failing row for requests.supabase"
  # What the path asked for, so the extra request is found without a device.
  grep -qF "2 × \`supabase GET /rest/v1/entries\`" "$run/summary.md" ||
    fail "summarizes a failure: the path's requests are not listed"
}

test_summarizes_a_pass() {
  local run="$work/summary-pass"
  new_run "$run"
  gate "$run" --env test
  grep -qF "Within budget on \`test\`" "$run/summary.md" ||
    fail "summarizes a pass: no within-budget headline in summary.md"
}

# --- frames -----------------------------------------------------------------------

test_fails_a_build_p90_over_the_baseline_plus_headroom() {
  local run="$work/slow-build"
  new_run "$run"
  # Baseline 2.0 ms plus 20% is 2.4 ms, well under the 16.7 ms floor.
  frames 200 2.5 4 >"$run/scroll.timeline_summary.json"
  gate "$run" --env test
  ((status == 1)) || fail "fails a build p90 over the baseline: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.p90_ms")
    | .status == "fail" and .value == 2.5 and .limit == 2.4' ||
    fail "fails a build p90 over the baseline: no failed build.p90_ms check at limit 2.4"
}

test_reports_raster_without_gating_it_where_the_budget_says_so() {
  local run="$work/emulator-raster"
  new_run "$run"
  # An emulator draws through the host: 17 ms of raster is its swap, not
  # the app's.
  frames 200 1.5 17 >"$run/scroll.timeline_summary.json"
  gate "$run" --env emulator
  ((status == 0)) || fail "reports raster without gating it: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "raster.p90_ms")
    | .status == "reported" and .limit == 16.7' ||
    fail "reports raster without gating it: raster.p90_ms is not reported against the floor"
  # The target means nothing where the floor does not gate.
  check "$run" '[.checks[] | select(.check == "raster.target_ms")] | length == 0' ||
    fail "reports raster without gating it: it still judges raster against the target"
}

# with_slow_frames <dir> <build|rasterizer> <count>: makes the first <count>
# frames of the run take 20 ms on that thread, over the 16.7 ms floor.
with_slow_frames() {
  jq --arg key "frame_$2_times" --argjson n "$3" \
    '.[$key] |= (to_entries | map(if .key < $n then 20000 else .value end))' \
    "$1/scroll.timeline_summary.json" >"$1/s" && mv "$1/s" "$1/scroll.timeline_summary.json"
}

test_fails_when_one_percent_of_frames_miss_the_floor() {
  local run="$work/missed-1pct"
  new_run "$run"
  with_slow_frames "$run" build 2 # 2 of 200: 1%, not under it
  gate "$run" --env test
  ((status == 1)) || fail "fails at 1% missed frames: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.missed_percent")
    | .status == "fail" and .value == 1 and .limit == 1' ||
    fail "fails at 1% missed frames: build.missed_percent is not a failure of 1 at 1"
}

test_passes_when_under_one_percent_of_frames_miss_the_floor() {
  local run="$work/missed-half-pct"
  new_run "$run"
  with_slow_frames "$run" rasterizer 1 # 1 of 200: 0.5%
  gate "$run" --env test
  ((status == 0)) || fail "passes under 1% missed frames: exit $status, $(cat "$work/gate.out")"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "raster.missed_percent")
    | .status == "pass" and .value == 0.5' ||
    fail "passes under 1% missed frames: raster.missed_percent is not a pass at 0.5"
}

test_reports_missed_frames_where_the_floor_is_only_reported() {
  local run="$work/emulator-missed"
  new_run "$run"
  # A shared runner stalls the emulator now and then.
  with_slow_frames "$run" build 6 # 3%
  gate "$run" --env emulator
  ((status == 0)) || fail "reports missed frames without gating them: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.missed_percent")
    | .status == "reported" and .value == 3' ||
    fail "reports missed frames without gating them: build.missed_percent is not reported at 3"
}

test_holds_a_p90_to_the_baseline_alone_where_the_floor_is_only_reported() {
  local run="$work/emulator-over-floor"
  new_run "$run"
  # The runner's baseline is 15 ms: 17.5 ms is over the floor but within
  # the baseline plus 20% (18 ms), which is all that gates there.
  frames 200 17.5 90 >"$run/scroll.timeline_summary.json"
  gate "$run" --env emulator
  ((status == 0)) || fail "holds a p90 to the baseline alone: exit $status, $(cat "$work/gate.out")"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.p90_ms")
    | .status == "pass" and .limit == 18' ||
    fail "holds a p90 to the baseline alone: build.p90_ms is not a pass at limit 18"
}

test_only_reports_a_p90_without_a_baseline_where_the_floor_is_only_reported() {
  local run="$work/new-emulator"
  new_run "$run"
  frames 200 17.5 90 >"$run/scroll.timeline_summary.json"
  gate "$run" --env new-emulator
  ((status == 0)) || fail "only reports a p90 without a baseline: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.p90_ms")
    | .status == "reported" and .limit == 16.7' ||
    fail "only reports a p90 without a baseline: build.p90_ms is not reported against the floor"
}

test_fails_a_path_that_drew_too_few_frames_to_judge() {
  local run="$work/few-frames"
  new_run "$run"
  # Under 100 frames, one slow frame is already over 1%.
  frames 50 1.5 4 >"$run/scroll.timeline_summary.json"
  gate "$run" --env test
  ((status == 1)) || fail "fails too few frames: exit $status"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "frames.count")
    | .status == "fail" and .value == 50 and .limit == 100' ||
    fail "fails too few frames: frames.count is not a failure of 50 under 100"
}

test_fails_a_path_without_a_timeline() {
  local run="$work/no-timeline"
  new_run "$run"
  rm "$run/scroll.timeline_summary.json"
  gate "$run" --env test
  ((status == 1)) || fail "fails a path without a timeline: exit $status, $(cat "$work/gate.out")"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "frames.count")
    | .status == "fail" and .value == 0' ||
    fail "fails a path without a timeline: frames.count is not a failure of 0"
}

test_warns_without_failing_when_a_p90_misses_the_120_fps_target() {
  local run="$work/under-target"
  new_run "$run"
  # No baseline on the phone: the 16.7 ms floor is the limit.
  frames 200 9 4 >"$run/scroll.timeline_summary.json"
  gate "$run" --env phone
  ((status == 0)) || fail "warns on the target: exit $status, $(cat "$work/gate.out")"
  check "$run" '.checks[] | select(.path == "scroll" and .check == "build.target_ms")
    | .status == "warn" and .value == 9 and .limit == 8.3' ||
    fail "warns on the target: build.target_ms is not a warning of 9 over 8.3"
}

# --- several runs -----------------------------------------------------------------

# three_runs <name> <build ms>...: three runs of `scroll` under $work/<name>,
# identical but for their build p90.
three_runs() {
  local name="$1" i=0 build
  shift
  for build in "$@"; do
    i=$((i + 1))
    new_run "$work/$name/$i"
    frames 200 "$build" 4 >"$work/$name/$i/scroll.timeline_summary.json"
  done
}

test_judges_the_median_of_several_runs() {
  # One slow runner out of three: the median is a normal night.
  three_runs one-slow 1.5 2.9 1.6
  status=0
  bash "$PERF" gate "$work/one-slow/1" "$work/one-slow/2" "$work/one-slow/3" \
    --env test --budget "$work/budget.yaml" >"$work/gate.out" 2>&1 || status=$?
  ((status == 0)) || fail "judges the median of several runs: exit $status, $(cat "$work/gate.out")"
  check "$work/one-slow/1" '.runs == 3 and (.checks[] | select(.path == "scroll" and .check == "build.p90_ms")
    | .value == 1.6 and .status == "pass")' ||
    fail "judges the median of several runs: build.p90_ms is not the median 1.6"
}

test_fails_when_most_runs_are_slow() {
  three_runs two-slow 2.5 2.9 1.6
  status=0
  bash "$PERF" gate "$work/two-slow/1" "$work/two-slow/2" "$work/two-slow/3" \
    --env test --budget "$work/budget.yaml" >"$work/gate.out" 2>&1 || status=$?
  ((status == 1)) || fail "fails when most runs are slow: exit $status"
  check "$work/two-slow/1" '.checks[] | select(.path == "scroll" and .check == "build.p90_ms")
    | .value == 2.5 and .status == "fail"' ||
    fail "fails when most runs are slow: build.p90_ms is not a failure at the median 2.5"
}

test_fails_an_extra_request_in_any_run() {
  three_runs one-extra 1.5 1.5 1.5
  jq '.scroll += ["supabase GET /rest/v1/entries"]' "$work/one-extra/3/requests.json" >"$work/r" &&
    mv "$work/r" "$work/one-extra/3/requests.json"
  status=0
  bash "$PERF" gate "$work/one-extra/1" "$work/one-extra/2" "$work/one-extra/3" \
    --env test --budget "$work/budget.yaml" >"$work/gate.out" 2>&1 || status=$?
  ((status == 1)) || fail "fails an extra request in any run: exit $status"
}

test_judges_runs_too_large_for_an_argument_list() {
  # Three nightly runs pool thousands of frame times; this is more than
  # any argument list holds (the first nightly gate died on it).
  local run="$work/huge"
  new_run "$run"
  frames 200000 1.5 4 >"$run/scroll.timeline_summary.json"
  gate "$run" --env test
  ((status == 0)) || fail "judges runs too large for an argument list: exit $status, $(tail -1 "$work/gate.out")"
}

# --- baseline ---------------------------------------------------------------------

test_takes_the_baseline_as_the_slowest_of_several_runs() {
  local one="$work/baseline-1" two="$work/baseline-2" out
  new_run "$one"
  new_run "$two"
  frames 200 1.9 4.5 >"$two/scroll.timeline_summary.json"
  out="$(bash "$PERF" baseline "$one" "$two")" || fail "baseline: exit $?"
  # The measurements behind it go into the budget file beside it.
  jq -e '.scroll == {build_p90_ms: 1.9, raster_p90_ms: 4.5,
      measured: {build_p90_ms: [1.5, 1.9], raster_p90_ms: [4, 4.5]}}' <<<"$out" >/dev/null ||
    fail "takes the slowest of several runs as the baseline: got $out"
}

# --- latency ----------------------------------------------------------------------

# latency <dir> <slow supabase reads>: 20 Supabase reads at 200 ms, the first
# <slow> of them at 1.5 s, and 5 agent rounds whose first byte came at 3 s.
latency() {
  jq -n --argjson slow "$2" '{
    supabase_read_ms: [range(20) | if . < $slow then 1500 else 200 end],
    agent_first_byte_ms: [range(5) | 3000],
    agent_round_ms: [range(5) | 3100]
  }' >"$1/latency.json"
}

test_fails_supabase_reads_over_their_p95_ceiling() {
  local run="$work/slow-reads"
  new_run "$run"
  latency "$run" 2 # 2 of 20 slow: the 95th percentile is slow
  gate "$run" --env test
  ((status == 1)) || fail "fails slow supabase reads: exit $status"
  check "$run" '.checks[] | select(.check == "latency.supabase_read_p95_ms")
    | .status == "fail" and .value == 1500 and .limit == 1000' ||
    fail "fails slow supabase reads: no failed supabase_read_p95_ms of 1500 over 1000"
}

test_passes_one_slow_read_and_only_reports_the_whole_agent_round() {
  local run="$work/one-slow-read"
  new_run "$run"
  latency "$run" 1 # 1 of 20: above the 95th percentile
  gate "$run" --env test
  ((status == 0)) || fail "passes one slow read: exit $status, $(cat "$work/gate.out")"
  check "$run" '[.checks[] | select(.check | startswith("latency."))]
    | (map(select(.check == "latency.supabase_read_p95_ms"))[0] | .status == "pass" and .value == 200)
      and (map(select(.check == "latency.agent_first_byte_p95_ms"))[0] | .status == "pass" and .value == 3000)
      and (map(select(.check == "latency.agent_round_p95_ms"))[0] | .status == "reported" and .value == 3100)' ||
    fail "passes one slow read: the latency checks are not pass, pass, reported"
}

test_judges_no_latency_when_the_run_measured_none() {
  local run="$work/no-latency"
  new_run "$run"
  gate "$run" --env test
  check "$run" '[.checks[] | select(.check | startswith("latency."))] | length == 0' ||
    fail "judges no latency when none was measured"
}

for test in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
  "$test"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'perf.test.sh: all passed\n'
