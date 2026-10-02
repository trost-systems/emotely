# `main` is protected, because agents will write to it

Every change lands on `main` through a squash-merged pull request that passes a
single required status check (`ci-ok`). Direct pushes are rejected, for admins
too. No approving review is required, so an agent can open a PR and merge it
unattended once CI is green.

The alternative we rejected was committing straight to `main` and relying on fast
rollback. That is a reasonable trade for a solo human — you are your own monitor,
you ran the thing, you saw it break, you revert in thirty seconds. It stops being
reasonable the moment autonomous agents are the ones committing: rollback is a bet
on *detection latency*, and an agent merging unattended has no one watching. During
the window before anyone looks, `main` is the branch every other agent forks from,
so one bad commit becomes the base for the next three.

The deeper reason is that a gate is a **precondition** and a rollback is a
**compensation**. Preconditions compose with autonomy; compensations need a
supervisor, and removing the supervisor is the entire point.

This also makes ADR 0001's promise literally true. The monorepo exists so that "a
schema change plus both sides move in one atomic, CI-verified commit" — direct
pushes with rollback deliver neither atomicity nor pre-merge verification.

## What follows from it

- **Squash-merge only.** Merge commits and rebase-merge are disabled, so one PR is
  always one revertable commit. That property is what makes rollback still work as
  the second line of defense.
- **`ci-ok` is the only required check.** Path filtering means the agent or app job
  may legitimately not run, and a required check that never reports blocks a PR
  forever. `ci-ok` always runs and inspects its dependencies: green when every job
  succeeded *or was skipped*, red when any failed or was canceled. It must never
  be a bare `echo ok` — that reports success unconditionally and is worse than no
  gate, because it manufactures confidence.
- **Enforced for admins.** Not because a human commit is dangerous, but because a
  bypass that is always available gets used reflexively. Bypass is still possible;
  it just costs a deliberate settings change, which is what makes an override
  actually deliberate.
- **Zero required approvals.** The gate is CI, not a human. Agents self-merge.

Who may auto-merge, and whether some paths need a human, are deliberately *not*
decided here — they are settings changes, and they are unanswerable until we have
watched agents actually work.
