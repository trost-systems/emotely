---
name: open-pr
description: How to open a pull request in emotely — branch, commits, the Entire checks around a push, the title and body, and before/after screenshots and video in the description when the diff changes a screen (evidence.sh). Use whenever opening, pushing or describing a pull request, or putting evidence into one.
---

# Opening a pull request

A pull request is open when its branch is pushed, its description says why,
a screen it changes shows before and after, and `ci-ok` is green. Merging
is the user's; `babysit-pr` watches it from here.

## 1. Branch

From the latest `main`, whatever the checkout sits on:

```bash
git fetch origin main && git switch -c <type>/<topic> origin/main
```

That sets the upstream to `origin/main`; the first push below sets it to the
branch.

## 2. Commit

A conventional subject, `type(scope): what it does` (`feat(run-app): …`,
`fix(web): …`, as `git log` shows), a body that says why, and the
`Co-Authored-By:` trailer your session's attribution names as the last line.
Leave Entire's `Entire-Checkpoint` trailer as it writes it.

## 3. Push, between two Entire checks

The repository is public and the session transcripts are private, so a
push must never carry `refs/entire/*` to `origin`
([docs/tooling/entire.md](../../../docs/tooling/entire.md) says why and how
to recover a leaked ref):

```bash
entire status | grep 'Checkpoints sync to'   # must name trost-systems/emotely-checkpoints
git push -u origin <branch>
git ls-remote origin 'refs/entire/*'          # must print nothing
```

Anything else in the first line (an owner mismatch, no checkpoint remote)
stops the push until it does.

## 4. Open it

```bash
gh pr create --base main --title '<the subject of step 2>' --body-file <file>
```

The title becomes the squash commit on `main`. The body:

- **Why first.** The diff shows what changed; the body says why, what was
  decided and what a reviewer should look at.
- **Abbreviations written out** on first use, the abbreviation in
  parentheses: pull request (PR), continuous integration (CI).
- **`Closes #n`** when it completes the issue's acceptance criteria,
  **`Refs #n`** when it does not yet, with what is left.
- US English, as `pnpm spell` holds the repository to.
- Last line: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

Write it to a file and pass `--body-file`; `gh pr edit <n> --body-file`
updates it later.

## 5. Evidence, when the diff changes a screen

A diff that touches a feature package's `lib/` or `l10n/`, the design
system, or `apps/mobile/app` changes a screen, and its description carries
before/after screenshots, plus a 4x video for a flow:

```bash
E=.claude/skills/open-pr/scripts/evidence.sh
$E plan            # the screens the diff changes; none ends here, adding nothing
$E up base         # drive each planned screen, save it under the printed name
$E down base
$E up head         # the same screens
$E down head
$E post            # uploads with gh --attach, writes the section
```

Run it again after a push that changes a screen: the section is replaced.
`$E plan <pr>` does the same for another agent's pull request, editing
only its description. Running it, what it plans, uploads and refuses, and
the smoke account it needs — read
[references/evidence.md](references/evidence.md) first.

## 6. Green, then hand over

The pull request is done here when `ci-ok` is green on its head:

```bash
timeout 1200 gh pr checks <n> --required --watch --fail-fast --interval 30
```

A red check, a review thread, keeping it current: `babysit-pr`. Merging and
enqueuing are the user's unless they ask for this one, and then
`babysit-pr` has the merge-queue steps.
