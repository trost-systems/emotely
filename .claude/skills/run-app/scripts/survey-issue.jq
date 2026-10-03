# One finding of the performance survey (#242) as its issue: the name that
# identifies it across runs, the title (the severity first), the body of a
# new issue and the comment a later run adds.
#
# Input: a finding (survey-classify.jq). Arguments (--arg):
#   $tag       put before the name: keeps test issues apart from real ones
#   $run_url   the run that found it

def metric_label: {build_p90: "build p90", raster_p90: "raster p90", missed_frames: "missed frames"}[.];

def unit($metric): if $metric == "missed_frames" then " %" else " ms" end;

def device_name: "\(.name) (\(.model), \(.version))";

def against($metric):
  if .limit != null then "\(.limit)\(unit($metric)) limit"
  elif .baseline != null then "\(.baseline)\(unit($metric)) baseline, +\(.drift_percent)%"
  else "—"
  end;

def table($metric):
  "| device | value | against | severity | why |",
  "| --- | --- | --- | --- | --- |",
  (.observations[]
    | "| \(.device | device_name) | \(.value)\(unit($metric)) | \(against($metric)) | \(.severity) | \(.reason) |");

. as $f
| "\(if $tag == "" then "" else "\($tag) " end)Perf survey: \(.screen) \(.metric | metric_label)" as $name
| .observations[0].device as $worst
| "\($worst.model):\($worst.version)" as $device
| ".claude/skills/run-app/scripts/survey.sh" as $script
| (.observations | map(.commit) | unique | join(", ")) as $commits
| {
    key: .key,
    name: $name,
    title: "[\(.severity)] \($name)",
    body: ([
      "The performance survey (#242) found **\(.screen)** \(if .severity == "critical" then "below the 60 fps floor" else "slower than it should be" end): **\(.metric | metric_label)**, severity **\(.severity)**.",
      "",
      table(.metric),
      "",
      "Found by [this run](\($run_url)) on `\($commits)`. The severity rules and the devices are in `apps/mobile/app/integration_test/survey.yaml`.",
      "",
      "## Reproduce, fix, prove",
      "",
      "1. The screen's history on this device: `\($script) history --device \($device) --screen \(.screen)`.",
      "2. The same screen on the same Test Lab device, alone (one of the day's physical runs): `\($script) ftl --device \($device) --screens \(.screen)`.",
      "3. Find the hot spot in a timeline (`perf.sh run --device <phone>`, or Perfetto), and fix it.",
      "4. Run step 2 on the fix's branch and compare its numbers with step 1; the pull request quotes both and closes this issue.",
      "",
      "Every later survey run that still finds this comments here, and the title carries the worst severity of the latest run.",
      "",
      "<!-- perf-survey: \(.key) -->"
    ] | join("\n")),
    comment: ([
      "[This run](\($run_url)) on `\($commits)`: **\(.severity)**.",
      "",
      table(.metric)
    ] | join("\n"))
  }
