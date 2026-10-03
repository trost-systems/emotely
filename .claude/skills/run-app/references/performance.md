# The performance budget: measure, judge, fix

The budget is `apps/mobile/app/integration_test/perf_budget.yaml`, and three
things hold the app to it:

| what | where | when | blocks |
| --- | --- | --- | --- |
| **Request counts** | `apps/mobile/app/test/perf/request_budget_test.dart`, a widget test in the app's `melos run test` | every app pull request, about a second | yes, through `ci-ok` |
| **Frames and latency** | `.github/workflows/nightly-perf.yml`: `perf.sh run` in profile mode on three emulators, then the deployed backend's latency | nightly (and `gh workflow run`) | never: anything that fails opens or comments on the one issue labeled `performance` |
| **Frames on a real phone** | `.github/workflows/perf-survey.yml`: `survey.sh`, every screen on Firebase Test Lab phones, kept in a history; read [performance-survey.md](performance-survey.md) | on demand: `gh workflow run perf-survey.yml --ref main` for a full survey of the default phones, or one device and screen; no schedule | never: a full survey's findings open or comment on one issue per screen and metric, by severity |

`scripts/perf.sh` is the profile run, the same one the nightly runs, for an
agent to measure frames locally. It also reports the request counts.

## On every pull request: the request counts

`test/perf/request_budget_test.dart` drives the same three paths as the
profile run (`integration_test/perf/perf_paths.dart`), over the same fake
backend, in an ordinary `testWidgets`. It holds each path's requests per
service to `requests:` in the budget file, exactly: a new request fails, and
so does one that went away, which asks for the lower number in the same pull
request. The failure lists every request the path made, in order. Run it
alone with the very_good_cli MCP `test` tool, `paths:
["test/perf/request_budget_test.dart"]`, in `apps/mobile/app`.

It reads the counts from the YAML (package:yaml), the file the nightly's gate
reads too, so they are written down once. Its journal holds 50 entries, not
300: a larger payload makes Supabase decode on an isolate, which a widget
test's fake clock never lets finish, and the journal is one request at any
length.

## The profile run: frames, and the nightly

```bash
S=.claude/skills/run-app/scripts/perf.sh
$S run                      # fresh headless Android emulator, then gone again
$S run --latency            # plus the deployed backend, as the probe's account
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

- **Paths** (`integration_test/perf/perf_paths.dart`, traced by
  `integration_test/perf_test.dart`): launch onto a journal of 300 made-up
  entries and fling it to the end and back; open an entry and go back, 12
  times; start a session and answer 16 questions. Each draws several hundred
  frames.
- **The backend is fake and in the process** (`integration_test/perf/`):
  the production graph (`registerApp`) over one fake http client. Frames
  measure the app, not a connection, and the request counts are exact.
  Nothing touches the smoke account or the network.
- **Frames**: p90 build and p90 raster at most 16.7 ms (60 fps), and under
  1% of frames over it. A baseline tightens this: each limit is the lower
  of 16.7 ms and the environment's baseline plus 20%. Over 8.3 ms (120 fps)
  is a warning. An emulator gates less (Environments, below).
- **Requests**: the count per path and service. On a pull request the widget
  test above holds them exactly. The profile run judges them too: any
  increase fails, and a decrease passes and asks for a lower number in the
  budget. `session_round`'s Supabase count includes one profile read for
  the whole session (#264), not one per agent round.
- **Latency** (`--latency`, and nightly): 20 Supabase reads and 5 agent first
  rounds from this machine, as the probe's account. p95 of the reads at most
  1 s, of the agent's first byte at most 5 s; the whole round is tracked,
  not gated. It takes that account's lock like `run-app.sh up` takes the
  smoke account's, so it fails at once while another run holds it: wait and
  retry.
- **The probe's account** is the Google service account
  `signin-probe@emotely-ci.iam.gserviceaccount.com`, signed in through
  Auth's ID-token grant, which the auth captcha (#94) does not check; a
  password grant would need a human check (#304, ADR 0008). The nightly gets
  its ID token keyless from GitHub (`PROBE_ID_TOKEN`). Locally `perf.sh`
  mints one with the gcloud config in `~/.config/emotely/gcloud`, whose
  account needs `roles/iam.serviceAccountOpenIdTokenCreator` on that service
  account (Peter's has it); without it, `--latency` fails naming both.

## Environments

The budget judges a run by where it measured (`--env`):

| env | where | what gates |
| --- | --- | --- |
| `github-emulator` | the nightly: three ubuntu runners, x86_64 emulator, software rendering | requests, the median build p90 against the runner's baseline plus 20% |
| `local-emulator` | `perf.sh run`: arm64 emulator, host GPU | requests; frames reported |
| `device` | `perf.sh run --device <phone>` | requests, the whole 60 fps floor, raster included |

On an emulator the 60 fps floor measures the host, not the app, so the
budget marks it `floor: reported` there: raster is the host's graphics
stack (a 16.7 ms swap locally, 65-170 ms of software rendering on the
runner), a shared host stalls single frames (the runner missed 1.5-11%),
and the runner's build p90 swings 1.6x from one runner to the next, up to
17.8 ms. So the nightly samples three runners and holds their median to
the baseline plus 20%. Locally, other sessions' builds move the build p90
more than any headroom allows (2.5 to 5.0 ms on the same commit), so a
local run reports frames and gates only the request counts: to check a
frame change locally, compare it with a run of `main` made just before, or
let the runners judge it with `gh workflow run nightly-perf.yml --ref
<branch>`. Pull requests never run this workflow.

The nightly notifies; it does not block. Whatever fails opens or comments on
the one open issue labeled `performance`, titled "Performance budget
exceeded", and says which part failed:
- a check over budget: frames, request counts or latency;
- a profile run that broke (the other samples are still judged);
- a latency probe that broke;
- the gate itself.

Flutter runs only debug builds on the iOS simulator, so there is no iOS
emulator environment. A phone gets the profile build installed over
whatever emotely build is on it: never use someone's personal phone
without asking.

## A run went over budget

1. Read `summary.md`: which path, which check, by how much.
2. **Requests**: the path's request list shows the extra one (the widget
   test's failure prints it too). Find the caller: usually a bloc that loads
   twice, or a list that reads per row. The widget test reproduces it in
   seconds, without an emulator.
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
- **A new path** is a method in `PerfPaths`, a `record` call in both
  drivers (`perf_test.dart` and the widget test) and its request counts in
  the budget.
- **120 fps as the gate**: once every baseline holds 8.3 ms, set
  `floor_ms: 8.3`.
