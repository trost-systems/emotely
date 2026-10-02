# Privacy policy skills

Researched and installed 2026-09-15. Two agent skills for writing and
reviewing the privacy notices at [`/privacy`](../../apps/web/lib/pages/privacy.dart)
and [`/app-privacy`](../../apps/web/lib/pages/app_privacy.dart). Both are
installed **at user level**, not in this repo: they are general-purpose legal
tooling, not an emotely dependency, and nothing in the build or CI needs them.

They do different jobs and the split matters — one drafts, one catches drift.

## What is installed

| | `privacy-policy` | `privacy-legal` |
|---|---|---|
| Kind | Skill (`~/.claude/skills/privacy-policy`) | Plugin (`privacy-legal@claude-for-legal`) |
| Source | [lawve-ai/awesome-legal-skills](https://github.com/lawve-ai/awesome-legal-skills) (691★) | [anthropics/claude-for-legal](https://github.com/anthropics/claude-for-legal) (9.4k★, first-party) |
| Author | Stephane Boghossian | Anthropic |
| License | **AGPL-3.0** | See upstream repo |
| Job | **Draft** a policy from intake | **Review** a policy against practice |
| Invoke | `/privacy-policy` | `/privacy-legal:<skill>` |

### `privacy-policy` — the generator

Jurisdiction-first: it establishes which laws apply from where users are
*before* drafting, which is what stops generic boilerplate. Its prime
directive is that a policy is a set of **enforceable representations**
(FTC §5), so overclaiming is worse than saying nothing — a clause renders
only if a confirming intake answer exists, and anything unanswered becomes a
visible `[GAP — confirm before publishing]` marker rather than a plausible
guess. It will not invent a statute number, a fine, or an effective date.

It is the only one of the two that knows about app stores. Its
`references/platform-cookies-ai.md` covers the requirements this repo has
already been bitten by:

- Apple **Guideline 5.1.1(i)** — policy linked in App Store Connect *and*
  in-app; **5.1.1(v)** — apps with accounts must offer in-app account deletion.
- The App Privacy **nutrition label must match the policy**.
- Google Play — the **Data Safety form must match the policy**, and an app
  that collects nothing still needs both.
- App Tracking Transparency, and the Kids-category rules.

Ten reference files, ~132K, all markdown. Nothing executes.

### `privacy-legal` — the reviewer

Seven skills; `policy-monitor` is the one that earns its place here. Its
thesis is that policies drift in one direction — practice moves forward and
the policy lags — and it has two modes:

- **Sweep** (`/privacy-legal:policy-monitor`) — diffs the published policy
  against accumulated practice, classifying each gap as **REQUIRED** (the
  policy misrepresents what actually happens) or **ADVISABLE** (the policy is
  merely silent), with drafted replacement language for each.
- **Direct query** (`/privacy-legal:policy-monitor "we want to start doing X"`)
  — returns covered / missing / conflicting before the change ships.

The others — `pia-generation`, `dpa-review`, `dsar-response`,
`reg-gap-analysis`, `use-case-triage`, `cold-start-interview` — are shaped for
an enterprise privacy team. `dsar-response` is the one most likely to matter
next, the first time someone exercises an Art. 15 right.

The plugin ships an `.mcp.json` recommending Slack and Google Drive
connectors. **They are not required** and are not connected; the skills work
against local files.

## Installing

Already done at user level, so a new machine is the only reason to rerun:

```bash
claude plugin marketplace add anthropics/claude-for-legal && claude plugin install privacy-legal@claude-for-legal --scope user
```

The generator is a plain directory copy, since it lives in a monorepo of
skills rather than a marketplace:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/lawve-ai/awesome-legal-skills.git /tmp/als && git -C /tmp/als sparse-checkout set skills/privacy-policy-stephane-boghossian && cp -R /tmp/als/skills/privacy-policy-stephane-boghossian ~/.claude/skills/privacy-policy
```

Verify both:

```bash
claude plugin list | grep -A3 privacy-legal && ls ~/.claude/skills/privacy-policy/references/
```

## Using them on this repo

The two notices are Jaspr components, not markdown, so neither skill can edit
them directly — the workflow is to let the skill produce the text and the
reasoning, then hand-port the wording into the Dart component. That is a
feature rather than a friction: it forces every generated sentence past a
human reading before it reaches a page the controller signs off on.

Run the reviewer whenever what the app *does* changes:

```bash
claude "/privacy-legal:policy-monitor we now request zero-data-retention on every model round"
```

Two things no general-purpose skill will get right here, so they stay a human
judgment:

- **Journal entries are special-category data.** Emotional and mental-health
  content plausibly engages Art. 9 GDPR. Both skills correctly escalate
  health data to a lawyer rather than resolving it; the notice relies on
  explicit consent under Art. 9 (2) (a), recorded as described in
  [ADR 0014](../adr/0014-explicit-consent-as-an-append-only-record.md).
- **The no-training and zero-retention guarantees are representations.**
  Because request-level ZDR is what every model round now asks for
  ([ADR 0003](../adr/0003-model-gateway-and-cost-ceiling.md)), the claim in
  the notice is enforceable against us under FTC §5 and Art. 5 (1) (a) GDPR.
  It is defensible precisely because the gateway **fails closed** — a
  downgrade is an outage, not a silent fallback to a weaker provider — but it
  means the Vercel Pro requirement in [`CLAUDE.md`](../../CLAUDE.md) is now
  load-bearing for a published privacy claim, not just for billing.

Neither skill is legal advice, and both say so.
