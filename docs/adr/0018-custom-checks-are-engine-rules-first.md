# Custom checks are rules for an existing engine first, Rust programs last

A check of our own is written as rules for an existing fast engine before it
is ever written as a program: ast-grep for anything syntactic, the Dart
analyzer only for checks that need types. A check that no rule can express
becomes a Rust program shipped as a prebuilt binary. Decided on 2026-09-25,
while reworking the comment tripwire (#166, pull request #176); #165 and #170
build their lints on it.

## Context

The first version of the comment tripwire was a Node package,
`packages/tripwire`, with its own lexers for Dart, TypeScript and shell. It
was fast enough: about 0.2 s of CPU over the whole tree. Speed is not what
fails at scale. What fails is the parsers: every new language, string form
or comment form needs another hand-written lexer, and every lint after it
(#165, #170) would need the same lexers or a second set. The codebase will
keep growing through pivots, and tooling written for today's size and
today's languages gets rewritten later. We would rather not write it twice.

## Decision

1. **A new custom check starts as rules for an existing fast engine.**
   - **ast-grep** for anything that depends only on syntax. It is written in
     Rust on tree-sitter grammars and has Dart, TypeScript, Bash and YAML
     built in. Rules are YAML with their own test runner (`ast-grep test`,
     valid and invalid cases with snapshots). It installs from npm
     (`@ast-grep/cli`, pinned in the root `package.json`) as a prebuilt
     binary, so no Rust toolchain is needed.
   - **The Dart analyzer** (a lint rule or an analyzer plugin) only when a
     rule needs type information.
2. **Only a check that cannot be expressed as rules becomes a program.** It
   is written in Rust and shipped as a prebuilt binary, so CI and agents
   never compile it.
3. **Never reimplement what an existing tool already does**: the Dart
   analyzer, biome, shellcheck. Before a custom check is written, it lists
   the existing rules it looked at in the tool that owns each language, and
   why each falls short. The list goes into the check's ADR or pull request,
   and the check covers only the gap. The tripwire below is the first
   instance: it skipped this step at first and was trimmed after review
   (see [What the tripwire leaves to existing tools](#what-the-tripwire-leaves-to-existing-tools)).
4. **Size tools for growth**: tens to hundreds of pull requests a day, and a
   codebase many times larger than today's.

`sgconfig.yml` at the repository root points ast-grep at `ast-grep/rules`
and `ast-grep/tests`. `scripts/ast-grep.sh` runs every rule over the files
git tracks; CI's `ast-grep` job runs the rule tests, the script's own tests
and the scan, and feeds `ci-ok`. A new syntactic rule is one YAML file under
`ast-grep/rules` plus its test under `ast-grep/tests`; the scan picks it up
with no other change (see [Adding a rule](#adding-a-rule)). The script and
the job were called `tripwire` until #165 added the first rule that is not
about comments.

## Measurements

On 2026-09-25, over the about 275 tracked Dart, TypeScript and shell files:

| | Wall time | CPU |
|---|---|---|
| Node tripwire (`packages/tripwire`) | 0.4–0.7 s | about 0.2 s |
| ast-grep 0.45.3, first draft of the rules | 0.03–0.33 s | about 0.2 s |
| ast-grep 0.45.3, the full port | 0.16–0.21 s | about 0.4 s |
| ast-grep 0.45.3, trimmed to the gaps (2026-09-26) | 0.08–0.16 s | about 0.3 s |
| CI job overhead (checkout, setup, install) | 10–20 s | |

The engine is not faster in any way that matters today; both are noise
next to the job overhead. It is chosen for what it saves later: real
parsers for every language we add, and one rule format for every check.

## Alternatives considered

- **Keep the Node tripwire.** It works and is fast enough, but each check
  and each language adds hand-written parsing that we own for good.
- **Rewrite the tripwire in Rust.** Faster, but CI would need prebuilt
  binaries or a compile step, and the parsing would still be hand-written.
  That is the same problem in a faster language.
- **Bend.** A young language for automatic parallelism on CPUs and GPUs. It
  has no parsers for our languages, and a checker's work is parsing, not
  arithmetic.

## What the tripwire leaves to existing tools

The first port reimplemented checks our linters already run. Review caught
it on 2026-09-26, and the tripwire now covers only what they miss. Each row
was verified that day against the pinned versions: `flutter_agent_lints`
1.0.1 (its `errors.yaml`) under the Dart 3.13 analyzer, biome 2.5.14, and
shellcheck. The Dart and biome rows were probed on scratch files.

| Language | Already covered, so not in the tripwire | Gap the tripwire covers |
|---|---|---|
| Dart | Upper-case `TODO`, `FIXME` and `HACK` in any comment (`todo`, `fixme`, `hack`: errors). A comment that opens with a lower-case `todo` (`flutter_style_todos`). A reason on every `ignore:` and `ignore_for_file:` (`document_ignores`), and stale ignores (`unnecessary_ignore`). | `XXX`, and the lower-case tag forms (`fixme(`, `hack:`, a `todo:` mid-comment). The workaround phrases. A reason on `coverage:ignore-*` and `cognitive_complexity:ignore*`, which neither the analyzer nor those tools check. |
| TypeScript | `biome-ignore` without an explanation (`suppressions/parse`, an error). Any `@ts-ignore` (`noTsIgnore`). | All four tags and the phrases: biome has no warning-comments rule. A reason on `@ts-expect-error` and `@ts-nocheck`: biome has no ban-ts-comment rule. |
| Shell | Nothing: shellcheck has no rule for tags and does not want a reason on `disable=`. | All of it. |

Deferring to those tools accepts their bar, not ours. biome takes any
explanation after the colon, one word included, where the tripwire wants
four. `document_ignores` wants a comment above or a text beside the ignore,
of any length.

The deferred checks run where their owners run. Those are CI's path-filtered
`agent` job (biome, for `apps/agent` and `packages`) and the `app` and `web`
jobs (the analyzer). On 2026-09-26 every tracked TypeScript and Dart file
sits under those paths. A source file added elsewhere is a gap in that
tool's scope, and it is fixed there, not by widening the tripwire again.

## What rules cannot express

The comment tripwire was ported rule for rule, then trimmed to the gaps
above; see the comments in `ast-grep/rules/tripwire`. Three limits of
ast-grep's rule language make parts of it looser than the Node version.
Each is pinned as a test case, so a change shows up in `ast-grep test`:

- **No line numbers.** A reason must sit in the comment right before a
  suppression, but "right before" is the previous node in the syntax tree.
  A blank line between the two, or a reason trailing code on the line above,
  still counts. The Node version required a comment alone on the line
  directly above. Likewise, "a directive on the file's first line" is the
  first node of the file, which is the same line once a formatter has
  removed leading blank lines.
- **No lookahead in regular expressions.** ast-grep uses Rust's `regex`
  crate. "temporary" is allowed before a runtime thing ("a temporary file"),
  but only per comment, not per occurrence: a comment holding both
  "temporary file" and "temporary fix" passes. "temporary" with nothing
  after it on its line still fails. Constraints cannot read a transformed
  value either, so the allowed phrases cannot be stripped out first.
- **A comment is one node.** A finding in a multi-line block comment is
  reported at the comment's first line, not the line holding the word; a
  directive on an inner line of a block comment needs its reason on that
  same line, since the line above it is part of the same node.

None of these needs a program. If one ever lets a real workaround comment
through, the fallback is point 2 above: a Rust program, weighed against
keeping the rule. That trade-off is decided then, not now.

## General and emotely-specific rules (amended 2026-09-26, #165)

The deciding test for where a rule lives: **would it make sense in a project
that isn't emotely?**

| Directory | Scope | Today |
|---|---|---|
| `ast-grep/rules/tripwire` | General: holds unchanged in any project with agents writing code. A later general concern gets its own directory beside it. | The comment tripwire: workaround tags and phrases, suppressions without a reason, in Dart, TypeScript and shell. |
| `ast-grep/rules/architecture` | Emotely-specific: the rule names emotely's paths, packages or ADRs, and means nothing elsewhere. | `no-from-environment` (ADR 0015): a define is read only in its app's environment file. |

Tests mirror the layout under `ast-grep/tests`. The engine does not care:
`ruleDirs` reads every directory under `ast-grep/rules`, and one scan runs
them all.

**Recommendation: keep both sets here until a second project wants the
general one.** Sharing has a cost we don't need to pay yet: a versioned
package, a way for `sgconfig.yml` to find its rules (`ruleDirs` takes paths,
so an npm package under `node_modules` would do), and changes made in two
repositories. With one consumer, the directory split is enough, and moving
a general directory out is a `git mv` plus one `ruleDirs` entry. When it is
extracted, the home is a rule set beside
[`flutter_agent_lints`](https://github.com/peter-trost/flutter_agent_lints),
not inside it: the tripwire covers TypeScript and shell as well as Dart, and
`flutter_agent_lints` is a pub package the analyzer reads, not ast-grep.

`no-from-environment` is emotely-specific. "Read a define in one place" is a
general idea, but the rule's whole content is which place: this repository's
two environment files.

## Adding a rule

A rule is one file plus its test, and nothing else changes:

1. List the existing rules you checked (Decision, point 3) in the pull
   request, and cover only the gap.
2. Pick the directory by the test above, and write the test first:
   `ast-grep/tests/<directory>/<rule-id>-test.yml`, with `valid` and
   `invalid` cases. Run `pnpm exec ast-grep test` and see it fail.
   `ast-grep test` exits 0 on a test whose rule does not exist yet, printing
   only "Configuration not found", so read the output, not the exit code.
3. Write `ast-grep/rules/<directory>/<rule-id>.yml`: `severity: error`, a
   comment saying why the rule exists, which existing rules fall short, and
   whether it is general or emotely-specific, and a `message` that names
   the fix, not only the fault.
4. Record the snapshots with `pnpm exec ast-grep test --update-all` and
   read them: they are the rule's expected findings.
5. If the rule has `files` or `ignores`, test them in
   `scripts/ast-grep.test.sh`, the only place a finding has a path.
6. `pnpm ast-grep:check` runs all three steps of CI's `ast-grep` job.

### What `no-from-environment` leaves to existing tools

Checked on 2026-09-26 against `flutter_agent_lints` 1.0.1 under the Dart
3.13 analyzer, `jaspr_lints` 0.7.2, biome 2.5.14 and shellcheck:

- **Dart linter, `do_not_use_environment`.** It flags every
  `fromEnvironment` and `hasEnvironment` call (probed on a scratch file).
  `flutter_agent_lints` turns it off, since defines are how Flutter is
  configured, and the analyzer cannot scope a rule to all files but one.
  Its only exemption is an `ignore_for_file` comment in the allowed file,
  and a comment travels with any copy of the code: a feature package opts
  out by writing one, with any reason `document_ignores` accepts. Enabling
  it in the shared set and turning it off for the app would exempt the
  whole app, not its environment file, and its message ("Invalid use of an
  environment declaration") cannot name the right place.
- **No other analyzer rule, and no `jaspr_lints` rule,** reads environment
  declarations.
- **biome and shellcheck** do not read Dart.

So the gap is all of it: a path-scoped exemption and a message naming the
file. The rule is `ast-grep/rules/architecture/no-from-environment.yml`.

## Consequences

- Lints of our own (#165, #170) are ast-grep rules in the same gate, with no
  extra CI step.
- ast-grep's rule language sets the limit of what a check can say cheaply;
  a check beyond it is a deliberate decision, recorded in an ADR amendment.
- An ast-grep rule has exactly one language, so a check across Dart,
  TypeScript and shell is three copies of the rule in one file. Their
  shared parts are kept identical by hand, and each copy is tested.
- A new check's pull request names the existing rules it looked at. A
  reviewer who knows a rule that already covers part of it cuts that part.
- Upgrading ast-grep is a version bump in `package.json`; `ast-grep test`
  catches a grammar or engine change that moves a rule.

## Sources

- ast-grep: [rule reference](https://ast-grep.github.io/reference/rule.html),
  [project configuration](https://ast-grep.github.io/reference/sgconfig.html),
  [`@ast-grep/cli` on npm](https://www.npmjs.com/package/@ast-grep/cli)
  (0.45.3, the latest release on 2026-09-25).
- Existing rules: [`flutter_agent_lints` 1.0.1](https://pub.dev/packages/flutter_agent_lints)
  (`lib/errors.yaml`, `lib/analysis_options.yaml`), the Dart
  [`document_ignores`](https://dart.dev/tools/linter-rules/document_ignores)
  and [`flutter_style_todos`](https://dart.dev/tools/linter-rules/flutter_style_todos)
  rules, biome's [rule sources](https://biomejs.dev/linter/rules-sources/)
  and [`noTsIgnore`](https://biomejs.dev/linter/rules/no-ts-ignore/), and the
  rule names in biome 2.5.14's `configuration_schema.json`.
- Rust `regex` crate: [syntax](https://docs.rs/regex/latest/regex/#syntax),
  which has no look-around; ast-grep 0.45.3 rejects `(?!…)` with "look-around,
  including look-ahead and look-behind, is not supported".
