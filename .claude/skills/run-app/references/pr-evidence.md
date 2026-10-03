# Before/after evidence on a pull request

`scripts/evidence.sh` puts before/after screenshots, and a 4x video for a
flow, into a pull request's description. It does everything except drive
the app: it maps the diff to screens, checks out the base and the head in
worktrees of their own, runs `run-app.sh up` and `down` in each, makes the
posting copies, uploads them with `gh pr edit --attach` and writes the
section. You drive each planned screen with marionette in between, with the
feature map's `reach`, exactly as in [verification.md](verification.md).

```bash
E=.claude/skills/run-app/scripts/evidence.sh
$E plan                 # this branch's PR; or `$E plan <pr>` for another one
$E up base              # prints the instance, each screen's reach and its screenshot command
# drive to each planned screen; save it under the printed name, e.g.
#   marionette -i <instance> take-screenshots --output <bundle>/01-journal.png
$E down base            # always, also after a failure
$E up head              # the same screens, the same names
$E down head
$E post                 # uploads and writes the section; a re-run replaces it
```

A few minutes for each side's `up` (the worktree's build, the boot and the
sign-in; under three on #288), then your driving; `down` takes seconds. `$E status` shows where a run stands; `$E clean`
brings an abandoned run down and removes its worktrees (the bundle stays in
`apps/mobile/app/build/evidence/`).

## What it plans

- **Screens.** A changed file under a feature package's `lib/` or `l10n/`
  changes the screens whose `package` it is in the feature map. The design
  system and the app itself (`apps/mobile/app` `lib/`, `l10n/`, `assets/`)
  change every screen: the ones a feature change names first, then the
  rest in map order, at most `--max` (default 4); the section names what it
  left out. Tests, other utilities, scripts and docs change no screen.
  `--screens journal,more` (slug or route) names them yourself.
- **No screen** ends at `plan`: nothing to drive, no section, and a section
  an earlier run left on the PR comes out.
- **Video.** A screen marked `flow: true` in the feature map (a session,
  onboarding, sign-in) gets one; `--video` / `--no-video` decide otherwise.
  `up` starts recording once signed in and `down` stops it, so drive
  straight through: the copy plays four times faster (`down --speed N` and
  `post --speed N` for another speed; use the same on both).
- **Order.** The plan keeps the map's order, which visits the signed-out
  screens (Welcome, sign-in) last: the way back in from them is `down`.

The plan reads the head's own feature map, so a pull request that adds a
screen plans it; skip a screen the base does not have yet. A screenshot
missing on one side leaves a caption saying so.

## Why the agent drives

The feature map's `reach` is knowledge, not a script, and it stays that
way: the steps need judgment a runner would have to encode — poll until a
model round answers, discard a session the account left open, agree to
consent only while it is missing, pick the newest entry, sign out last. A
runner of those steps would be a homemade flow language, the flow runner
the project decided against (scripted journeys belong in patrol, #38). So
the command does the parts that are the same every time, and the agent
does the driving with the same commands it uses to verify any change.

## Privacy

Attachments on this public repository are public (ADR 0005), and the
screenshots show the real app, every screen, nothing blacked out. So
everything the smoke account shows is published: its address (More and
Profile show it), its name and its journal entries. All of it must be made
up.

- **A publishable address, or no evidence.** `up` and `post` refuse unless
  the smoke address is on a domain reserved for documentation, which has no
  real inbox (example.com, example.net, example.org and their subdomains,
  or a `.test` or `.example` domain; RFC 2606), or on a domain listed in
  `EVIDENCE_PUBLIC_DOMAINS` (comma-separated, in `apps/agent/.env.local`)
  for a dedicated public alias. Your personal address as smoke account gets
  a refusal that names this fix.
- Each side runs through `run-app.sh up`, which signs in as the smoke
  account and refuses any other address. Its build hides the DEBUG banner,
  so the screenshots look like the installed app.
- `post` uploads only the plan's screenshots and the video of a side that
  `evidence.sh up` and `down` handled, nothing else in the bundle.
- It uploads by paths relative to the bundle, so no local path (your user
  name) reaches the body or its public edit history.
- What you type is made-up content, and so is what the account already
  holds. Text logs in the bundle stay scrubbed of the address, password and
  user id as before; only the pictures show the address.

## How the upload works

`gh pr edit --attach` (gh 2.99+) rewrites the destination of a Markdown
link or image that names an attached file, `[text](./file)` or
`![alt](./file)`, to the uploaded URL, and appends files the body does not
name. An HTML `<img src="./file">` stays as written: gh parses Markdown, and
an HTML block is not Markdown. A width needs `<img>`, so `post` uploads in
two edits:

1. The body with a staging section of one link per file,
   `[pr-evidence:base:01-journal](./base/post/01-journal.png)`, plus one
   `--attach` per file, run from the bundle. gh rewrites each link in place.
2. The URLs read back by label, then the final section: one table row per
   screen, before and after side by side, each `<img width="300">` over its
   caption, and each video URL alone in its paragraph, which GitHub plays.

The section sits between `<!-- pr-evidence:start -->` and
`<!-- pr-evidence:end -->`, before the "Generated with" trailer, and a
re-run replaces it in place. On another agent's pull request this edits
the description only; it pushes nothing.

## Several sessions at once

Each side's worktree is `.claude/worktrees/evidence-<session>-<side>` in the
main checkout, its run-app session is named after the worktree, and the
plan lives in this checkout's `apps/mobile/app/build/pr-evidence/`. The
smoke account runs one session at a time: `up` waits while another
session holds its lock (30 minutes, `EMOTELY_EVIDENCE_WAIT` sets them),
tries again when another session takes it first, and never takes it from a
live holder. Base and head run one after the other for the same reason.
