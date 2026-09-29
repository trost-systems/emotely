# The performance survey: real phones, a history, findings by severity

`scripts/survey.sh` walks every screen of the feature map in profile mode on
real phones in Firebase Test Lab, keeps each run's numbers in a history, and
files findings as one issue per screen and metric, by severity (#242). The
performance budget (`perf.sh`, [performance.md](performance.md)) is the
emulator gate on three paths; this is the survey of the whole app on the
phones users have, to pull up when making a screen faster.

```bash
S=.claude/skills/run-app/scripts/survey.sh
$S ftl --device galaxy-s24                      # the whole walk, one Test Lab phone
$S ftl --device SC-51E:36 --screens journal     # one screen, any <model>:<version>
$S local --device emulator-5554                 # the same walk on a device here
$S history --device a14m --screen journal       # the last 30 days, one command
$S history --device galaxy-s24 --days 90 --json | jq -s 'map(.build_ms.p90)'
```

## Test Lab, and what it costs

- **Project `emotely-ci`**, Spark plan, no billing account: nothing can cost
  money. **5 physical and 10 virtual test runs a day**, shared by every run
  in the project, scheduled or ad hoc. One device of one run is one test
  run, whether it passes or not.
- **Locally, gcloud for emotely always runs as `CLOUDSDK_CONFIG=$HOME/.config/emotely/gcloud`.**
  The default configuration belongs to another organisation; `survey.sh`
  uses the emotely one by itself and refuses to run without it.
- **In CI, sign-in is keyless**: Workload Identity Federation (pool
  `github`, provider `emotely`) into `ftl-runner@emotely-ci.iam.gserviceaccount.com`,
  which holds Test Lab admin and analytics viewer only. The repository
  variables are `FTL_PROJECT_ID`, `FTL_WORKLOAD_IDENTITY_PROVIDER` and
  `FTL_SERVICE_ACCOUNT`.
- The results land in the project's default bucket
  (`gs://test-lab-da5r8r2b0t3mw-ii9dsjb3i5fn4/survey/<run>/`): the device
  log, the test result, and `survey.json`.

## The device matrix and the quota

`apps/mobile/app/integration_test/survey.yaml` lists the phones and when the
nightly (`.github/workflows/perf-survey.yml`, 05:30 UTC) runs each:

| device | Test Lab id | why | nightly | physical runs |
| --- | --- | --- | --- | --- |
| Galaxy S24 | `SC-51E:36` | 120 Hz Android flagship | daily | 1 |
| Galaxy A14 | `a14m:34` | low-end Android, 60/90 Hz | Monday, Thursday | +1 |
| iPhone 16 Pro | `iphone16pro:18.3` | 120 Hz iPhone | not yet (iOS, below) | +1 once on |
| Medium Phone | `MediumPhone.arm:34` | virtual, for trying things | never | virtual |

That is **1 physical run a day, 2 on Mondays and Thursdays** (with the
iPhone, 2 and 3): at least 2 of the 5 always stay for an agent chasing a
regression. `survey.test.sh` fails a matrix that would leave fewer. Iterate
on the virtual device; a physical run is for a number that matters.

## What a run measures

`integration_test/survey_test.dart` composes the app over the budget's
in-process fake backend (made-up content, ADR 0005), launches it signed in,
then walks each screen (`survey/survey_walk.dart`) with a gesture repeated
until it draws a few hundred frames. Per screen it records, from the
engine's own `FrameTiming`s (Test Lab runs the test with no host, so no
timeline):

- **build and raster p50/p90/p99** in milliseconds;
- **missed frames at 60 Hz and 120 Hz**: the share of frames whose build
  or raster took longer than 16.7 ms or 8.3 ms;
- **the refresh rate the frames ran at**, from the time between their
  vsyncs (an adaptive display reports its idle rate: the S24 said 24 Hz);
- **requests** per service, against the fake backend, so exact;
- **startup**: from the app's first widget to the journal's newest entry
  on screen, inside the process.

On Test Lab the walk writes `survey.json` to the device (Android: the app's
external files directory; iOS: its Documents) and logs it in numbered
chunks as well; `survey.sh ftl` pulls the file, or puts it back together
from the device log (`survey.sh from-log`) when Test Lab pulled nothing.

## The history

Every run's records, one JSON object per line, in `survey.jsonl` on the
branch **`perf-survey`** (written by the workflow through the API, with the
same `vercel.json` files as the `status` branch so that it deploys nothing).
A record is one screen of one run on one device:

```json
{"run": "…", "at": "2026-09-30T05:41:02Z", "commit": "abc1234", "source": "nightly",
 "device": {"key": "galaxy-s24", "model": "SC-51E", "version": "36", "name": "Galaxy S24",
            "platform": "android", "form": "physical"},
 "refresh_hz": 120, "display_hz": 24, "startup_ms": 151, "screen": "journal", "frames": 2151,
 "build_ms": {"p50": 1.063, "p90": 2.434, "p99": 3.369}, "raster_ms": {"p50": 2.686, "p90": 3.079, "p99": 3.511},
 "missed_60_percent": 0, "missed_120_percent": 0.046, "requests": {"supabase": 2}}
```

`survey.sh history` narrows it (`--device` matches key, model, name or
`<model>:<version>`, any part, any case; `--screen`; `--days`, 30 by
default) and prints a table, or the records with `--json`. Without
`gh`: `gh api -H 'Accept: application/vnd.github.raw+json'
'repos/trost-systems/emotely/contents/survey.jsonl?ref=perf-survey' | jq -s …`.

## Severity

`survey.sh classify` judges a run against `survey.yaml`'s rules and each
device's **trailing baseline**: the median of that device's last 7 nightly
runs of the screen within 30 days, once there are 3. Ad-hoc runs are
compared with the baseline, never part of it.

- **critical**: below the 60 fps floor on any device: a p90 over 16.7 ms,
  or 1% of frames or more over it;
- **major**: more than 20% slower than the baseline, or over 8.3 ms on a
  120 Hz device on a main path (journal, entry, session);
- **minor**: 10-20% slower than the baseline, or over 8.3 ms on a 120 Hz
  device on any other screen.

A drift also has to be 0.5 ms or more: 20% of a 1 ms build is noise. A
screen that drew fewer than 60 frames is recorded, not judged. A virtual
device judges build times only (its raster is its host's software
renderer).

**One issue per screen and metric** (build p90, raster p90, missed frames),
whatever the device, titled `[<severity>] Perf survey: <screen> <metric>`.
A later run that finds it again comments its numbers and retitles the issue
when the severity changed; it never files a second one. No labels. The
nightly files; an ad-hoc run files only when given a tag
(`workflow_dispatch -f issue_tag='[test]'`), which keeps its issues apart.

## Chasing a finding

1. Pick the worst: `gh issue list --search 'Perf survey in:title' --state open`,
   critical before major before minor.
2. Its history on the device it names: `survey.sh history --device <id> --screen <screen>`.
3. Reproduce it on the same Test Lab device, that screen alone (one of the
   day's physical runs): `survey.sh ftl --device <id> --screens <screen>`,
   or `gh workflow run perf-survey.yml -f device=<id> -f screens=<screen>`.
4. Find the hot spot: a timeline from `perf.sh run --device <phone>` in
   Perfetto, or the frame times in the run's `survey.json`.
5. Fix it, and run step 3 on the fix's branch. The pull request quotes the
   history and the new numbers and closes the issue.

## iOS

The walk runs and passes on the iPhone 16 Pro in Test Lab (run
`matrix-1bm9e4zytbfda`, 2026-09-29, 9.5 minutes, `survey.json` written to
the app's Documents), and the XCTest bundle is built and signed without a
human:

- `survey.sh build ios --profile <.mobileprovision>` builds the walk for
  devices unsigned, then signs the app, its frameworks and its test bundle
  with the certificate match's **App Store** profile names (Test Lab
  re-signs everything with its own; no development profile, no registered
  device). In CI the `ios survey_signing` fastlane lane installs match's
  certificate and profile (the `release` environment, so main only) and
  hands the profile's path over as `SURVEY_PROFILE`.
- Under Test Lab's XCTest runner the app has no `HOME`: the walk finds its
  container through Darwin's per-app temporary directory instead.

**The gap:** Test Lab did not pull `de.emotely.emotely:/Documents/survey`
back, although the matrix carried the pull directory. The walk now also
logs `survey.json` in chunks, which the always-kept `syslog.txt` holds,
and `survey.sh ftl` falls back to it (verified end to end on Android's
logcat, not yet on an iPhone). To finish: one physical run,
`gh workflow run perf-survey.yml --ref main -f device=iphone-16-pro`; if it
records, set the iPhone's `nightly: daily` in `survey.yaml`.
