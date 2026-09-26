# The performance budget: measure, judge, fix

`scripts/perf.sh` runs the app's three main paths in **profile mode** and
judges them against `apps/mobile/app/integration_test/perf_budget.yaml`. The
nightly workflow (`.github/workflows/nightly-perf.yml`) runs the same thing
and opens an issue labelled `performance` when a path goes over budget.

```bash
S=.claude/skills/run-app/scripts/perf.sh
$S run                      # fresh headless Android emulator, then gone again
$S run --latency            # plus the deployed backend, as the smoke account
$S run --device <id>        # a phone (`fvm flutter devices`) or a running emulator
$S gate <run dir> --env local-emulator   # judge a run again after editing the budget
$S baseline <run dir>...    # a new baseline from several runs
$S down                     # clean up after a run that crashed
```

A run takes about four minutes: the emulator boots, a profile build, then
the paths. It exits 0 within budget, 1 over it, 2 when the run itself broke
(the step is named). The run directory (`apps/mobile/app/build/perf/<time>/`
by default) holds:

- `summary.md`: the verdict, every check with its value and limit, and each
  path's requests;
- `result.json`: the same as data;
- `<path>.timeline.json`: the whole trace, for https://ui.perfetto.dev or
  `chrome://tracing`;
- `<path>.timeline_summary.json`: frame build and raster times;
- `requests.json`: each path's requests, in order;
- `latency.json` with `--latency`; `drive.log` always.

## What is measured, and against what

- **Paths** (`integration_test/perf_test.dart`): launch onto a journal of
  300 made-up entries and fling it to the end and back three times; open an
  entry and go back, eight times; start a session and answer eight
  questions. Each repeats until it draws a few hundred frames.
- **The backend is fake and in the process** (`integration_test/perf/`):
  the production graph (`registerApp`) over one fake http client. Frames
  measure the app, not a connection, and the request counts are exact.
  Nothing touches the smoke account or the network.
- **Frames**: p90 build and p90 raster at most 16.7 ms (60 fps), and under
  1% of frames over it. A baseline tightens this: each limit is the lower
  of 16.7 ms and the environment's baseline plus 20%. Over 8.3 ms (120 fps)
  is a warning.
- **Requests**: the count per path and service. Any increase fails; a
  decrease passes and asks for a lower number in the budget.
- **Latency** (`--latency`, and nightly): 20 Supabase reads and 5 agent first
  rounds from this machine, as the smoke account. p95 of the reads at most
  1 s, of the agent's first byte at most 5 s; the whole round is tracked,
  not gated. It takes the smoke account's lock like `run-app.sh up`, so it
  fails at once while another session holds the account: wait and retry.

## Environments

The budget judges a run by where it measured (`--env`):

| env | where | raster, missed frames |
| --- | --- | --- |
| `github-emulator` | the nightly: ubuntu runner, x86_64 emulator, software rendering | reported |
| `local-emulator` | `perf.sh run`: arm64 emulator, host GPU (baseline from an Apple M4 Pro) | reported |
| `device` | `perf.sh run --device <phone>` | gated |

On an emulator, raster time is the host's graphics stack (a 16.7 ms swap
locally, 80-170 ms of software rendering on the runner), and a shared host
stalls single frames now and then, which alone breaks "under 1% missed".
Both are reported there and never gated. Build p90 against the baseline
and the request counts gate everywhere; a phone gates the whole floor. Flutter runs only debug builds on the iOS
simulator, so there is no iOS emulator environment. A phone gets the
profile build installed over whatever emotely build is on it: never use
someone's personal phone without asking.

## A run went over budget

1. Read `summary.md`: which path, which check, by how much.
2. **Requests**: the path's request list shows the extra one. Find the
   caller: usually a bloc that loads twice, or a list that reads per row.
3. **Frames**: open the path's `.timeline.json` in Perfetto and find the
   longest `Frame` slices (build, UI thread) or `GPURasterizer::Draw`
   (raster). The slice's children name the widget or layout that cost it.
4. Fix, then `perf.sh run` again until it is within budget.

## Changing the budget

The budget is code: a pull request that changes it says why. A path that
got cheaper for good gets a lower count or a new baseline; one that must
cost more (a new request by design) says what it buys.

- **A new baseline**: at least five runs on the same environment, then
  `perf.sh baseline <run dir>...` prints each path's slowest p90, which is
  the baseline. For `github-emulator`, run five side by side with
  `gh workflow run nightly-perf.yml -f samples='[1,2,3,4,5]'`, then
  `gh run download <run id>` fetches their `perf-run-N` artifacts.
- **A new path** is a method in `PerfPaths`, a `measure` call and its
  request counts in the budget.
- **120 fps as the gate**: once every baseline holds 8.3 ms, set
  `floor_ms: 8.3`.
