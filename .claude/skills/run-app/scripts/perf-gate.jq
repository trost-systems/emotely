# The performance budget's gate: judges one profile run against the budget.
#
# Input (jq -n, everything through --slurpfile / --argjson / --arg):
#   $budget     [the budget file as JSON]
#   $runs       [{summaries: {"<path>": <flutter_driver timeline summary>},
#                 requests: {"<path>": ["<service> <METHOD> <path>", ...]}}],
#               one per run of the same commit
#   $latency    [] or [latency.json]
#   $env        the environment the runs measured on (a key of .environments)
#
# Output: {env, runs, pass, checks: [{path, check, value, limit, status}],
# requests}, where
# status is "pass", "fail", "warn" (over the 120 fps target), "under" (fewer
# requests than budgeted: pass, and lower the budget) or "reported"
# (measured, not gated).

def request_checks($path; $made; $allowed):
  ($made | map(split(" ")[0]) | group_by(.) | map({key: .[0], value: length}) | from_entries) as $counts
  | ($allowed | keys) + ($counts | keys) | unique as $services
  | $services[]
  | ($counts[.] // 0) as $value
  | ($allowed[.] // 0) as $limit
  | {
      path: $path,
      check: "requests.\(.)",
      value: $value,
      limit: $limit,
      status: (if $value > $limit then "fail" elif $value < $limit then "under" else "pass" end)
    };

def round3: . * 1000 | round / 1000;

# The 60 fps floor gates unless the environment says `floor: reported`: on
# an emulator the floor measures the host (a shared runner stalls single
# frames, and its build p90 swings 1.5x from one runner to the next), so
# only the baseline gates there.
def floor_gated($environment): $environment.floor != "reported";

# The limit of a p90: the floor, or the baseline plus the headroom when that
# is lower, so a path that is fast today cannot quietly get slower. Where
# the floor is only reported, the baseline plus the headroom alone.
def p90_limit($frames; $baseline; $floor_gated):
  if $baseline == null then $frames.floor_ms
  else ($baseline * (1 + $frames.headroom_percent / 100)) as $tightened
    | if $floor_gated then [$frames.floor_ms, $tightened] | min else $tightened end
    | round3
  end;

# Whether a frame metric gates at all. An emulator's raster thread draws
# through the host's graphics stack, so its budget can report raster
# without gating it; build always gates.
def gated($metric; $environment):
  $metric == "build" or $environment.raster != "reported";

def judged($value; $limit; $gated):
  if $gated | not then "reported" elif $value > $limit then "fail" else "pass" end;

# The share of frames, in percent, whose time on that thread misses the
# floor. The summary lists the times in microseconds.
def missed_percent($times; $floor_ms):
  if ($times | length) == 0 then 0
  else ($times | map(select(. / 1000 > $floor_ms)) | length) * 100 / ($times | length) | round3
  end;

# A path must draw enough frames for "under 1%" to allow any miss at all; a
# path with no timeline drew none.
def count_check($path; $summary; $frames):
  ($summary.frame_count // 0) as $count
  | {
      path: $path,
      check: "frames.count",
      value: $count,
      limit: $frames.min_frames,
      status: (if $count < $frames.min_frames then "fail" else "pass" end)
    };

def thread_checks($path; $summary; $frames; $environment):
  ("build", "raster") as $metric
  | (if $metric == "build" then "build" else "rasterizer" end) as $thread
  | gated($metric; $environment) as $gated
  | floor_gated($environment) as $floor
  | $environment.baseline[$path]["\($metric)_p90_ms"] as $baseline
  | $summary["90th_percentile_frame_\($thread)_time_millis"] as $p90
  | p90_limit($frames; $baseline; $floor) as $limit
  | missed_percent($summary["frame_\($thread)_times"] // []; $frames.floor_ms) as $missed
  | {
      path: $path,
      check: "\($metric).p90_ms",
      value: $p90,
      limit: $limit,
      # Without the floor and without a baseline there is nothing to hold
      # the p90 to yet.
      status: judged($p90; $limit; $gated and ($floor or $baseline != null))
    },
    # The 120 fps target: a warning until the baseline holds it, when the
    # budget makes it the floor. Only where the floor gates.
    (select($gated and $floor) | {
      path: $path,
      check: "\($metric).target_ms",
      value: $p90,
      limit: $frames.target_ms,
      status: (if $p90 > $frames.target_ms then "warn" else "pass" end)
    }),
    {
      path: $path,
      check: "\($metric).missed_percent",
      value: $missed,
      limit: $frames.max_missed_percent,
      # "Under 1%": reaching the limit already fails.
      status: (if ($gated and $floor) | not then "reported"
               elif $missed >= $frames.max_missed_percent then "fail"
               else "pass" end)
    };

def frame_checks($path; $summary; $frames; $environment):
  count_check($path; $summary; $frames),
  if $summary == null then empty else thread_checks($path; $summary; $frames; $environment) end;

# The nearest-rank 95th percentile of the samples.
def p95: sort | .[((length * 95 / 100) | ceil) - 1];

# The real backend, measured apart from the frames (`perf.sh latency`). The
# whole agent round is bound by the model: tracked, never gated.
def latency_checks($samples; $ceilings):
  ("supabase_read", "agent_first_byte", "agent_round") as $metric
  | ($samples["\($metric)_ms"] // []) as $values
  | select($values | length > 0)
  | ($values | p95) as $value
  | $ceilings["\($metric)_p95_ms"] as $limit
  | {
      path: null,
      check: "latency.\($metric)_p95_ms",
      value: $value,
      limit: $limit,
      status: judged($value; $limit; $limit != null)
    };

def median: sort | if length % 2 == 1 then .[length / 2 | floor] else (.[length / 2 - 1] + .[length / 2]) / 2 end;

# Several runs of one commit as one: each p90 is the median of the runs'
# (one slow runner is not a slow app), the frame times are pooled, and the
# frame count is the fewest any run drew. A path any run lacks is missing.
def merged_summary($path):
  [$runs[].summaries[$path]] as $all
  | if any($all[]; . == null) then null
    else {
      frame_count: ($all | map(.frame_count) | min),
      "90th_percentile_frame_build_time_millis": ($all | map(."90th_percentile_frame_build_time_millis") | median),
      "90th_percentile_frame_rasterizer_time_millis": ($all | map(."90th_percentile_frame_rasterizer_time_millis") | median),
      frame_build_times: ($all | map(.frame_build_times // []) | add),
      frame_rasterizer_times: ($all | map(.frame_rasterizer_times // []) | add)
    }
    end;

# Each path's requests as the run that made the most of them made them:
# counts are exact, so any run over budget is over budget.
def most_requests($path): [$runs[].requests[$path] // []] | max_by(length);

$budget[0] as $b
| ($b.requests | keys | map({key: ., value: most_requests(.)}) | from_entries) as $r
| ($b.requests | keys | map({key: ., value: merged_summary(.)}) | from_entries) as $s
| ($b.environments[$env] // error("no environment \"\($env)\" in the budget")) as $e
| [
    ($b.requests | to_entries[]
      | request_checks(.key; $r[.key] // []; .value)),
    ($b.requests | keys[]
      | frame_checks(.; $s[.]; $b.frames; $e)),
    ($latency[0] // empty | latency_checks(.; $b.latency))
  ] as $checks
| {
    env: $env,
    runs: ($runs | length),
    pass: ($checks | all(.status != "fail")),
    checks: $checks,
    requests: $r
  }
