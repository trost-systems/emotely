# The gate's verdict as Markdown: what the nightly issue and the local run
# print. Input: result.json (perf-gate.jq's output); $requests is the run's
# requests.json, slurped.

def status_cell: if . == "fail" then "**fail**" else . end;
def cell: if . == null then "—" else tostring end;

. as $result
| (if .pass then "Within budget on `\(.env)`" else "Over budget on `\(.env)`" end),
  "",
  "\($result.checks | map(select(.status == "fail")) | length) check(s) over budget, \($result.checks | map(select(.status == "warn")) | length) warning(s). Limits and baselines: `apps/mobile/app/integration_test/perf_budget.yaml`.",
  "",
  "| path | check | value | limit | status |",
  "| --- | --- | --- | --- | --- |",
  ($result.checks[] | "| \(.path | cell) | \(.check) | \(.value | cell) | \(.limit | cell) | \(.status | status_cell) |"),
  "",
  "### Requests per path",
  "",
  ($requests[0] | to_entries[]
    | "- **\(.key)**: " + (.value | group_by(.) | map("\(length) × `\(.[0])`") | join(", "))),
  "",
  "A frame check over budget: open `<path>.timeline.json` from the run in https://ui.perfetto.dev (or chrome://tracing) and look for the longest `Frame` (build) and `GPURasterizer::Draw` (raster) slices."
