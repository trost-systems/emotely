#!/usr/bin/env bash
# Tests for the parts of evidence.sh (#172) that need no simulator and no
# GitHub: which screens a diff changes, the files it may upload, the
# before/after section it writes, and how that section goes into a pull
# request's body (inserted, replaced, or not there at all). Sources the
# script (its `main` runs only when executed). Run from anywhere:
#   bash .claude/skills/run-app/scripts/evidence.test.sh
set -euo pipefail

# shellcheck source=SCRIPTDIR/evidence.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/evidence.sh"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failures=0
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

# A process that is certainly dead: a finished background job.
dead_pid() {
  true &
  local pid=$!
  wait "${pid}"
  printf '%s' "${pid}"
}

# --- fixtures ---------------------------------------------------------------------

# Six screens over four features, two of them flows, in the order a walk
# visits them: the signed-out screen last.
cat >"${work}/map.yaml" <<'EOF'
screens:
  - route: JournalRoute
    package: feature_journal
    path: /
    reach:
      - "`run-app.sh up` ends here."
  - route: EntryRoute
    package: feature_journal
    path: /entries/:id
    reach:
      - Tap the newest journal_view.entry.
  - route: SessionRoute
    package: feature_session
    path: /session
    flow: true
    reach:
      - Tap journal_view.start.
  - route: MoreRoute
    package: feature_account
    path: /more
    reach:
      - Tap app_shell.more.
  - route: PrivacySettingsRoute
    package: feature_account
    path: /more/privacy
    reach:
      - Tap app_shell.more.
      - Tap more_view.privacy_settings.
  - route: SignInRoute
    package: feature_auth
    path: /sign-in
    flow: true
    reach:
      - Sign out, then tap onboarding.welcome.have_account.
EOF

# plan <max> <video auto|on|off> <only> <changed file>...: the plan for a
# diff of those files.
plan() {
  local max="$1" video="$2" only="$3"
  shift 3
  plan_json "${work}/map.yaml" "$(printf '%s\n' "$@")" "${max}" "${video}" "${only}"
}
slugs() { jq -r '[.screens[].slug] | join(",")' <<<"$1"; }

# --- which screens a diff changes -------------------------------------------------

test_a_feature_view_maps_to_the_screens_of_its_package() {
  local p
  p="$(plan 4 auto '' apps/mobile/packages/feature/feature_journal/lib/src/view/journal_view.dart)"
  [[ "$(slugs "${p}")" == journal,entry ]] ||
    fail "a feature view maps to its package's screens: got $(slugs "${p}")"
  [[ "$(jq -r '[.screens[].n] | join(",")' <<<"${p}")" == 01,02 ]] ||
    fail "the screens are numbered in walking order: got ${p}"
  [[ "$(jq -r '.screens[0].route' <<<"${p}")" == JournalRoute ]] ||
    fail "a planned screen keeps its route: got ${p}"
}

test_a_feature_copy_change_maps_to_its_screens() {
  local p
  p="$(plan 4 auto '' apps/mobile/packages/feature/feature_account/l10n/feature_account_de.arb)"
  [[ "$(slugs "${p}")" == more,privacy_settings ]] ||
    fail "a feature's l10n change maps to its screens: got $(slugs "${p}")"
}

test_two_features_map_to_both_in_walking_order() {
  local p
  p="$(plan 9 auto '' \
    apps/mobile/packages/feature/feature_auth/lib/src/sign_in_page.dart \
    apps/mobile/packages/feature/feature_journal/lib/src/view/entry_view.dart)"
  [[ "$(slugs "${p}")" == journal,entry,sign_in ]] ||
    fail "two features map to both, in walking order: got $(slugs "${p}")"
}

test_a_change_that_touches_no_screen_plans_none() {
  local p
  p="$(plan 4 auto '' \
    apps/mobile/packages/feature/feature_journal/test/view/journal_view_test.dart \
    apps/mobile/packages/feature/feature_journal/pubspec.yaml \
    apps/mobile/packages/utility/journal_repository/lib/src/journal_repository.dart \
    apps/agent/src/session.ts \
    .claude/skills/run-app/scripts/evidence.sh \
    docs/adr/0005-journal-content-privacy-mode.md)"
  [[ "$(jq '.screens | length' <<<"${p}")" == 0 ]] ||
    fail "tests, utilities, the agent, scripts and docs touch no screen: got $(slugs "${p}")"
  [[ "$(jq '.video' <<<"${p}")" == false ]] ||
    fail "no screen, no video: got ${p}"
}

test_no_changed_files_plan_no_screens() {
  local p
  p="$(plan_json "${work}/map.yaml" '' 4 auto '')"
  [[ "$(jq '.screens | length' <<<"${p}")" == 0 ]] || fail "no files, no screens: got ${p}"
}

test_the_design_system_counts_as_every_screen_up_to_the_cap() {
  local p
  p="$(plan 3 auto '' apps/mobile/packages/utility/design_system/lib/src/theme.dart)"
  [[ "$(slugs "${p}")" == journal,entry,session ]] ||
    fail "the design system is every screen, capped: got $(slugs "${p}")"
  [[ "$(jq -r '.omitted | join(",")' <<<"${p}")" == MoreRoute,PrivacySettingsRoute,SignInRoute ]] ||
    fail "the screens over the cap are named as left out: got ${p}"
  [[ "$(jq '.every' <<<"${p}")" == true ]] || fail "the plan says it is every screen: got ${p}"
}

test_the_app_shell_counts_as_every_screen() {
  local p
  p="$(plan 9 auto '' apps/mobile/app/lib/app/shell.dart)"
  [[ "$(jq '.screens | length' <<<"${p}")" == 6 ]] ||
    fail "an app-level change is every screen: got $(slugs "${p}")"
}

test_screens_a_feature_touches_win_the_cap_and_keep_walking_order() {
  local p
  p="$(plan 2 auto '' \
    apps/mobile/packages/utility/design_system/lib/src/theme.dart \
    apps/mobile/packages/feature/feature_auth/lib/src/sign_in_page.dart)"
  [[ "$(slugs "${p}")" == journal,sign_in ]] ||
    fail "the touched feature's screen wins the cap, in walking order: got $(slugs "${p}")"
}

test_a_flow_screen_asks_for_a_video() {
  local p
  p="$(plan 4 auto '' apps/mobile/packages/feature/feature_session/lib/src/view/session_view.dart)"
  [[ "$(jq '.video' <<<"${p}")" == true ]] || fail "a flow screen asks for a video: got ${p}"
  p="$(plan 4 auto '' apps/mobile/packages/feature/feature_account/lib/src/more_view.dart)"
  [[ "$(jq '.video' <<<"${p}")" == false ]] || fail "a single screen asks for none: got ${p}"
}

test_a_video_can_be_asked_for_or_turned_off() {
  local p
  p="$(plan 4 on '' apps/mobile/packages/feature/feature_account/lib/src/more_view.dart)"
  [[ "$(jq '.video' <<<"${p}")" == true ]] || fail "--video asks for one: got ${p}"
  p="$(plan 4 off '' apps/mobile/packages/feature/feature_session/lib/src/view/session_view.dart)"
  [[ "$(jq '.video' <<<"${p}")" == false ]] || fail "--no-video turns it off: got ${p}"
}

test_named_screens_replace_the_diff() {
  local p
  p="$(plan 1 auto 'sign_in,MoreRoute' apps/mobile/packages/feature/feature_journal/lib/src/view/journal_view.dart)"
  [[ "$(slugs "${p}")" == more,sign_in ]] ||
    fail "--screens names the screens, by slug or route, in walking order and past the cap: got $(slugs "${p}")"
}

test_an_unknown_named_screen_is_refused() {
  if (plan 4 auto 'nowhere' apps/mobile/app/lib/main.dart) >/dev/null 2>&1; then
    fail "an unknown --screens name is refused"
  fi
}

test_every_screen_of_the_feature_map_is_reachable_from_a_diff() {
  local map unreachable
  map="${REPO}/.claude/skills/run-app/references/feature-map.yaml"
  unreachable="$(yq -o json "${map}" | jq -r '.screens[].package' | sort -u | while read -r package; do
    [[ "${package}" == app || -n "$(compgen -G "${REPO}/apps/mobile/packages/*/${package}")" ]] ||
      printf '%s ' "${package}"
  done)"
  [[ -z "${unreachable}" ]] ||
    fail "every package in the feature map lives where the mapping looks: not ${unreachable}"
}

# --- the smoke account's lock -----------------------------------------------------

printf 'SMOKE_EMAIL=smoke@example.com\nSMOKE_PASSWORD=made-up\nSMOKE_EMAIL_DOMAINS=example.com\n' >"${work}/smoke.env"

test_waiting_never_takes_the_account_from_a_live_holder() {
  local lock err
  lock="$(LOCK_ROOT="${work}/live" SMOKE_EMAIL=smoke@example.com account_lock)"
  (LOCK_ROOT="${work}/live" SMOKE_EMAIL=smoke@example.com SESSION=other REPO=/checkout/other \
    take_account_lock "$$") 2>/dev/null
  if err="$(LOCK_ROOT="${work}/live" ENV_FILE="${work}/smoke.env" WAIT_MINUTES=0 wait_for_account 2>&1)"; then
    fail "waiting gives up while a live session holds the account"
  fi
  [[ "${err}" == */checkout/other* ]] || fail "it names the checkout holding the account: got ${err}"
  [[ "$(lock_field "${lock}" session)" == other ]] || fail "the holder keeps its lock"
}

test_waiting_passes_a_lock_whose_holder_is_dead() {
  (LOCK_ROOT="${work}/dead" SMOKE_EMAIL=smoke@example.com SESSION=gone REPO=/checkout/gone \
    take_account_lock "$(dead_pid)") 2>/dev/null
  (LOCK_ROOT="${work}/dead" ENV_FILE="${work}/smoke.env" WAIT_MINUTES=0 wait_for_account) 2>/dev/null ||
    fail "a dead holder's lock does not make it wait"
}

# --- the files it uploads ---------------------------------------------------------

# A plan of journal and entry, with a video; base and head both through
# up and down, each with its screenshots, a video and a stray file.
evidence_fixture() {
  local dir="$1" side
  plan 4 on '' apps/mobile/packages/feature/feature_journal/lib/src/view/journal_view.dart >"${dir}/plan.json"
  for side in base head; do
    mkdir -p "${dir}/${side}/post"
    : >"${dir}/${side}/post/01-journal.png"
    : >"${dir}/${side}/post/02-entry.png"
    : >"${dir}/${side}/post/video-4x.mp4"
    : >"${dir}/${side}/post/03-somewhere-else.png"
    mark_side "${dir}" "${side}" up made-up-session
    mark_side "${dir}" "${side}" down
  done
}

test_it_uploads_the_planned_screenshots_and_the_video_of_each_side() {
  local dir="${work}/files" files
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  files="$(evidence_files "${dir}" 4 2>/dev/null)"
  [[ "$(jq -r '[.[].path] | join(" ")' <<<"${files}")" == "./base/post/01-journal.png ./base/post/02-entry.png ./base/post/video-4x.mp4 ./head/post/01-journal.png ./head/post/02-entry.png ./head/post/video-4x.mp4" ]] ||
    fail "uploads each side's planned screenshots and video, by relative path: got ${files}"
  [[ "$(jq -r '[.[].label] | unique | length' <<<"${files}")" == 6 ]] ||
    fail "every upload has its own label: got ${files}"
}

test_it_never_uploads_a_file_the_plan_does_not_name() {
  local dir="${work}/stray" files
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  files="$(evidence_files "${dir}" 4 2>/dev/null)"
  [[ "${files}" != *somewhere-else* ]] || fail "a file the plan does not name is not uploaded: got ${files}"
}

test_it_refuses_a_side_that_evidence_did_not_bring_up() {
  local dir="${work}/foreign" files
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  rm "${dir}/base/.evidence"
  files="$(evidence_files "${dir}" 4 2>/dev/null)"
  [[ "${files}" != *./base/* ]] ||
    fail "a side not brought up by evidence.sh (so not the smoke account) is not uploaded: got ${files}"
}

test_it_refuses_a_side_that_is_still_up() {
  local dir="${work}/still-up" files
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  mark_side "${dir}" head up made-up-session
  files="$(evidence_files "${dir}" 4 2>/dev/null)"
  [[ "${files}" != *./head/* ]] || fail "a side still up (not collected) is not uploaded: got ${files}"
}

test_it_refuses_to_post_when_no_side_is_done() {
  local dir="${work}/none-done"
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  rm "${dir}/base/.evidence" "${dir}/head/.evidence"
  if (evidence_files "${dir}" 4) >/dev/null 2>&1; then
    fail "refuses to post when neither side went through up and down"
  fi
}

test_the_staging_section_links_each_file_by_its_label() {
  local dir="${work}/staging" files staged
  mkdir -p "${dir}"
  evidence_fixture "${dir}"
  files="$(evidence_files "${dir}" 4 2>/dev/null)"
  staged="$(staging_section "${files}")"
  [[ "${staged}" == *"[pr-evidence:base:01-journal](./base/post/01-journal.png)"* ]] ||
    fail "the staging section links a file under its label, so --attach rewrites it: got ${staged}"
  [[ "${staged}" == "${MARK_START}"* && "${staged}" == *"${MARK_END}" ]] ||
    fail "the staging section sits between the markers: got ${staged}"
  [[ "${staged}" != *"${work}"* ]] || fail "the staging section holds no absolute local path: got ${staged}"
}

test_it_reads_the_uploaded_urls_back_by_label() {
  local urls
  printf 'Intro\n\n%s\n\n[pr-evidence:base:01-journal](https://github.com/user-attachments/assets/aaa)\n\n[pr-evidence:head:video](https://github.com/user-attachments/assets/bbb)\n\n%s\n' \
    "${MARK_START}" "${MARK_END}" >"${work}/rewritten.md"
  urls="$(uploaded_urls "${work}/rewritten.md")"
  [[ "$(jq -r '."base:01-journal"' <<<"${urls}")" == https://github.com/user-attachments/assets/aaa ]] ||
    fail "reads an uploaded URL back by its label: got ${urls}"
  [[ "$(jq -r '."head:video"' <<<"${urls}")" == https://github.com/user-attachments/assets/bbb ]] ||
    fail "reads the video's URL back: got ${urls}"
}

test_it_fails_when_an_upload_is_missing() {
  local files urls
  files='[{"label":"base:01-journal","path":"./base/post/01-journal.png"},{"label":"head:01-journal","path":"./head/post/01-journal.png"}]'
  urls='{"base:01-journal":"https://github.com/user-attachments/assets/aaa"}'
  if (check_uploaded "${files}" "${urls}") 2>/dev/null; then
    fail "fails when a file was not uploaded"
  fi
}

# --- the section ------------------------------------------------------------------

section_for() {
  local urls="$1"
  plan 4 on "" apps/mobile/packages/feature/feature_journal/lib/src/view/journal_view.dart >"${work}/section-plan.json"
  render_section "${work}/section-plan.json" "${urls}" '{"base":"abc1234","head":"def5678","speed":4}'
}

all_urls='{
  "base:01-journal": "https://github.com/user-attachments/assets/b1",
  "head:01-journal": "https://github.com/user-attachments/assets/h1",
  "base:02-entry": "https://github.com/user-attachments/assets/b2",
  "head:02-entry": "https://github.com/user-attachments/assets/h2",
  "base:video": "https://github.com/user-attachments/assets/bv",
  "head:video": "https://github.com/user-attachments/assets/hv"
}'

test_the_section_shows_each_pair_side_by_side_at_300_px_with_captions() {
  local s row
  s="$(section_for "${all_urls}")"
  [[ "$(grep -o '<img ' <<<"${s}" | wc -l | tr -d ' ')" == 4 ]] || fail "one image per side and screen: got ${s}"
  [[ "$(grep -c '<img [^>]*width="300"' <<<"${s}")" == 2 ]] ||
    fail "every image is shown 300 px wide, a pair per row: got ${s}"
  row="$(grep -F 'assets/b1' <<<"${s}")"
  [[ "${row}" == *assets/h1* ]] || fail "a screen's before and after sit side by side in one row: got ${row}"
  [[ "${row}" == *"Journal, before"* && "${row}" == *"Journal, after"* ]] ||
    fail "each image has its caption: got ${row}"
  [[ "${s}" == *abc1234* && "${s}" == *def5678* ]] || fail "the section names base and head: got ${s}"
  [[ "${s}" == *"smoke account"* && "${s}" == *"made-up"* ]] ||
    fail "the section says whose data it shows: got ${s}"
}

test_the_section_plays_each_video_from_a_url_alone_in_its_paragraph() {
  local s
  s="$(section_for "${all_urls}")"
  local url
  for url in https://github.com/user-attachments/assets/bv https://github.com/user-attachments/assets/hv; do
    [[ "$(grep -B1 -A1 -x "${url}" <<<"${s}" | tr '\n' '|')" == "|${url}||" ]] ||
      fail "a video's URL is alone in its paragraph, so GitHub plays it: ${url} in ${s}"
  done
  [[ "${s}" == *"4x"* ]] || fail "the section says the video is sped up: got ${s}"
}

test_the_section_without_a_video_says_nothing_of_one() {
  local s
  s="$(section_for '{"base:01-journal":"https://x/b1","head:01-journal":"https://x/h1","base:02-entry":"https://x/b2","head:02-entry":"https://x/h2"}')"
  [[ "${s}" != *[Vv]ideo* ]] || fail "no video, no video paragraph: got ${s}"
}

test_a_screenshot_missing_on_one_side_leaves_a_caption_and_no_image() {
  local s row
  s="$(section_for '{"head:01-journal":"https://x/h1","base:02-entry":"https://x/b2","head:02-entry":"https://x/h2"}')"
  row="$(grep -F 'https://x/h1' <<<"${s}")"
  [[ "$(grep -o '<img ' <<<"${row}" | wc -l | tr -d ' ')" == 1 ]] ||
    fail "a missing screenshot has no image: got ${row}"
  [[ "${row}" == *"Journal, before: no screenshot"* ]] || fail "it says the screenshot is missing: got ${row}"
  [[ "${s}" != *'src=""'* ]] || fail "no image without a source: got ${s}"
}

test_the_section_is_wrapped_in_its_markers() {
  local s
  s="$(section_for "${all_urls}")"
  [[ "$(head -1 <<<"${s}")" == "${MARK_START}"* && "$(tail -1 <<<"${s}")" == "${MARK_END}" ]] ||
    fail "the section opens and closes with its markers: got ${s}"
}

# --- the section in the body: insert, replace, none --------------------------------

printf '%s\n\nNEW SECTION\n\n%s\n' "${MARK_START}" "${MARK_END}" >"${work}/section.md"
markers_in() { grep -c -F "${MARK_START}" "$1" || true; }

test_inserts_the_section_at_the_end_of_a_body_without_one() {
  printf 'Why this change.\n\nCloses #1\n' >"${work}/plain.md"
  splice_section "${work}/plain.md" "${work}/section.md" >"${work}/out.md"
  [[ "$(head -1 "${work}/out.md")" == "Why this change." ]] || fail "insert keeps the body first"
  [[ "$(tail -1 "${work}/out.md")" == "${MARK_END}" ]] || fail "insert appends the section at the end: got $(cat "${work}/out.md")"
  grep -qx 'Closes #1' "${work}/out.md" || fail "insert keeps the body's lines"
  [[ "$(markers_in "${work}/out.md")" == 1 ]] || fail "insert writes one section"
}

test_inserts_the_section_before_the_generated_with_trailer() {
  printf 'Why this change.\n\n\xf0\x9f\xa4\x96 Generated with [Claude Code](https://claude.com/claude-code)\n' >"${work}/trailer.md"
  splice_section "${work}/trailer.md" "${work}/section.md" >"${work}/out.md"
  [[ "$(tail -1 "${work}/out.md")" == *"Generated with [Claude Code]"* ]] ||
    fail "the trailer stays last: got $(cat "${work}/out.md")"
  grep -qx 'NEW SECTION' "${work}/out.md" || fail "the section goes in before the trailer"
}

test_replaces_an_existing_section_in_place() {
  printf 'Top.\n\n%s\nOLD SECTION\n%s\n\nBottom.\n' "${MARK_START}" "${MARK_END}" >"${work}/old.md"
  splice_section "${work}/old.md" "${work}/section.md" >"${work}/out.md"
  ! grep -q 'OLD SECTION' "${work}/out.md" || fail "replace drops the old section"
  grep -qx 'NEW SECTION' "${work}/out.md" || fail "replace writes the new one"
  [[ "$(markers_in "${work}/out.md")" == 1 ]] || fail "replace leaves one section: got $(cat "${work}/out.md")"
  [[ "$(head -1 "${work}/out.md")" == Top. && "$(tail -1 "${work}/out.md")" == Bottom. ]] ||
    fail "replace keeps the text around it where it was: got $(cat "${work}/out.md")"
}

test_a_rerun_is_idempotent() {
  printf 'Top.\n' >"${work}/rerun.md"
  splice_section "${work}/rerun.md" "${work}/section.md" >"${work}/once.md"
  splice_section "${work}/once.md" "${work}/section.md" >"${work}/twice.md"
  cmp -s "${work}/once.md" "${work}/twice.md" || fail "running twice writes the same body: got $(cat "${work}/twice.md")"
}

test_replaces_duplicate_sections_with_one() {
  printf 'Top.\n\n%s\nA\n%s\n\nMiddle.\n\n%s\nB\n%s\n' \
    "${MARK_START}" "${MARK_END}" "${MARK_START}" "${MARK_END}" >"${work}/dupes.md"
  splice_section "${work}/dupes.md" "${work}/section.md" >"${work}/out.md"
  [[ "$(markers_in "${work}/out.md")" == 1 ]] || fail "two stale sections become one: got $(cat "${work}/out.md")"
  grep -qx 'Middle.' "${work}/out.md" || fail "the text between them stays"
}

test_none_removes_a_stale_section_and_its_gap() {
  printf 'Top.\n\n%s\nOLD SECTION\n%s\n\nBottom.\n' "${MARK_START}" "${MARK_END}" >"${work}/stale.md"
  splice_section "${work}/stale.md" >"${work}/out.md"
  [[ "$(cat "${work}/out.md")" == "$(printf 'Top.\n\nBottom.')" ]] ||
    fail "none removes the section and leaves one blank line: got $(cat "${work}/out.md")"
}

test_none_leaves_a_body_without_a_section_alone() {
  printf 'Top.\n\nBottom.\n' >"${work}/clean.md"
  if has_section "${work}/clean.md"; then
    fail "a body without the markers has no section"
  fi
  splice_section "${work}/clean.md" >"${work}/out.md"
  [[ "$(cat "${work}/out.md")" == "$(cat "${work}/clean.md")" ]] || fail "none changes nothing in a clean body"
}

test_a_body_that_only_mentions_the_marker_has_no_section() {
  local tick=$'\x60'
  printf "The section sits between %s%s%s and %s%s%s.\n" "${tick}" "${MARK_START}" "${tick}" "${tick}" "${MARK_END}" "${tick}" >"${work}/mentions.md"
  if has_section "${work}/mentions.md"; then
    fail "a marker quoted inside a line is not a section"
  fi
  splice_section "${work}/mentions.md" "${work}/section.md" >"${work}/out.md"
  grep -qF 'The section sits between' "${work}/out.md" || fail "the line quoting the marker stays"
  [[ "$(markers_in "${work}/out.md")" == 2 ]] || fail "insert adds one section beside the quote: got $(cat "${work}/out.md")"
}

test_handles_a_body_edited_in_the_browser() {
  printf 'Top.\r\n\r\n%s\r\nOLD\r\n%s\r\n' "${MARK_START}" "${MARK_END}" >"${work}/crlf.md"
  has_section "${work}/crlf.md" || fail "finds the section in a CRLF body"
  splice_section "${work}/crlf.md" "${work}/section.md" >"${work}/out.md"
  ! grep -q 'OLD' "${work}/out.md" || fail "replaces the section in a CRLF body: got $(cat "${work}/out.md")"
}

for test in $(declare -F | awk '{print $3}' | grep '^test_'); do
  "${test}"
done

if ((failures > 0)); then
  printf '%d failure(s)\n' "${failures}" >&2
  exit 1
fi
printf 'all evidence tests passed\n'
