# The performance survey's findings by severity (#242): a run's records,
# judged against survey.yaml's severity rules and each device's trailing
# history of the same screen. One finding per screen and metric, whatever
# the device, at the worst severity any device showed; each device's
# numbers are its observations.
#
# Input: jq -n. Arguments (--slurpfile):
#   $records   the run's records (survey-record.jq's output)
#   $history   earlier records, any device and screen
#   $config    [survey.yaml as JSON]
#
# Output: [{key: "<screen>/<metric>", screen, metric, severity,
#           observations: [{severity, value, limit, baseline, drift_percent,
#                           reason, device, refresh_hz, run, commit, at}]}]
# where metric is build_p90, raster_p90 or missed_frames.

def rank: {critical: 3, major: 2, minor: 1}[.];

def round1: . * 10 | round / 10;

def median:
  sort | if length % 2 == 1 then .[length / 2 | floor] else (.[length / 2 - 1] + .[length / 2]) / 2 end;

def value_of($metric):
  if $metric == "build_p90" then .build_ms.p90
  elif $metric == "raster_p90" then .raster_ms.p90
  else .missed_60_percent
  end;

# The metrics a device's findings may be filed on: survey.yaml's `judges`,
# else build times alone on a virtual device (it draws through its host's
# software renderer) and everything on a phone.
def judged($c):
  $c.devices[.device.key].judges
  // (if .device.form == "virtual" then ["build_p90"] else ["build_p90", "raster_p90", "missed_frames"] end);

# The trailing baseline of one record's metric: the median of the same
# device's last full surveys (source "survey") of the screen before it, or
# null while there are too few of them. Ad-hoc runs (a regression chased, a fix proved on a
# branch) are compared with it, never part of it.
def baseline($r; $metric; $s):
  [$history[]
    | select(.source == "survey")
    | select(.device.model == $r.device.model and .device.version == $r.device.version
        and .screen == $r.screen and .run != $r.run and (.frames // 0) >= $s.min_frames
        and .at < $r.at
        and (($r.at | fromdateiso8601) - (.at | fromdateiso8601)) <= $s.baseline_days * 86400)]
  | sort_by(.at) | .[-($s.baseline_runs):]
  | map(value_of($metric)) | map(select(. != null))
  | if length >= $s.min_baseline_runs then median else null end;

def observe($r; $metric; $c):
  $c.severity as $s
  | ($r | value_of($metric)) as $value
  | ($c.screens[$r.screen].gated // false) as $gated
  | (($r.refresh_hz // 0) >= $s.high_refresh_hz) as $high_refresh
  | select($value != null)
  | if $metric == "missed_frames" then
      select($value >= $s.max_missed_percent)
      | {severity: "critical", value: $value, limit: $s.max_missed_percent, baseline: null,
         drift_percent: null, reason: "\($value)% of frames over the 60 fps floor"}
    else
      baseline($r; $metric; $s) as $baseline
      | (if $baseline != null and $baseline > 0 and ($value - $baseline) >= $s.min_drift_ms
         then ($value - $baseline) / $baseline * 100 | round1 else null end) as $drift
      | {value: $value, baseline: $baseline, drift_percent: $drift}
      + if $value > $s.floor_ms then
          {severity: "critical", limit: $s.floor_ms, reason: "over the 60 fps floor"}
        elif $drift != null and $drift > $s.major_drift_percent then
          {severity: "major", limit: null, reason: "\($drift)% slower than its baseline"}
        elif $high_refresh and $gated and $value > $s.target_ms then
          {severity: "major", limit: $s.target_ms, reason: "over the 120 fps target on a main path"}
        elif $drift != null and $drift > $s.minor_drift_percent then
          {severity: "minor", limit: null, reason: "\($drift)% slower than its baseline"}
        elif $high_refresh and $value > $s.target_ms then
          {severity: "minor", limit: $s.target_ms, reason: "over the 120 fps target"}
        else empty
        end
    end
  | . + {device: $r.device, refresh_hz: $r.refresh_hz, run: $r.run, commit: $r.commit, at: $r.at};

$config[0] as $c
| [$records[]
    | select((.frames // 0) >= $c.severity.min_frames)
    | . as $r
    | judged($c)[] as $metric
    | observe($r; $metric; $c)
    | . + {screen: $r.screen, metric: $metric}]
| group_by("\(.screen)/\(.metric)")
| map({
    key: "\(.[0].screen)/\(.[0].metric)",
    screen: .[0].screen,
    metric: .[0].metric,
    severity: (max_by(.severity | rank) | .severity),
    observations: (sort_by(-(.severity | rank)) | map(del(.screen, .metric)))
  })
