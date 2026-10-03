---
name: store-consoles
description: How an agent does the App Store Connect and Play Console steps no API covers — Apple's App Privacy labels, Play's App access (reviewer sign-in), the IARC content rating questionnaire, Play's category, privacy policy URL, contact details and countries — in Peter's Chrome, from answers kept in the repository. Use whenever one of those changes, a store review or rejection points at one, or the repository and a console may have drifted apart.
---

# Store console steps (no API)

Everything a store lets CI write is written by CI (the release-app skill:
listings, App Review information, Play Data safety). What is left are forms
only a browser reaches. For each of them **the repository holds the
answer**, and the agent's job is to make the console say exactly that and
prove it did.

## The shape of every step

1. **Repository first.** A change is a pull request to the answer file
   below; the console follows after it merges. When a console already says
   something else (a review asked for it, someone clicked), the file is
   corrected first, so the two never disagree for long.
2. **Open the console in Peter's Chrome** (Claude in Chrome, a new tab).
   Play Console stays signed in. **App Store Connect needs Peter signed in**;
   a sign-in page is his to complete, never the agent's.
3. **Fill the form from the file**, field by field.
4. **Ask Peter before Save, Submit or Publish**, naming each field that
   changes from what to what; act on his yes in chat. Saving a store form is
   public, and the safety rules require that approval.
5. **Verify**: reload the page, read every field back and compare it with
   the file. The step is done when they match, not when the form saved.

**Where the human steps in**, always: signing in to App Store Connect;
typing any password (the reviewer accounts' password goes into Play's App
access form by Peter's hand — the agent fills everything else and leaves
that field to him); the yes before each save. Passwords are never in the
repository: the reviewer password is in `~/.config/emotely/reviewer-accounts.env`
and Peter's iCloud Passwords.

## Driving the consoles

- **Play Console**: app id `4975881213380590767`, developer
  `5174249003608815741`, `https://play.google.com/console/u/0/developers/5174249003608815741/app/4975881213380590767/…`.
  A deep link redirects to the app list unless the app dashboard
  (`…/app-dashboard`) was opened once in that tab. Pages render lazily:
  wait a few seconds and take a screenshot before reading. Page text
  extraction returns only the navigation; read a section with `find` and
  `read_page` on its ref, or from a screenshot.
- **Clicking a free-text field can hand the tab to another extension**
  ("Cannot access a chrome-extension:// URL of different extension"), after
  which every action on that tab fails: close it, open a fresh one, and set
  text fields through `javascript_tool` (the native value setter plus
  `input` and `change` events) instead of typing; `form_input` alone does
  not register with the Play Console's forms.
- **App Store Connect**: app id `6466288395`,
  `https://appstoreconnect.apple.com/apps/6466288395/…`.
- Close the tabs you opened when done.

## The steps

### Apple App Privacy (nutrition labels)

- **Truth**: `apps/mobile/app/fastlane/console/app_privacy_details.json`, in
  the format of fastlane's `upload_app_privacy_details_to_app_store`
  (`category`, `purposes`, `data_protections` per data type). What each
  answer means and why: the release-app skill's
  `references/data-declarations.md`.
- Eight data types, all linked, none used for tracking: read from App Store
  Connect on 2026-10-03, then corrected to what the code does (#290).
  `fastlane/test` checks every id is one App Store Connect knows and holds
  the expected purposes per type, so a purpose changes in the test and the
  file together; the console follows after the merge.
- **Console**: App Store Connect → App Privacy → Edit, per data type.
  Alternatively Peter runs, in his own terminal (it asks for his Apple ID
  and 2FA, which no agent enters):
  `cd apps/mobile/app && bundle exec fastlane run upload_app_privacy_details_to_app_store json_path:fastlane/console/app_privacy_details.json app_identifier:de.emotely.emotely team_id:VCZSHMZY25`.
  No API key can do this (the action logs in as a user; App Store Connect
  API 4.5 has no endpoint for it).
- **Verify**: after **Publish**, reload; the product page preview lists
  exactly the JSON's types under **Data Linked to You** and **no "Data Not
  Linked to You"** panel. Editing a type's purposes resets its linkage to
  "not linked" silently: click the linkage answer on every edit, even when
  it looks right.

### Play App access (reviewer sign-in)

- **Truth**: `apps/mobile/app/fastlane/console/play.yaml` → `app_access`
  (entry name, user name, the "allow Google to use these details for
  testing" switch) and `play_app_access_instructions.txt` (the
  instructions, ≤ 500 characters, checked by `fastlane/test`).
- **Console**: Play Console → Policy → App content → App access → Sign-in
  details → Manage. The agent fills the entry name, user name and
  instructions; Peter types the password; then the yes, Save.
- **Verify**: the entry list (it loads lazily, sometimes only after a
  scroll) shows the entry with the user name and the instructions from the
  file; the testing switch is on.

### Play content rating (IARC)

- **Truth**: `play.yaml` → `content_rating`: the questionnaire category,
  the ratings it produced and, from the next questionnaire on, every
  question with the answer given (`answers`). The console shows the
  ratings afterwards, not the answers, so the file is the only record.
- **Console**: Play Console → Policy → App content → Content ratings →
  Start new questionnaire. Answer from `answers`; a question the file does
  not answer is Peter's to decide, and its answer goes into the file in
  the same pull request. Submitting sends the questionnaire to IARC and
  can change the ratings everywhere: the yes names the expected ratings.
- **Verify**: Content ratings shows status Completed, a new certificate id
  and the ratings in the file; update `iarc_certificate_id`, `submitted`
  and `ratings` in the file.

### Play category, privacy policy URL, contact details, countries

- **Truth**: `play.yaml` → `category`, `privacy_policy_url`, `contact`,
  `external_marketing`, `production_countries`.
- **Consoles**:
  - Category, contact, external marketing: Grow users → Store presence →
    Store settings.
  - Privacy policy URL: Policy → App content → Privacy policy. One URL for
    the whole app; it must load without sign-in or a consent wall, since
    Google fetches it (`/privacy` instead of `/app-privacy` got the
    2026-09-13 update rejected).
  - Countries: Test and release → Production → Countries/regions.
- **Verify**: the App content list (Actioned tab, row expanded) and Store
  settings show the file's values; Production's track summary shows the
  file's country count.
