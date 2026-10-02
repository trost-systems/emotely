# Store releases run through fastlane, signed by match, from GitHub Actions

Shipping to TestFlight and to Play must be something an agent runs end to end
(`CLAUDE.md`), with the human only ever touching the store dashboards. That
rules out the two things Apple signing usually needs: an Apple ID logged into
Xcode, and a certificate exported by hand from someone's keychain.

## The pieces

- **fastlane** (`apps/app/fastlane`, pinned in `apps/app/Gemfile`) is the one
  entry point: `ios certificates`, `ios beta`, `android beta`. It wraps
  `flutter build ipa` / `flutter build appbundle` and the two store uploads.
- **match** holds the App Store certificate and provisioning profile,
  encrypted, in the private repo `trost-systems/emotely-certificates`. It mints
  them through the **App Store Connect API key** (`emotely CI`, Admin, key ID
  `8S5G6UTCKM` on team `VCZSHMZY25`) — so no Apple ID, no 2FA, ever. The
  Matchfile is `readonly(true)`; only the `certificates` lane may write.
- **Android** signs with the legacy upload keystore (Play App Signing holds
  the real signing key). CI writes `android/key.properties` and the keystore
  from secrets; without them a release build falls back to the debug key so
  `flutter run --release` works on a dev machine.
- **GitHub Actions** (`.github/workflows/app-release.yml`) runs both lanes in
  the `release` environment on every merge to `main` that touches the app
  (continuous delivery: `main` is already gated by `ci-ok`), and on
  `workflow_dispatch`. The build number is `1000 + run_number`: monotonic,
  and above anything the legacy app ever shipped (ADR 0012). iOS builds on
  `macos-26`, because App Store Connect rejects anything below the iOS 26 SDK.

## Secrets (environment `release`)

`APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
`APP_STORE_CONNECT_API_KEY_P8`, `MATCH_PASSWORD`, `MATCH_DEPLOY_KEY` (write
deploy key of the certificates repo), `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEY_PROPERTIES`, `PLAY_SERVICE_ACCOUNT_JSON`, `POSTHOG_KEY`.
Since 2026-10 also `APP_REVIEW_DEMO_PASSWORD` and `APP_REVIEW_CONTACT_PHONE`,
the parts of the App Review information that stay out of the repository.
The human-readable copies live in the login keychain on the dev Mac
(`emotely_*` items) — never in the repo, never in chat.

## Amendment 2026-09-19: every build reaches the beta testers

The lanes now distribute, not just upload (#127). `ios beta` hands each build
to the external TestFlight group `Beta` (the internal `Team` group has
access to all builds by itself; naming it is rejected by Apple); `android
beta` uploads to `internal` and then promotes that same version code to the
closed track `alpha`. Outside testers were the reason: an external TestFlight
group and a closed Play track are the only ways to reach someone who is not
in the App Store Connect team or on an internal list, and assigning each
build by hand in two consoles is exactly the human step this ADR removes.

It costs time, not reliability. `distribute_external` cannot skip Apple's
build processing, so the macos-26 job now waits the 10–30 min it used to
return before — that wait is inside the run, which is what makes the job
slower. Two more waits outlast the workflow without failing it: the first
build of a version goes through Beta App Review, and Google reviews every
closed-testing release. Android takes two `upload_to_play_store` calls
rather than one, because supply ignores `track_promote_to` on any run that
uploaded a binary — the promotion has to be its own, binary-free edit.

## Amendment 2026-09-20: merges stay internal; the beta is a manual promotion

The 2026-09-19 model — every merge straight to the outside testers — met
Apple's review queue on day one. Apple accepts one Beta App Review
submission per version at a time, pilot submits every build (and does so
*before* it assigns groups), so the second merge after #127 failed with
*"Another build in the same train is already in beta review"*, reached
nobody outside `Team`, and would have failed every merge until Apple
approved the first build, typically a day or two. Underneath that was a
second problem: with a merge every few hours, every-merge-to-testers means
a notification every few hours and a half-finished build in testers' hands
whenever iteration is fast.

So the pipeline has two stages. **Every merge uploads to the internal stage
only**: `ios internal` puts the build on TestFlight where the `Team` group
picks it up by itself (no groups, no submission, and pilot returns as soon
as the build appears instead of waiting for processing); `android internal`
uploads to the Play `internal` track. **The beta is a `workflow_dispatch`
run** that builds nothing: `ios beta` submits the newest processed build
(or the `build_number` input) for Beta App Review and hands it to the
external group `Beta`; `android beta` promotes the internal release to the
closed track `alpha`. Both are store API calls on Linux. `ios beta` refuses
while a build of the version is still in review — better a red manual run
that names the blocking build than pilot's `reject_build_waiting_for_review`,
which expires the reviewed build and restarts the review — and does nothing
if `Beta` already has the build, so a rerun never re-notifies.

Deferred, not rejected: triggering the beta promotion from Apple's
`BUILD_BETA_DETAIL_EXTERNAL_BUILD_STATE_UPDATED` webhook once a review
clears. Apple cannot call GitHub directly, so it needs an HMAC-verifying
relay and a GitHub token; with a human deciding when the beta ships, there
is nothing for it to trigger yet. Tracked in #144.

## What we rejected

- **Xcode cloud-managed signing** (`-allowProvisioningUpdates` with the API
  key) needs fewer secrets but hides the certificate inside Xcode's behavior,
  and Flutter's `build ipa` does not pass the authentication flags through.
  match keeps the material inspectable and portable to any machine.
- **Exporting the existing distribution certificate** from the dev keychain
  into CI: a manual, unrepeatable step, exactly what this ADR removes.
