---
name: babysit-pr
description: Watch an open PR until it is merged, closed, or genuinely needs the user — polling CI, review threads and mergeability, diagnosing ci-ok failures, fixing what the branch broke, and re-running only what is flaky. Use whenever asked to babysit, monitor or watch a PR, keep an eye on CI, or drive review feedback to zero.
---

# Babysitting a PR

One PR, watched to a terminal state. The loop is: snapshot → decide → act →
snapshot again, until the PR is merged or closed, or something genuinely needs
a human. Green CI is a milestone inside the loop, never a reason to leave it —
review comments arrive after CI goes green, and that is exactly when a watcher
that stopped early costs a round trip.

Everything here is `gh` + `jq`.

## Pick up the PR

```bash
gh pr view --json number,url,state,isDraft,mergeable,mergeStateStatus,headRefName,headRefOid,reviewDecision
```

No argument means the PR for the current branch; otherwise take a number or a
URL and pass it as the first argument to every command below. Confirm the head
SHA before acting on any CI result — a snapshot describes one SHA, and a push
that lands mid-loop invalidates it.

## The snapshot

```bash
gh pr checks --json name,state,bucket,link,workflow | jq -r '
  group_by(.bucket) | map({bucket: .[0].bucket, n: length, names: map(.name)}) | .[]
  | "\(.bucket)\t\(.n)\t\(.names | join(", "))"'
gh pr-review threads list --pr <n> --repo trost-systems/emotely --unresolved
```

`gh pr-review` needs both `--pr` and `--repo`: it does not infer the PR from
the current branch the way `gh pr` does, and a numeric selector without
`--repo` is an error. It prints a JSON array (`[]` when a PR has no inline
threads), so pipe it through `jq` — check the object shape with
`jq '.[0] | keys'` on a PR that has threads before writing a field path
against it.

`gh pr checks` buckets into `pass` / `fail` / `pending` / `skipping`. Read the
buckets, not the individual jobs: this repo's CI is path-filtered, so a PR that
touches only `apps/web` legitimately shows `agent`, `app` and `supabase` as
skipped — **skipped is not failed**, and `ci-ok` is green precisely because it
treats them as fine.

The checks from outside `ci.yml` worth recognizing are the **Vercel** preview
deployments (`emotely-agent`, `emotely-web`, each skipped by its
`vercel-ignore.sh` when that app is untouched).

Secrets are caught by GitHub's own **secret scanning with push protection**,
not by a check: a push containing a known provider's secret is rejected with a
`GH013` "push protection" error, and anything that got through shows up in
`gh api repos/trost-systems/emotely/secret-scanning/alerts`. Triage it first —
test fixtures and example values trip it too. If it is a **real** secret, never
bypass the block: get it out of the history (see [Staying current with `main`](#staying-current-with-main) — this
is the one case where rebasing is right), treat the secret as burned and needing
rotation, and **tell the user**: a real leak is never something to handle
silently. A false positive needs no history surgery, just the finding reported.

## What CI actually means here

`ci-ok` is the only required check ([`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)).
It is a gate job: green only when every other job succeeded or was skipped.
Three consequences for a watcher:

- **Diagnose the job, not the gate.** `ci-ok` failing tells you nothing except
  that something upstream of it failed. Find the real job before reading logs.
- **Cancellation leaves `ci-ok` pending, not failed.** The workflow's
  concurrency group cancels in-flight runs when a new commit supersedes them.
  A pending `ci-ok` on a stale SHA is not a hang — check whether the head SHA
  moved before investigating.
- **A fork PR skips the live eval** for want of a gateway key, and that is
  expected. On a branch in this repo a missing `AI_GATEWAY_API_KEY` is a broken
  `ci` environment and fails loudly — that one is the user's, not yours to patch.

## Reading a failure

```bash
gh run list --commit "$(gh pr view --json headRefOid -q .headRefOid)" \
  --json databaseId,name,status,conclusion,url
gh api "repos/{owner}/{repo}/actions/runs/<run-id>/jobs" --jq \
  '.jobs[] | select(.conclusion == "failure") | {id, name, html_url}'
gh api "repos/{owner}/{repo}/actions/jobs/<job-id>/logs" > "$TMPDIR/job-<job-id>.log"
```

`{owner}/{repo}` is expanded by `gh` from the current repo — leave it literal.
Write logs to a scratch path, never into the worktree: an untracked log file
would show up as an unrelated change on the next commit.

Go to the failed job's log as soon as that job fails. `gh run view --log-failed`
is run-scoped and stays empty until the whole run finishes, so on a PR that
touches several apps you would wait for the slowest job to diagnose the one
that already failed.

Then classify, and let the classification decide the action:

- **Branch-related** — a compile, analyze, format, test or coverage failure in
  code this PR touched. Fix it. See [references/failures.md](references/failures.md)
  for what each job's failure output looks like in this repo and which command
  reproduces it locally.
- **Flaky or infrastructural** — runner provisioning, a network or registry
  timeout, an Actions outage. Re-run it, at most **3 times** per SHA, then stop
  and report.

Never close the gap between those two by weakening the thing that caught it.
Lints here are deny-by-default and generated code is committed and
tripwired; a red check is usually correct. Silencing a rule, loosening a
coverage threshold or regenerating a committed artifact to make CI quiet is a
change to the repo's standards, and that is the user's call — surface it instead.

```bash
gh run rerun <run-id> --failed
```

## Reading review feedback

```bash
gh pr-review threads list --pr <n> --repo trost-systems/emotely --unresolved
gh pr-review review view --pr <n> --repo trost-systems/emotely --unresolved | jq -r '
  .reviews[] | .comments[]? | [.thread_id, .author_login, (.body | split("\n")[0])] | @tsv'
gh pr view <n> --json comments,reviews   # top-level comments and submissions
```

`threads list` carries no author; `review view` does, and the author decides
whether a thread is the user's or another human's.

Ignore reviews still in `PENDING` state — the reviewer has not submitted them,
and acting on a half-written review is both wrong and visible. Threads already
marked resolved are done unless new unresolved feedback hangs off them.

When a comment is correct and actionable, fix it in code, push, and then
resolve its thread once its [layer is recorded](#classifying-a-correction):

```bash
gh pr-review threads resolve --pr <n> --repo trost-systems/emotely --thread-id <id>
```

When it is ambiguous, wrong, asks a question, or wants a product decision,
**bring it to the user in chat with a suggested reply** rather than answering on
GitHub. Writing to a review thread is visible to other people, so it follows
one rule: never leave a GitHub trace that makes it hard to tell whether the user
or an agent did something.

- Resolve threads the user opened.
- Leave threads where other humans are participating — report those instead,
  with your classification in the suggested reply.
- Post a reply only when the user has confirmed the exact text, and prefix it with
  `[from Claude]: ` so its origin is unambiguous. The one exception is the
  layer record below on a thread the user opened: it states what was done, not
  a position, so it needs no confirmation.
- Never mark the PR draft or ready, never close or reopen it, never dismiss a
  review.

```bash
gh pr-review comments reply --pr <n> --repo trost-systems/emotely \
  --thread-id <id> --body '[from Claude]: ...'
```

### Classifying a correction

Classify every thread before resolving it, against the four layers in the
root `AGENTS.md`:

- **One-off** — true of this diff only: a typo, a wrong value, a misread
  requirement. The fix is the whole answer.
- **Kind of mistake** — the reviewer would write the same comment on another
  PR. Pick the strongest layer that can hold it, then either
  - build that layer in this PR, beside the fix, when it fits the PR's scope; or
  - open a follow-up when the layer is its own piece of work (a lint plugin, a
    refactor across packages), and link it in the reply:
    `gh issue create --label enhancement --title '...' --body '...'`, with the
    thread URL in the body and a line saying Claude opened it from review.

  Layer 4 also goes in the PR description, with why nothing stronger fits.

A kind of mistake closes only with a commit or a linked issue; a reply alone
leaves it to be made again. Before picking the layer, look for an earlier
record of the same kind:

- **A rule that should have caught it** — an `AGENTS.md` line, a skill step, a
  lint that misses this case. The correction has now been made twice: go one
  layer above that rule.
- **An open follow-up** — `gh issue list --label enhancement --search '<keywords>'`.
  Link it instead of opening a second.

Unsure whether it is a kind at all? Treat it as an ambiguous comment and bring
it to the user with your guess.

Record the call on the thread, then resolve it:

```text
[from Claude]: Fixed in <sha>. One-off.
[from Claude]: Fixed in <sha>. Kind of mistake → layer 2: <the rule> in <sha>.
[from Claude]: Fixed in <sha>. Kind of mistake → layer 1: follow-up #<n>.
```

## Merging is the user's, unless they hand it to you

Report that a PR is ready; let the user merge it. Do not merge a PR on your own
initiative — not because CI is green, not because it looks routine.

**The exception is the user explicitly asking you to merge.** Then merge it,
once it is actually ready: `ci-ok` green, `mergeable: MERGEABLE`, no unresolved
threads, and no pending review asking for changes. An instruction to merge is
not an instruction to bypass the gates — if the PR is not ready, keep watching
and merge when it becomes ready, or report what is blocking it.

```bash
gh pr merge <n> --squash
```

`main` requires a merge queue, so this **enqueues** the PR rather than merging
it: the queue tests it on a `gh-readonly-queue/main/…` branch against what
`main` will be, and squash-merges it when that run's `ci-ok` passes. Do not
pass `--delete-branch` (gh rejects it with a queue; the repo deletes merged
branches itself) or `--admin` (nobody bypasses the queue). The merge is done
only when `state` is `MERGED`. Queue state is GraphQL-only:

```bash
gh api graphql -F owner=trost-systems -F name=emotely -F n=<n> -f query='
  query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){
    pullRequest(number:$n){state isInMergeQueue mergeQueueEntry{position state}}}}'
```

If the PR drops out of the queue unmerged, the queue's own CI run failed: the
PR timeline says why, and the failing run is the CI run on the
`gh-readonly-queue/main/pr-<n>-…` branch. Diagnose it like any `ci-ok`
failure, fix it on the branch, and enqueue again.

Stacked PRs go through `gh stack merge <stack> --yes`, which enqueues the whole
stack (it detects the queue and ignores `--squash`); never merge a stacked PR
on its own.

"Explicitly" means the user asked for *this* merge — "merge it", "ship it",
"land it once green". A general "babysit this PR", "keep an eye on CI" or "get
this through" is not authorization to merge: babysitting is watching, and the
standing rule still holds. When you are unsure which you were given, ask —
merging is not reversible by you.

## Staying current with `main`

A branch that is merely **behind** `main` needs nothing: the merge queue tests
it against the latest `main` anyway, so do not spend a CI run on
`gh pr update-branch` just to catch up. (If you ever do run it, it creates a
merge commit by default — keep it that way; outside the secret-leak case below,
never pass `--rebase`.)

When it **conflicts**, the queue cannot build it, so resolve it by merging
`main` into the branch — **not by rebasing**:

```bash
git fetch origin main
git merge origin/main      # resolve, commit, push
```

A rebase rewrites every SHA on the branch, which throws away the "changes since
you last looked" view a reviewer depends on and re-anchors their comments. Once
a PR has a review on it, that cost is real, and the merge commit that bothers
people is not: `main` squash-merges, so the branch's internal history collapses
to a single commit and the merge commits never reach it.

Before a first review has landed, either is harmless — but merging is still the
default, so there is one rule rather than a judgment call about how "reviewed"
a PR is.

**The one exception is a real secret in the history.** There, rewriting is the
point: the commit must leave the branch immediately, so rebase (or filter) it
out, force-push, and tell the user so the secret can be rotated. Making the
reviewer's diff harder to read is worth it to get a live credential out of a
public repo.

If a conflict needs a decision about *intent* — two changes that are both
deliberate and disagree — resolving it is not the poll loop's call. Report it
with what each side wants and stop.

## The loop

The PR goes through two phases that want different waiting strategies. Use
`--watch` for the first and polling for the second; the phases alternate
whenever a new commit lands.

### While CI is running: block on `--watch`

```bash
timeout 1200 gh pr checks <n> --required --watch --fail-fast --interval 30
```

This blocks until the required check settles instead of burning a poll every
minute. Each flag is load-bearing:

- **`--required`** watches `ci-ok` alone. Watching every check would also block
  on the Vercel previews, and `ci-ok` is the only gate that decides mergeability.
- **`--fail-fast`** returns the moment a check fails, so diagnosis starts
  immediately rather than after the remaining jobs finish.
- **`timeout 1200`** is the stall safeguard. `--watch` waits forever on a queued
  job, a stuck runner, or a check that never reports. Twenty minutes is
  comfortably longer than a normal run here; if `timeout` fires (exit **124**),
  that is a signal to look, not to re-enter the watch blindly.

Read the exit code — it is the result:

| Exit | Meaning | Do |
| --- | --- | --- |
| `0` | required checks passed | go to the green phase |
| `8` | checks still pending | re-check state, then resume |
| `124` | `timeout` fired — stalled | inspect the run; don't blindly re-watch |
| `4` | `gh` needs auth | stop; the user has to re-auth |
| `1` | a check failed, **or** `gh` itself errored | read the output before assuming a failed check |

Do not treat a non-zero exit as "a check failed" without looking: `1` is also
`gh`'s generic error, so a network blip or a bad PR number lands there too.
Confirm against a `gh pr view` snapshot before you start patching code.

**`--watch` is blind to everything except checks.** It cannot see merge
conflicts, review comments, or the PR being closed — `mergeable` and
`reviewDecision` come only from `gh pr view`. So never treat a watch as the
whole loop: bracket it with a `gh pr view` snapshot before and after. That
closes the "watch sits idle while a conflict appears" gap, because the conflict
is caught the moment the watch returns rather than never.

If CI is expected to run long, prefer a shorter `timeout` and loop the watch,
taking a snapshot between iterations — the snapshot is the point.

### Once CI is green: poll every 3–5 minutes

With checks settled there is nothing to block on. What remains — review
comments, approvals, a conflict appearing when `main` moves — has no watch
primitive at all, so it is a sampling problem:

```bash
sleep 240
gh pr view <n> --json state,mergeable,mergeStateStatus,reviewDecision,headRefOid
gh pr-review threads list --pr <n> --repo trost-systems/emotely --unresolved
```

Four minutes is the right order of magnitude: a human reviewer's feedback does
not get stale in that window, and it is ~15 calls/hour instead of 60. Drop back
to `--watch` the moment the head SHA changes — a new commit means CI is running
again.

Each pass, in either phase, in this order:

1. **Merged or closed?** Report the terminal state and stop.
2. **New review feedback?** Handle it before CI. A review fix produces a new
   commit, which retriggers CI anyway — so acting on review first avoids
   re-running checks on a SHA you are about to replace.
3. **Failed checks?** Diagnose, then fix (branch-related) or re-run (flaky).
4. **Mergeable?** Check for conflicts (being behind `main` is fine). If the
   user asked you to merge this PR and it is now ready, enqueue it here, then
   keep watching until the queue merges it or drops it — waiting for a further
   go-ahead just costs a round trip.
5. Otherwise wait and repeat.

After any push, start again from the new SHA in the same turn. A push is not a
finish line, and neither is the first all-green snapshot.

## Reporting

While watching, report only changes and the occasional heartbeat — not every
poll. Say it once when CI first goes green for a SHA, then keep watching.

Stop and hand back only when the PR is merged or closed, when it is ready and
merging it was not yours to do, or when you are actually blocked: the retry
budget is spent, `gh` auth or push permission fails, the worktree holds
unrelated uncommitted changes, a conflict turns on a
question of intent, or a reviewer is asking for a decision that is not yours to
make. Say which of those it is, and what you would do next.

Tell the user right away — without waiting for a stop condition — if a real
secret reached the history, or if CI is failing in a way whose only fix would
weaken a lint, a coverage gate or a tripwire.

Final summary: head SHA, CI status, mergeability, what you pushed, how many
re-runs you spent, each thread's class and layer (with any follow-up
issue), and anything still open.
