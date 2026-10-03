# The performance survey's history records (#242): one device's survey.json
# (what integration_test/survey_test.dart measured) as one record per
# screen, the shape the history keeps (one JSON object per line).
#
# Input: survey.json. Arguments (jq --slurpfile / --arg / --argjson):
#   $config     [survey.yaml as JSON]
#   $device     the device as `survey.sh` was given it: a key of
#               survey.yaml's devices, or `<model>:<version>`
#   $form, $platform   for a device survey.yaml does not list
#   $screens    the screens the walk was asked for, or null for all of them
#   $run, $at, $commit, $source   the run
#
# Frame times arrive in microseconds, one per frame; the records keep
# milliseconds, nearest-rank percentiles, the share of frames that missed a
# 60 Hz (floor_ms) or 120 Hz (target_ms) frame on either thread, and the
# refresh rate the frames ran at (display_hz is what the display reported).

def round3: . * 1000 | round / 1000;

# The nearest-rank percentile, in milliseconds, of times in microseconds.
def ms_percentile($p):
  if length == 0 then null
  else sort | .[((length * $p / 100) | ceil) - 1] / 1000 | round3
  end;

def percentiles: {p50: ms_percentile(50), p90: ms_percentile(90), p99: ms_percentile(99)};

# The percentage of frames whose build or raster took longer than $budget ms:
# a frame late on either thread is a frame the display did not get in time.
def missed_percent($build; $raster; $budget):
  if ($build | length) == 0 then null
  else [range($build | length) | select($build[.] / 1000 > $budget or $raster[.] / 1000 > $budget)]
    | length * 100 / ($build | length) | round3
  end;

# The refresh rate the frames ran at: one over the median time between the
# starts of consecutive frames (the vsyncs they were drawn for), which
# during a gesture is one display refresh. An adaptive display reports the
# rate it idles at when the app starts (a Galaxy S24 said 24 Hz), not the
# one it draws a fling at.
def vsync_hz:
  [range(1; length) as $i | .[$i] - .[$i - 1] | select(. > 0)]
  | if length == 0 then null
    else sort | (if length % 2 == 1 then .[length / 2 | floor] else (.[length / 2 - 1] + .[length / 2]) / 2 end)
      | 1000000 / . | round
    end;

def device_record($c):
  ($c.devices // {} | to_entries
    | map(select(.key == $device or "\(.value.model):\(.value.version)" == $device))
    | .[0]) as $known
  | if $known != null then
      {key: $known.key} + ($known.value | {model, version, name, platform, form})
    else
      ($device | split(":")) as $parts
      | {key: $device, model: $parts[0], version: ($parts[1] // ""), name: $parts[0],
         platform: $platform, form: $form}
    end;

$config[0] as $c
| . as $survey
| ($screens // ($c.screens | keys)) as $expected
| ($expected - ($survey.screens | keys)) as $missing
| if ($missing | length) > 0 then
    error("the walk reported no \($missing | join(", ")): a full survey walks every screen of survey.yaml")
  else . end
| device_record($c) as $d
| $c.severity as $s
| $survey.screens | to_entries[]
| .key as $screen
| .value as $v
| {
    schema: 1,
    run: $run,
    at: $at,
    commit: $commit,
    source: $source,
    device: $d,
    refresh_hz: (($v.frame_vsync_starts // [] | vsync_hz)
      // ($survey.refresh_hz | if . == null then null else round end)),
    display_hz: ($survey.refresh_hz | if . == null then null else round end),
    startup_ms: $survey.startup_ms,
    screen: $screen,
    frames: $v.frame_count,
    build_ms: ($v.frame_build_times | percentiles),
    raster_ms: ($v.frame_rasterizer_times | percentiles),
    missed_60_percent: missed_percent($v.frame_build_times; $v.frame_rasterizer_times; $s.floor_ms),
    missed_120_percent: missed_percent($v.frame_build_times; $v.frame_rasterizer_times; $s.target_ms),
    requests: ($v.requests | map(split(" ")[0]) | group_by(.) | map({key: .[0], value: length}) | from_entries)
  }
