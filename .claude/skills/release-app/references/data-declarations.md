# Store data declarations

App Store Connect (App Privacy) and Play Console (Data safety) each ask which
data types the app collects, and a reviewer compares the answers with the
notice at `https://getemotely.com/app-privacy`.

**Play Data safety lives in the repository**:
`apps/mobile/app/fastlane/data_safety.csv`, the file the Play Console's
**App content → Data safety → Export to CSV** produces. A change merged to
`main` is written to Play by the `play-data-safety` workflow (`fastlane
android data_safety`, `POST applications/{pkg}/dataSafety`), and the upload
**replaces every answer**: change the CSV, never the form. Until the first
export is committed, the workflow skips with a notice and the form below is
still the truth. The tables in this file describe what the CSV must say;
when they and the CSV disagree, the CSV is what Play has.

App Store Connect's App Privacy has no API for an API key and stays a form.
Its answers belong in `apps/mobile/app/fastlane/console/app_privacy_details.json`
(not yet created), and the store-consoles skill is how an agent puts them
into the console. **App Store Connect needs Peter signed in** in that
Chrome profile: a signed-out session is his to sign in to, never the
agent's. Play Console stays signed in.

## What is declared

As corrected on 2026-09-15: seven types, everything **Linked** to the user,
and **no tracking** — contact info (email), user content (the journal),
identifiers (user id and the analytics library's device id), usage data,
diagnostics.

Google sign-in (#51) added a **name**: Google's ID token carries the
account's name and a profile picture link, and Supabase stores both with the
sign-in record. Since #204 the app also asks for a name itself and greets
the user by it. Both consoles declare it, as changed on 2026-09-27:

- ASC **Contact Info → Name**: Linked, **App Functionality and Product
  Personalization**, no tracking (published).
- Play **Data safety → Personal info → Name**: collected, not shared,
  optional, **App functionality, Personalization, Account management**
  (sent for review).

The picture link is a URL on Google's servers, not a photo the app holds, and
needs no category of its own.

Play Data safety as of 2026-09-27, after the onboarding additions (no data
shared):

| Data type | Required? | Purposes |
| --- | --- | --- |
| Name | optional | App functionality, Personalization, Account management |
| Email address | required | App functionality, Account management |
| User IDs | required | App functionality, Analytics, Account management |
| App interactions | required | Analytics |
| Crash logs | required | Analytics |
| Diagnostics | required | Analytics |
| Other user-generated content | — | App functionality |
| Device or other IDs | declared | (not re-read on 2026-09-27) |

## Changes for the onboarding build (#204)

The onboarding build asks for a name, greets the user by it, sends it to
the model provider with each session round, and sets PostHog up only after
the user taps Allow on first launch (ADR 0004 amendment, ADR 0019). Two
kinds of change follow, and they are due at different times.

**When.** Play: "Your Data safety section describes the sum of your app's
data collection and sharing across all its versions currently distributed on
Google Play", and "Your Data safety form responses must remain accurate and
complete at all times"
([Play Console Help, Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)).
Every merge to `main` puts a build on the Play `internal` track, and a track
is distribution on Google Play (our reading), so:

- **Additions are due as soon as any track carries the onboarding build**:
  the name's new purposes. Declaring them early is harmless, since the older
  builds collect less.
- **Relaxations wait until no distributed version still collects without
  asking**: analytics becomes optional only once every track, production
  included, carries a consent-gated build. Before that the older builds
  still collect it for everyone, and "optional" would misdescribe them.

App Store Connect has one label per app, shown on the product page: change it
with the App Store submission of the consent-gated build, not before.

**Status (2026-09-27, when #204 merged):** the additions are done — the
name's purposes in both consoles. The one relaxation still open is making
App interactions, Crash logs, Diagnostics and Device or other IDs
**optional** in Play, due once production carries a consent-gated build
(tracked in #218).

### Play Console → Policy → App content → Data safety

- **Name**: still collected, still **optional**, still not shared. Purposes
  become **App functionality, Personalization, Account management**. The
  app asks for it and greets the user by it (personalization, app
  functionality); Supabase still stores the name Google sends with a Google
  sign-in, which is account management. The app no longer takes a name from
  Google or Apple, but Google's still arrives, so the type stays declared.
- **App interactions, Crash logs, Diagnostics**: **optional** (users choose
  on first launch, and can switch it off in Privacy settings). Purpose stays
  Analytics. Play allows it: data is optional when "a user has control over
  its collection and can use the app without providing it", and only if "all
  users – regardless of device or region – can either optionally provide
  information, opt-out, or opt-in" — the choice is asked everywhere.
- **Device or other IDs**: the random identifier PostHog keeps on the phone
  is one (Play's own example is a "Firebase installation ID"). If the form
  does not list it yet, add it: **optional**, Analytics, not shared.
- **User IDs**: stay **required** — the account id is needed for the account
  itself, and Play takes one answer per data type. Analytics stays among its
  purposes, since PostHog links events to the account id after sign-in, if
  allowed.
- **Other user-generated content**: unchanged (the journal, App
  functionality). If PostHog surveys are switched on, their free-text
  answers go to PostHog only after Allow: add Analytics as a purpose then.
- **Shared: still none.** The name, like the journal, now reaches the AI
  Gateway and the model provider with each round. Play's sharing is
  "transferring user data collected from your app to a third party", except
  to a "service provider", "an entity that processes user data on behalf of
  the developer and based on the developer's instructions" (same page). The
  gateway and the provider answer each round for us on our instructions, so
  this is not sharing.
- The agent's own technical record of each round (latency, tokens, cost) and
  its server-side error reports carry no user or device identifier, so they
  do not make Diagnostics required.

Save, then **submit** the form; an edited, unsubmitted form does not count.

### App Store Connect → App Privacy

Apple has no "optional" answer: data "collected on an ongoing basis after an
initial request for permission must be disclosed"
([Apple, App privacy details](https://developer.apple.com/app-store/app-privacy-details/)).
So the analytics types stay declared exactly as they are.

- **Contact Info → Name**: Linked, no tracking. Purposes **App
  Functionality and Product Personalization**. Apple defines Product
  Personalization as "Customizing what the user sees, such as a list of
  recommended products, posts, or suggestions". The name changes what the
  user sees — the journal's greeting and how the companion addresses them —
  and the notice calls it the personalized service the user asked for, so
  both consoles and the notice tell the same story. App Functionality stays
  for the account record of a Google sign-in.
- **Identifiers (user id, device id), Usage Data and Diagnostics**:
  unchanged — Linked, the purposes already chosen (Analytics among them),
  **no tracking**.
- **No App Tracking Transparency prompt.** Tracking is "linking data
  collected from your app about a particular end-user or device … with
  Third-Party Data for targeted advertising or advertising measurement
  purposes, or sharing data … with a data broker" (same page). PostHog is
  first-party product analytics with neither, so ATT does not apply; the
  first-launch sheet is the consent § 25 TDDDG asks for, not ATT.

**Adding a purpose to a data type resets its "linked" answer.** On
2026-09-27, editing Name to add Product Personalization showed "Yes, linked"
on the linkage step, but it published as *not linked*: the product page
preview gained a "Data Not Linked to You → Contact Info" panel beside the
linked one. Re-running the edit showed "No" selected; choosing "Yes"
explicitly and publishing again fixed it. So on every edit, click the
linkage answer even when it looks right, and after **Publish** reload the
page and check that **Data Not Linked to You** is absent (nothing emotely
declares is unlinked).
