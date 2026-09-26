# emotely

Rebuild of the original emotely journaling app around a tools-first AI harness.
Read [`README.md`](README.md) for the architecture and [`docs/adr/`](docs/adr/)
for the load-bearing decisions.

Agents are first-class citizens here: every action must be executable by an
agent end to end — building, running, testing, deploying, verifying — with a
human in the loop only for critical steps such as production access and secret
handling. If a step is only documented for humans, move it into a skill.

## Corrections go up a layer

Each human correction should be the last of its kind. When one reveals a
*kind* of mistake — the same comment would apply outside this diff — fix it in
the strongest layer that can hold it, not only in the code at hand:

1. **Structure** — types, package boundaries or one blessed way make the
   mistake impossible to write. Agents copy what they see, so this layer
   teaches as well as blocks.
2. **Static analysis** — a lint rule, a compiler flag, a CI gate.
3. **Guidance** — the nearest `AGENTS.md` or a skill.
4. **Human review only** — last resort; the PR says why nothing stronger fits.

A kind of mistake ends as a change in the same PR or a linked follow-up issue
labelled `enhancement`, never as an acknowledgement alone. A correction made
twice was held too low: move it up a layer. A one-off needs only its fix.

## Conventions

- Research the latest version and current API of any dependency, model, or action
  from its canonical source before pinning or calling it — never from memory.
- Before adopting a hosted service that runs per PR (CI runners, coverage,
  anything with a free tier), check its usage limits against tens to hundreds
  of PRs a day; a quota sized for one human's pace runs out at ours.
- Every skill and script must be safe for several agent sessions on one
  machine at once. Name anything machine-wide (a simulator, a registered
  instance, a lock) after the session, keep state in the checkout, let the
  OS assign ports, and put anything shared that cannot be split, such as a
  test account, under a lock that fails fast, names its holder and goes
  stale when the holder dies. The lock in
  `.claude/skills/run-app/scripts/run-app.sh` is the one to reuse.
- `main` is protected: all changes land via squash-merged PR through the merge
  queue, `ci-ok` green on the PR and again on the queue's run.
- Agent guidance is `AGENTS.md`; every `CLAUDE.md` is a symlink to the
  `AGENTS.md` beside it, at the root and in each directory that carries its own
  (`.claude/skills`, `apps/mobile`, `apps/mobile/app`, `apps/web`,
  `apps/web/lib/pages`, `scripts`). Edit the `AGENTS.md`, and put a fact in
  the nearest one rather than here when it only matters in that directory.
- Never point at a skill from an `AGENTS.md`: skill descriptions are already in
  context, so the pointer is noise. Put the fact itself here or in the skill.
- Lints are deny-by-default and always errors: biome `preset: "all"`
  (`biome.jsonc`), all TS strictness flags,
  [`flutter_agent_lints`](https://github.com/peter-trost/flutter_agent_lints)
  (experimental variant; every SDK rule is an error or a reasoned `false`)
  and emotely's own analyzer plugin (`tools/emotely_lints`) with
  `dart analyze --fatal-infos` — never `flutter analyze`, which does not
  report plugin diagnostics. Disabling any rule requires an
  in-config justification comment next to the override. Never fix a
  diagnostic by weakening a rule without that justification.
- Words a user reads — the app, the site, sign-in mails, store listings,
  the companion's prompts — use [`CONTEXT.md`](CONTEXT.md)'s terms, in
  every language; its header says how to add or change one.
- Deferred work goes into an issue, not a comment: the Dart analyzer, biome and the tripwire in CI's `ast-grep` job (rules in `ast-grep/rules/tripwire`, for what those two miss) fail on a TODO or workaround comment and on a suppression without its reason.
- A new custom check is rules for an existing engine, never a hand-rolled
  tool: ast-grep (`ast-grep/rules`, each with a test in `ast-grep/tests`)
  when it depends only on syntax, a Dart analyzer rule only when it needs
  types, and a prebuilt Rust binary only when no rule can express it. First
  list the existing analyzer, biome and shellcheck rules you checked and why
  each falls short, then cover only the gap. Size a tool for hundreds of pull
  requests a day
  ([ADR 0018](docs/adr/0018-custom-checks-are-engine-rules-first.md)).
- An ast-grep rule that names emotely's paths, packages or ADRs goes in
  `ast-grep/rules/architecture`; one that would hold unchanged in a project
  that isn't emotely goes in `ast-grep/rules/tripwire` or a new directory
  beside it, the general set we may share later. Its `files` and `ignores`
  are tested in `scripts/ast-grep.test.sh`, since a rule test has no path.

## Billing

- **Vercel is on Pro since 2026-09-13 and MUST stay there** while emotely is
  in front of testers or customers. The team hosting `emotely-agent` was on
  Hobby from 2026-08-29 (downgraded during the IAKUVO shutdown) and was upgraded
  again for the beta. Hobby is non-commercial-only: Vercel defines commercial
  usage as any deployment "used for the purpose of financial gain of anyone
  involved in any part of the production of the project", with no de-minimis
  threshold, and reserves the right to terminate Hobby projects without notice.
  Never downgrade to save the ~20 USD/month while the app is distributed.
  Source: [Fair Use Guidelines](https://vercel.com/docs/limits/fair-use-guidelines)
  § "Commercial usage"; [Terms of Service](https://vercel.com/legal/terms) § 4.
- **The agent runtime now depends on Pro** (changed 2026-09-15). Gateway
  *access* is not plan-gated, and until now Pro only unlocked peripheral
  features (team-wide provider allowlist, Trace Drains) and more than one
  firewall rate-limit rule
  ([ADR 0008](docs/adr/0008-public-endpoint-abuse-controls.md)) — so the
  runtime genuinely did not depend on the plan. It does now: every model round
  requests **request-level Zero Data Retention**, which Vercel gates to **Pro
  and Enterprise only**
  ([ADR 0003](docs/adr/0003-model-gateway-and-cost-ceiling.md) amendment
  2026-09-15). The gateway's privacy filters fail *closed*, so a downgrade
  would not quietly fall back to weaker privacy — it would **fail every round
  of every session**, taking the app down rather than degrading it. That is
  the safer failure mode, and it turns "stay on Pro" from a billing
  preference into a runtime requirement: a downgrade is an outage, not a
  saving.

## Tooling

- [Entire](docs/tooling/entire.md) — captures agent sessions and links them to
  commits. Active in this repo; capture is automatic. Use `entire why <file>:<line>`
  / `entire checkpoint explain <sha>` to recover the intent behind a change, and
  leave the `Entire-Checkpoint` commit trailer alone.
