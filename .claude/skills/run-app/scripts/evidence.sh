#!/usr/bin/env bash
# Before/after evidence for a pull request (#172): which screens its diff
# changes (through the feature map), the app on the base and on the head,
# the screenshots and a 4x video collected, uploaded with `gh pr edit
# --attach`, and a before/after section in the pull request's body that a
# re-run replaces. `evidence.sh help` for usage.
#
# It does everything except driving the app. Reaching a screen is the
# feature map's `reach`, which is knowledge for an agent and not a script
# (no flow runner): between `up` and `down` the agent drives each planned
# screen with marionette and saves its screenshot under the planned name.
#
# Privacy (ADR 0005): the repository and its attachments are public. Each
# side runs through run-app.sh, which signs in as the smoke account and
# nobody else; this script uploads only the planned screenshots and the
# video of a side it brought up and down itself, by relative path, so no
# local path reaches the body or its edit history. What the agent types is
# made-up content.
#
# Several agent sessions on one machine run this at once: each side is a
# worktree named after the session, the run-app session in it is named
# after that worktree, the state lives in this checkout, and the smoke
# account's lock is waited for, never taken from its holder.
set -euo pipefail

EVIDENCE_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# run-app.sh's helpers: the smoke account and its lock, the session id,
# the posting copies. Sourcing runs none of its commands.
# shellcheck source=SCRIPTDIR/run-app.sh
source "$EVIDENCE_SCRIPTS/run-app.sh"

MAP_PATH=".claude/skills/run-app/references/feature-map.yaml"
RUN_APP_PATH=".claude/skills/run-app/scripts/run-app.sh"
# One evidence run per checkout; its state lives in the ignored build
# directory, the bundles beside run-app's.
EV_DIR="$APP_DIR/build/pr-evidence"
EV_STATE="$EV_DIR/state"
# The sides' worktrees, beside the ones Claude Code makes (ignored).
WORKTREES="$MAIN_CHECKOUT/.claude/worktrees"
MARK_START='<!-- pr-evidence:start -->'
MARK_END='<!-- pr-evidence:end -->'
DEFAULT_MAX=4
# How long `up` waits for another session to free the smoke account.
WAIT_MINUTES="${EMOTELY_EVIDENCE_WAIT:-30}"

evidence_usage() {
  cat <<EOF
Usage: evidence.sh <command>

  plan [<pr>] [--base <branch>] [--max N] [--video|--no-video] [--screens a,b]
                   Map the diff to the screens it changes and plan the
                   evidence: the pull request <pr> (number or URL), or this
                   branch's committed HEAD against its pull request's base
                   (or --base, default main). Feature packages map to their
                   screens; the design system and the app to every screen,
                   at most --max (default $DEFAULT_MAX). A flow screen gets a video
                   (--video / --no-video to decide). --screens names the
                   screens instead of the diff. Touching no screen ends
                   here: no evidence, and a section from an earlier run is
                   removed.
  up base|head     Check the side out in its own worktree, wait for the
                   smoke account, run-app.sh up there (signed in, usage
                   analytics denied), start the recording when the plan
                   has a video, and print what to drive: each screen's
                   reach and the exact screenshot to take.
  down base|head [--speed N]
                   Stop the recording (its copy N times faster, default
                   $DEFAULT_SPEED), make the ${POST_WIDTH} px copies of the screenshots and
                   run-app.sh down. Always run it, also after a failure.
  post [<pr>] [--speed N] [--dry-run]
                   Upload the planned screenshots and the video of each
                   side that went through up and down, with gh pr edit
                   --attach, and write the before/after section into the
                   pull request's body, replacing an earlier one. Then
                   removes the worktrees. --dry-run prints the section.
  status           The plan and each side's state.
  clean            Bring both sides down and remove their worktrees and
                   the state; the bundle stays.
  help             This text.

Between up and down, drive with marionette (run-app.sh help), made-up
content only, and save each planned screen as
  marionette -i <instance> take-screenshots --output <bundle>/<NN>-<screen>.png
Do the base, then the head: one smoke account runs one session at a time.
EOF
}

die() {
  printf 'evidence: step "%s" failed: %s\n' "$STEP" "$*" >&2
  exit 1
}

# --- state ----------------------------------------------------------------------

ev_get() { sed -n "s/^$1=//p" "$EV_STATE" 2>/dev/null | tail -1; }
ev_set() {
  mkdir -p "$EV_DIR"
  printf '%s=%s\n' "$1" "$2" >>"$EV_STATE"
}
require_plan() {
  [[ -f "$EV_STATE" ]] || die "no plan: run \`evidence.sh plan\` first"
  DIR="$(ev_get DIR)"
  [[ -f "$DIR/plan.json" ]] || die "the plan's bundle $DIR is gone: run \`evidence.sh plan\` again"
}
require_side() {
  case "${1:-}" in
    base | head) ;;
    *) die "say which side: base or head" ;;
  esac
}
sha_of() {
  case "$1" in
    base) ev_get BASE_SHA ;;
    head) ev_get HEAD_SHA ;;
  esac
}
# "#283", or "this branch" before its pull request is open.
target_name() {
  if [[ -n "${PR:-}" ]]; then printf '#%s' "$PR"; else printf 'this branch'; fi
}

# mark_side <dir> <side> up <run-app session> | down: what evidence.sh did
# with that side's bundle. Only a side marked down is uploaded.
mark_side() {
  mkdir -p "$1/$2"
  case "$3" in
    up) printf 'session=%s\nstate=up\n' "$4" >"$1/$2/.evidence" ;;
    down) printf 'state=down\n' >>"$1/$2/.evidence" ;;
  esac
}
side_state() { sed -n 's/^state=//p' "$1/$2/.evidence" 2>/dev/null | tail -1; }

# --- the plan -------------------------------------------------------------------

# plan_json <feature map> <changed files> <max> <video on|off|auto> <only>
plan_json() {
  yq -o json "$1" | jq --arg files "$2" --argjson max "$3" --arg video "$4" --arg only "$5" \
    -f "$EVIDENCE_SCRIPTS/evidence-plan.jq"
}

# Sets PR (empty without one), BASE_SHA (the merge base) and HEAD_SHA.
resolve_target() {
  local pr="$1" base="$2" view
  if [[ -n "$pr" ]]; then
    view="$(gh pr view "$pr" --json number,baseRefName,headRefOid)" || die "no pull request $pr"
    PR="$(jq -r .number <<<"$view")"
    base="${base:-$(jq -r .baseRefName <<<"$view")}"
    HEAD_SHA="$(jq -r .headRefOid <<<"$view")"
    git -C "$REPO" fetch -q origin "$base" "refs/pull/$PR/head" || die "could not fetch the pull request"
  else
    # This branch's committed HEAD, posted to its pull request if it has one.
    PR="$(gh pr view --json number -q .number 2>/dev/null || true)"
    if [[ -n "$PR" && -z "$base" ]]; then
      base="$(gh pr view "$PR" --json baseRefName -q .baseRefName)"
    fi
    base="${base:-main}"
    HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
    git -C "$REPO" fetch -q origin "$base" || die "could not fetch $base"
    [[ -z "$(git -C "$REPO" status --porcelain)" ]] ||
      log "uncommitted changes are not in the evidence: it shows the commit $(git -C "$REPO" rev-parse --short HEAD)"
  fi
  git -C "$REPO" cat-file -e "$HEAD_SHA^{commit}" 2>/dev/null || die "commit $HEAD_SHA is not here"
  BASE_SHA="$(git -C "$REPO" merge-base "origin/$base" "$HEAD_SHA")" ||
    die "no merge base of origin/$base and $HEAD_SHA"
}

# The PR's section, if it has one, comes out of its body.
remove_stale_section() {
  [[ -n "$PR" ]] || return 0
  local body="$EV_DIR/body.md"
  gh pr view "$PR" --json body -q .body >"$body" || die "could not read the body of #$PR"
  has_section "$body" || return 0
  splice_section "$body" >"$EV_DIR/body-clean.md"
  gh pr edit "$PR" --body-file "$EV_DIR/body-clean.md" >/dev/null || die "could not edit #$PR"
  log "removed the evidence section an earlier run left on #$PR"
}

print_plan() {
  jq -r '
    "\(.screens | length) screen(s)\(if .every then " (an app-wide change; capped)" else "" end), video: \(if .video then "yes" else "no" end)",
    (.screens[] | "  \(.n)-\(.slug)  \(.route)  \(.path)  (\(.package))"),
    (if (.omitted | length) > 0 then "  left out: \(.omitted | join(", "))" else empty end)' "$1"
}

evidence_plan() {
  local pr="" base="" max="$DEFAULT_MAX" video=auto only="" side
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base) base="${2:?--base needs a branch}"; shift 2 ;;
      --max) max="${2:?--max needs a number}"; shift 2 ;;
      --video) video=on; shift ;;
      --no-video) video=off; shift ;;
      --screens) only="${2:?--screens needs a list}"; shift 2 ;;
      -*) die "unknown option $1" ;;
      *) pr="$1"; shift ;;
    esac
  done
  STEP="plan"
  [[ "$max" =~ ^[1-9][0-9]*$ ]] || die "--max takes a whole number from 1 up, not \"$max\""
  if [[ -f "$EV_STATE" ]]; then
    for side in base head; do
      [[ "$(side_state "$(ev_get DIR)" "$side")" != up ]] ||
        die "the $side side is still up: evidence.sh down $side first"
    done
    remove_worktrees
  fi
  rm -rf "$EV_DIR"
  mkdir -p "$EV_DIR"
  resolve_target "$pr" "$base"

  local files map="$EV_DIR/feature-map.yaml" plan="$EV_DIR/plan.json"
  files="$(git -C "$REPO" diff --name-only "$BASE_SHA" "$HEAD_SHA")"
  # The head's map: a pull request that adds a screen also adds its entry.
  git -C "$REPO" show "$HEAD_SHA:$MAP_PATH" >"$map" 2>/dev/null || cp "$REPO/$MAP_PATH" "$map"
  plan_json "$map" "$files" "$max" "$video" "$only" >"$plan" || die "could not plan"

  if [[ "$(jq '.screens | length' "$plan")" == 0 ]]; then
    remove_stale_section
    rm -rf "$EV_DIR"
    printf 'evidence: %s touches no screen: no evidence and no section\n' "$(target_name)"
    return
  fi

  local session dir
  session="$(new_session_id "$REPO")"
  dir="$APP_DIR/build/evidence/${PR:+pr-$PR-}$session"
  mkdir -p "$dir"
  cp "$plan" "$dir/plan.json"
  ev_set SESSION "$session"
  ev_set PR "$PR"
  ev_set BASE_SHA "$BASE_SHA"
  ev_set HEAD_SHA "$HEAD_SHA"
  ev_set DIR "$dir"
  printf 'evidence: %s, base %s, head %s\n' "$(target_name)" \
    "$(git -C "$REPO" rev-parse --short "$BASE_SHA")" "$(git -C "$REPO" rev-parse --short "$HEAD_SHA")"
  print_plan "$plan"
  printf 'next: evidence.sh up base, drive, evidence.sh down base; the same for head; evidence.sh post\n'
}

# --- up and down ----------------------------------------------------------------

worktree_of() { printf '%s/evidence-%s-%s' "$WORKTREES" "$(ev_get SESSION)" "$1"; }

# Waits while another session holds the smoke account. Never takes it
# from a live holder; a dead holder's lock is stale, and `up` takes it.
wait_for_account() {
  local lock record deadline
  read_smoke_account
  lock="$(account_lock)"
  deadline=$((SECONDS + WAIT_MINUTES * 60))
  while record="$(lock_read "$lock")" && [[ -n "$record" ]] && record_alive "$record"; do
    ((SECONDS < deadline)) ||
      die "the smoke account is still in use by session $(record_field "$record" session) in $(record_field "$record" checkout) after ${WAIT_MINUTES} min; try again later (EMOTELY_EVIDENCE_WAIT sets the minutes)"
    log "the smoke account is in use by session $(record_field "$record" session) in $(record_field "$record" checkout); waiting"
    sleep 30
  done
}

# run_up <worktree> <bundle>: run-app.sh up in that worktree, waiting for
# the account and trying again when another session took it first.
run_up() {
  local run_app="$1/$RUN_APP_PATH" err="$EV_DIR/up.err" skip=()
  if [[ -d "$1/apps/mobile/app/build/ios/iphonesimulator/Runner.app" ]]; then skip=(--skip-build); fi
  while :; do
    wait_for_account
    # Its log shows as it goes and is kept to tell a lost race apart;
    # pipefail makes the pipeline fail with `up`.
    if { "$run_app" up --out "$2" --analytics deny ${skip[@]+"${skip[@]}"} 2>&1 >"$EV_DIR/up.out"; } |
      tee "$err" >&2; then
      return 0
    fi
    "$run_app" down >/dev/null 2>&1 || true
    grep -q 'smoke account is in use' "$err" || return 1
    log "another session took the smoke account first; waiting again"
  done
}

print_drive() {
  local side="$1" instance="$2" bundle="$3"
  printf '\nevidence: %s is up (%s, %s)\n' "$side" \
    "$(git -C "$REPO" rev-parse --short "$(sha_of "$side")")" \
    "$([[ "$side" == base ]] && printf 'before the change' || printf 'with the change')"
  printf 'instance  %s\nbundle    %s\n' "$instance" "$bundle"
  if [[ "$(jq '.video' "$DIR/plan.json")" == true ]]; then
    printf 'video     recording, until evidence.sh down %s\n' "$side"
  fi
  printf '\nDrive to each screen with marionette, made-up content only, and save it under exactly this name:\n'
  jq -r --arg i "$instance" --arg b "$bundle" '.screens[] |
    "\n\(.n)-\(.slug)  \(.route)  \(.path)",
    (.reach[] | "  - \(.)"),
    "  marionette -i \($i) take-screenshots --output \($b)/\(.n)-\(.slug).png"' "$DIR/plan.json"
  printf '\nA screen the base does not have yet: skip it there. Then: evidence.sh down %s\n' "$side"
}

evidence_up() {
  local side="${1:-}" worktree sha bundle instance
  STEP="up"
  require_side "$side"
  require_plan
  [[ "$(side_state "$DIR" "$side")" != up ]] || die "$side is already up: evidence.sh down $side first"
  if [[ "$side" == head && "$(side_state "$DIR" base)" == up ]]; then
    die "base is still up: evidence.sh down base first (one smoke account, one session)"
  fi
  if [[ "$side" == base && "$(side_state "$DIR" head)" == up ]]; then
    die "head is still up: evidence.sh down head first (one smoke account, one session)"
  fi
  sha="$(sha_of "$side")"
  worktree="$(worktree_of "$side")"
  if [[ ! -d "$worktree" ]]; then
    mkdir -p "$WORKTREES"
    git -C "$REPO" worktree add -q --detach "$worktree" "$sha" || die "could not check $side out"
  fi
  [[ -x "$worktree/$RUN_APP_PATH" ]] || die "$side ($sha) has no run-app.sh to run the app with"
  # A session an earlier, interrupted run left in this worktree.
  [[ ! -d "$worktree/apps/mobile/app/build/run-app" ]] || "$worktree/$RUN_APP_PATH" down >/dev/null 2>&1 || true
  bundle="$DIR/$side"
  rm -rf "$bundle"
  mkdir -p "$bundle"
  run_up "$worktree" "$bundle" || die "run-app.sh up failed on $side; it is down again"
  instance="$(sed -n 's/^instance  *//p' "$EV_DIR/up.out")"
  mark_side "$DIR" "$side" up "$(sed -n 's/^session  *//p' "$EV_DIR/up.out")"
  if [[ "$(jq '.video' "$DIR/plan.json")" == true ]]; then
    "$worktree/$RUN_APP_PATH" record start || log "could not start the recording; there will be no video of $side"
  fi
  print_drive "$side" "$instance" "$bundle"
}

evidence_down() {
  local side="${1:-}" worktree run_app
  shift || true
  STEP="down"
  require_side "$side"
  parse_speed "$@"
  require_plan
  STEP="down"
  worktree="$(worktree_of "$side")"
  run_app="$worktree/$RUN_APP_PATH"
  if [[ ! -x "$run_app" ]]; then
    log "$side has no worktree: nothing is up"
    return
  fi
  # Whatever fails here, the session goes down and frees the account.
  "$run_app" record stop --speed "$SPEED" || log "the recording of $side has no posting copy"
  STEP="down"
  post_screenshots "$DIR/$side"
  "$run_app" down || log "run-app.sh down reported a problem on $side"
  STEP="down"
  if [[ "$(side_state "$DIR" "$side")" == up ]]; then mark_side "$DIR" "$side" down; fi
  local missing
  missing="$(jq -r '.screens[] | "\(.n)-\(.slug).png"' "$DIR/plan.json" | while read -r shot; do
    [[ -e "$DIR/$side/post/$shot" ]] || printf '%s ' "$shot"
  done)"
  [[ -z "$missing" ]] || log "$side has no screenshot ${missing}(fine for a screen the base does not have yet)"
  log "$side is down; its copies to post are in $DIR/$side/post"
}

# --- post -----------------------------------------------------------------------

# evidence_files <bundle dir> <speed>: what may be uploaded, as JSON
# [{label, path}], paths relative to the bundle dir: the plan's screenshots
# and the video of each side that evidence.sh brought up and down. Nothing
# else, whatever else lies there.
evidence_files() {
  local dir="$1" speed="$2" side state shot sides=() out=()
  for side in base head; do
    state="$(side_state "$dir" "$side")"
    case "$state" in
      down) sides+=("$side") ;;
      up) log "$side is still up: evidence.sh down $side first; nothing of it is uploaded" ;;
      *) log "$side did not go through evidence.sh up and down; nothing of it is uploaded" ;;
    esac
  done
  ((${#sides[@]} > 0)) || die "no side went through evidence.sh up and down: nothing to post"
  for side in "${sides[@]}"; do
    while read -r shot; do
      if [[ -e "$dir/$side/post/$shot.png" ]]; then
        out+=("$(jq -nc --arg l "$side:$shot" --arg p "./$side/post/$shot.png" '{label: $l, path: $p}')")
      fi
    done < <(jq -r '.screens[] | "\(.n)-\(.slug)"' "$dir/plan.json")
    if [[ -e "$dir/$side/post/video-${speed}x.mp4" ]]; then
      out+=("$(jq -nc --arg l "$side:video" --arg p "./$side/post/video-${speed}x.mp4" '{label: $l, path: $p}')")
    fi
    for shot in "$dir/$side/post"/*; do
      [[ -e "$shot" ]] || continue
      jq -e --arg f "$(basename "$shot")" --arg v "video-${speed}x.mp4" \
        '$f == $v or any(.screens[]; "\(.n)-\(.slug).png" == $f)' "$dir/plan.json" >/dev/null ||
        log "not uploading $side/post/$(basename "$shot"): the plan does not name it"
    done
  done
  printf '%s\n' ${out[@]+"${out[@]}"} | jq -s .
}

# The section while uploading: one link per file, under its label, which
# `gh --attach` rewrites to the uploaded URL in place.
staging_section() {
  jq -r --arg start "$MARK_START" --arg end "$MARK_END" '
    [$start, "Uploading the before/after evidence.", "",
     (.[] | "[pr-evidence:\(.label)](\(.path))", ""), $end] | join("\n")' <<<"$1"
}

# uploaded_urls <body>: label -> URL of every staged link gh rewrote.
uploaded_urls() {
  tr -d '\r' <"$1" |
    { grep -oE '\[pr-evidence:[a-z]+:[0-9a-z_-]+\]\([^)]+\)' || true; } |
    sed -E 's/^\[pr-evidence:([^]]+)\]\((.*)\)$/\1	\2/' |
    jq -Rn '[inputs | split("\t") | select(.[1] | startswith("https://")) | {(.[0]): .[1]}] | add // {}'
}

# check_uploaded <files> <urls>: every file came back with its URL.
check_uploaded() {
  local missing
  missing="$(jq -nr --argjson f "$1" --argjson u "$2" '[$f[] | select($u[.label] == null) | .path] | join(", ")')"
  [[ -z "$missing" ]] || die "not uploaded: $missing; run evidence.sh post again"
}

# render_section <plan> <urls> <meta>
render_section() {
  jq -r --argjson urls "$2" --argjson meta "$3" --arg start "$MARK_START" --arg end "$MARK_END" \
    -f "$EVIDENCE_SCRIPTS/evidence-section.jq" "$1"
}

# A section starts at the start of a line; a marker quoted in a sentence is
# not one.
has_section() { tr -d '\r' <"$1" | grep -q "^$MARK_START"; }

# Prints its arguments as lines, without leading or trailing blank lines.
lines() {
  local text
  text="$(printf '%s\n' "$@")"
  while [[ "$text" == $'\n'* ]]; do text="${text#$'\n'}"; done
  printf '%s' "$text"
}

# splice_section <body> [<section>]: the body with every evidence section
# replaced by the section, where the first one stood; without one, with the
# section before the "Generated with" trailer, or at the end. Without a
# section, the sections come out and a body that has none stays as it is.
splice_section() {
  local section="" line inside=0 found=0 trailer=-1 i part text=""
  local before=() after=()
  [[ -n "${2:-}" ]] && section="$(<"$2")"
  if [[ -z "$section" ]] && ! has_section "$1"; then
    cat "$1"
    return
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" == "$MARK_START"* ]]; then
      inside=1
      found=1
      continue
    fi
    if ((inside)); then
      [[ "$line" == "$MARK_END"* ]] && inside=0
      continue
    fi
    if ((found)); then after+=("$line"); else before+=("$line"); fi
  done <"$1"
  if ((!found)); then
    for ((i = ${#before[@]} - 1; i >= 0; i--)); do
      if [[ "${before[i]}" == "🤖 Generated with"* ]]; then
        trailer=$i
        break
      fi
    done
    if ((trailer >= 0)); then
      after=("${before[@]:trailer}")
      before=("${before[@]:0:trailer}")
    fi
  fi
  for part in "$(lines ${before[@]+"${before[@]}"})" "$section" "$(lines ${after[@]+"${after[@]}"})"; do
    [[ -n "$part" ]] || continue
    text="${text:+$text$'\n\n'}$part"
  done
  printf '%s\n' "$text"
}

remove_worktrees() {
  local side worktree
  for side in base head; do
    worktree="$(worktree_of "$side")"
    [[ -d "$worktree" ]] || continue
    [[ ! -d "$worktree/apps/mobile/app/build/run-app" ]] || "$worktree/$RUN_APP_PATH" down >/dev/null 2>&1 || true
    git -C "$REPO" worktree remove --force "$worktree" || log "could not remove $worktree"
  done
  git -C "$REPO" worktree prune
}

evidence_post() {
  local pr="" dry=0 files urls meta head_now
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --speed) args+=(--speed "${2:?--speed needs a number}"); shift 2 ;;
      -*) die "unknown option $1" ;;
      *) pr="$1"; shift ;;
    esac
  done
  STEP="post"
  parse_speed ${args[@]+"${args[@]}"}
  STEP="post"
  require_plan
  files="$(evidence_files "$DIR" "$SPEED")"
  meta="$(jq -nc --arg b "$(git -C "$REPO" rev-parse --short "$(ev_get BASE_SHA)")" \
    --arg h "$(git -C "$REPO" rev-parse --short "$(ev_get HEAD_SHA)")" --argjson s "$SPEED" \
    '{base: $b, head: $h, speed: $s}')"
  if ((dry)); then
    render_section "$DIR/plan.json" "$(jq -c 'map({(.label): .path}) | add // {}' <<<"$files")" "$meta"
    return
  fi

  PR="${pr:-$(ev_get PR)}"
  PR="${PR:-$(gh pr view --json number -q .number 2>/dev/null || true)}"
  [[ -n "$PR" ]] || die "no pull request for this branch: open it (gh pr create), then post"
  head_now="$(gh pr view "$PR" --json headRefOid -q .headRefOid)"
  [[ "$head_now" == "$(ev_get HEAD_SHA)" ]] ||
    log "#$PR's head is $(git -C "$REPO" rev-parse --short "$head_now" 2>/dev/null || printf '%s' "$head_now") now, the evidence shows $(git -C "$REPO" rev-parse --short "$(ev_get HEAD_SHA)"): plan again if the screens changed since"

  local attach=() path
  while read -r path; do attach+=(--attach "$path"); done < <(jq -r '.[].path' <<<"$files")
  gh pr view "$PR" --json body -q .body >"$DIR/body-before.md" || die "could not read the body of #$PR"
  staging_section "$files" >"$DIR/section-staging.md"
  splice_section "$DIR/body-before.md" "$DIR/section-staging.md" >"$DIR/body-staging.md"
  # Relative paths, resolved from the bundle: no local path reaches the body.
  (cd "$DIR" && gh pr edit "$PR" --body-file body-staging.md "${attach[@]}" >/dev/null) ||
    die "the upload failed; whatever uploaded is in #$PR's body: run evidence.sh post again"
  gh pr view "$PR" --json body -q .body >"$DIR/body-uploaded.md"
  urls="$(uploaded_urls "$DIR/body-uploaded.md")"
  check_uploaded "$files" "$urls"
  render_section "$DIR/plan.json" "$urls" "$meta" >"$DIR/section.md"
  splice_section "$DIR/body-uploaded.md" "$DIR/section.md" >"$DIR/body-final.md"
  gh pr edit "$PR" --body-file "$DIR/body-final.md" >/dev/null || die "could not write the section into #$PR"
  remove_worktrees
  printf 'evidence: posted to %s\n' "$(gh pr view "$PR" --json url -q .url)"
}

# --- status and clean -----------------------------------------------------------

evidence_status() {
  STEP="status"
  require_plan
  printf 'pull request  %s\nbase          %s\nhead          %s\nbundle        %s\n' \
    "${PR:-$(ev_get PR)}" "$(ev_get BASE_SHA)" "$(ev_get HEAD_SHA)" "$DIR"
  printf 'base          %s\nhead          %s\n' "$(side_state "$DIR" base)" "$(side_state "$DIR" head)"
  print_plan "$DIR/plan.json"
}

evidence_clean() {
  STEP="clean"
  [[ -f "$EV_STATE" ]] || {
    log "no plan"
    return
  }
  DIR="$(ev_get DIR)"
  local side
  for side in base head; do
    if [[ "$(side_state "$DIR" "$side")" == up ]]; then mark_side "$DIR" "$side" down; fi
  done
  remove_worktrees
  rm -rf "$EV_DIR"
  log "clean; the bundle stays in $DIR"
}

evidence_main() {
  case "${1:-help}" in
    plan) shift; evidence_plan "$@" ;;
    up) shift; evidence_up "$@" ;;
    down) shift; evidence_down "$@" ;;
    post) shift; evidence_post "$@" ;;
    status) evidence_status ;;
    clean) evidence_clean ;;
    help | -h | --help) evidence_usage ;;
    *)
      evidence_usage >&2
      exit 64
      ;;
  esac
}

# Sourced by evidence.test.sh, which calls the functions itself.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  evidence_main "$@"
fi
