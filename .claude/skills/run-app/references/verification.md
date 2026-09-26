# Verify on the simulator: up → drive → collect → down

`.claude/skills/run-app/scripts/run-app.sh` sets the app up and collects the
evidence; you drive it in between with plain `marionette` commands. Run
`run-app.sh help` first: it prints the CLI's usage followed by marionette's
own reference (`marionette help-ai`).

1. **Up.** `run-app.sh up` builds a debug app, creates and boots a fresh iOS
   simulator for this session, launches the app with `flutter run` against
   the deployed agent, registers it with marionette and signs in as the
   smoke account. It ends on the signed-in journal and prints the
   **instance** and the **bundle**:

   ```
   session   agent-a01f-3fa9c2
   instance  emotely-agent-a01f-3fa9c2
   device    <udid>
   bundle    …/apps/mobile/app/build/evidence/20260925-101500
   drive     marionette -i emotely-agent-a01f-3fa9c2 get-interactive-elements
   ```

   About three minutes (build, boot, sign-in). `run-app.sh status` prints the
   same again. Attach the Claude Code iOS Simulator panel to the device to
   watch. Any command that fails exits non-zero and names its step
   (`preflight`, `claim`, `credentials`, `build`, `simulator`, `launch`,
   `register`, `sign-in`, …).
2. **Drive** with `marionette -i <instance> <command>`. Look before acting:
   `get-interactive-elements` lists what is on screen with its keys. Match by
   **key** first (`--key journal_view.start`), by visible `--text` only where a
   widget has none, and never by coordinates: a widget the task needs gets a
   `Key('<screen>.<thing>')` like its neighbours. Marionette taps the centre
   of what a key names, so the key belongs on the tappable widget itself (see
   `SubmitButton.buttonKey`), never on a full-width row around it. A model
   round takes a few seconds: poll `get-interactive-elements` until the next
   key shows up. Screenshots go into the bundle:
   `take-screenshots --output <bundle>/NN-<name>.png`. For video, wrap the
   part worth watching in `run-app.sh record start` / `record stop`.
3. **Collect.** `run-app.sh collect` stops a running recording and writes
   `app.log` (marionette `get-logs`: every `debugPrint`),
   `posthog-events.json` (the smoke user's events since `up`, `$`
   properties dropped) and `summary.json`, next to `flutter-run.log` and your
   screenshots, plus the copies to post (below) in `<bundle>/post/`. It
   briefly backgrounds the app so PostHog flushes (up to two and a half
   minutes while events arrive), then brings it back; drive on and collect
   again if you need to.
4. **Down.** `run-app.sh down` stops the app, unregisters the instance,
   deletes the session's simulator and frees the smoke account. The bundle
   stays.

`up --skip-build` reuses the last `Runner.app` that `up` built in this
checkout.

## Worked example: start a session and answer the first question

```bash
S=.claude/skills/run-app/scripts/run-app.sh
$S up                                   # prints instance and bundle
I=emotely-agent-a01f-3fa9c2             # from up's output
B=/…/build/evidence/20260925-101500     # from up's output
m() { marionette -i "$I" "$@"; }

$S record start
m get-interactive-elements              # a leftover session shows journal_view.discard
m tap --key journal_view.discard        # only if it is there
m take-screenshots --output "$B/01-journal.png"
m tap --key journal_view.start
# The consent screen, only while the smoke account's consent is missing or
# out of date: m scroll-to --key consent_view.checkbox; m tap --key
# consent_view.checkbox; m scroll-to --key consent_view.agree; m tap --key
# consent_view.agree
m get-interactive-elements              # repeat until session_view.question shows
m take-screenshots --output "$B/02-first-question.png"
# The keys tell the kind of question; this one was a text list:
m enter-text --key text_list_input.field.0 --input "Made-up item one"
m enter-text --key text_list_input.field.1 --input "Made-up item two"
m tap --key text_list_input.submit
m get-interactive-elements              # repeat until Text: "Question 2" shows
m take-screenshots --output "$B/03-second-question.png"
m press-back-button                     # leave no open session behind
m get-interactive-elements              # repeat until journal_view.discard shows
m tap --key journal_view.discard
$S collect                              # also stops the recording
$S down
```

The other kinds: `longtext_input.field` then `longtext_input.submit`;
`tap --key rating_input.slider` (its centre is a 5) then
`rating_input.submit`; `emoji_input.slot.0`, `tap --text 😊` (the
third-party picker has no keys) then `emoji_input.submit`;
`color_input.slot.0`, `color_input.select` then `color_input.submit`.
Discard what you open: the nightly live smoke starts a new session and fails
on an unfinished one.

## Posting evidence to a pull request or issue

Post the copies in `<bundle>/post/`, never the originals, which stay in the
bundle:

- **Screenshots**: `collect` writes each at 600 px wide. Show them at
  300 px: full size is huge in a pull request, and 600 px keeps them sharp
  on a 2x screen. Markdown has no width, so use an `<img>` tag.
- **Video**: `record stop` and `collect` write `video-4x.mp4`, four times
  faster than real time, since an agent spends most of a recording between
  actions. H.264 in MP4 is what GitHub recommends for inline playback (WebM
  does not play in every browser), with no audio, 15 fps and 600 px wide,
  so it stays well under the 10 MB video limit. `--speed 2` or `--speed 1`
  on either command writes `video-2x.mp4` / `video-1x.mp4` instead.

`--attach` (gh 2.99+, on `gh pr create|edit` and `gh issue create|comment`)
rewrites only a Markdown `![alt](path)` reference into the uploaded URL. An
`<img src="path">` tag or a bare video path stays as written and the file is
appended at the end (gh 2.100.0, checked on #180). So upload first, then
write the tags with the URLs:

```bash
P=<bundle>/post
gh pr edit <n> --attach "$P/01-journal.png" --attach "$P/02-first-question.png" \
  --attach "$P/video-4x.mp4"
gh pr view <n> --json body -q .body | grep -o 'https://github.com/user-attachments/assets/[^)]*'
```

The URLs come back in upload order. Rewrite the body with `gh pr edit <n>
--body-file`, dropping the appended lines: the screenshots side by side on
one line as `<img src="<url>" width="300" alt="<what it shows>">`, and the
video's URL alone on its own line, which GitHub renders as a player.

## Privacy

The repository and its attachments are public (ADR 0005). `up` signs in only
as the smoke account from `apps/agent/.env.local` (read blind, from the main
checkout when run in a worktree), refuses an address whose domain is not in
`SMOKE_EMAIL_DOMAINS`, and signs in before any recording. `collect` scrubs
the smoke address, password and user id from every text file in the
bundle. What you type is yours to keep clean: made-up content only, and say
so. Never sign in as anyone else on a driven app.

**Your own smoke account.** Contributors bring their own: an address whose
inbox you, and the agents you run, can read, so a flow that sends mail can
be verified end to end. Put `SMOKE_EMAIL`, `SMOKE_PASSWORD` and
`SMOKE_EMAIL_DOMAINS` (its domain, comma-separated if more than one) in
`apps/agent/.env.local`. Inside emotely that is an address on
`getemotely.com`. Reading the inbox from the CLI is #186.

## Parallel sessions

Several agent sessions on one machine can each run the CLI:

- **Parallel-safe**: every `up` creates its own simulator and marionette
  instance, both named `emotely-<checkout>-<random>`, and `down` deletes and
  unregisters them. State, the build and the bundle live in the checkout.
  The VM service, DDS and the video stream take ports the OS assigns;
  marionette keeps one registry file per instance; Flutter and CocoaPods
  lock their own caches.
- **One at a time**: one session per checkout, and one per smoke account.
  Two sessions on one account would collide on its server state (an open
  session, consent) and `collect` could not tell their PostHog events
  apart, so `up` takes a machine-wide lock on the account
  (`~/.local/state/emotely/run-app/`). A second `up` fails at once and names
  the checkout that holds it. The lock follows the session's `flutter run`:
  when that process is gone, the lock is stale and the next `up` takes it.
  Truly parallel runs come with per-run users (#185) on plus-addresses of
  the smoke inbox (#186).

## How it fits together

`main.dart` initialises `MarionetteBinding` only under `kDebugMode`, so
profile and release builds never contain it. The debug build carries
`SMOKE_EMAIL`, which makes the sign-in screen ask that one account for a
password instead of a code; that workaround goes with email + password
sign-in (#187). The installed `marionette_cli` must match the app's
`marionette_flutter` version; `up`'s preflight says which to activate.
