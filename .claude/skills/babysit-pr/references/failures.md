# Reading a failed job in this repo

Which job failed tells you what broke and how to reproduce it locally. Fix the
cause on the branch; never quiet the check. Every command below runs from the
repo root unless the job's `working-directory` says otherwise.

## `agent` — `apps/agent`, `packages/**` (Node, pnpm)

| Failing step | What it means | Reproduce |
| --- | --- | --- |
| `pnpm lint` | biome, `preset: "all"`, warnings are errors | `pnpm lint`, then `pnpm format` for the mechanical half |
| `pnpm typecheck` | project-wide `tsc --build`, every strictness flag | `pnpm typecheck` |
| `pnpm -r --if-present test` | a package's own suite | `pnpm -r --if-present test` |
| contract tripwire | `contract.schema.json` no longer matches the zod source | `pnpm --filter @emotely/contract schema` and commit the result |
| `pnpm --filter @emotely/agent eval` | live-model protocol eval, deterministic assertions | needs `AI_GATEWAY_API_KEY`; see below |

The contract tripwire is a **regenerate-and-commit**, not a fix: the schema is
emitted from zod and committed, and CI fails when the two drift. Run the
generator and commit its output — never hand-edit the JSON to match.

A failing eval is a real signal about model behavior, not a flake to re-run.
Judged behavior evals run nightly; the CI one is deterministic. If it fails
only on a fork PR for a missing key, that is expected and not yours to fix.

## `app` — `apps/mobile` (the Flutter workspace)

The job is a matrix of four runners: `app (checks)` runs `melos run checks`
(every gate but `test`), and `app (tests 1)` to `app (tests 3)` each run
`melos run test` for every third package in scope; the step before it names
the shard's packages. Read the failing part's log, then the package name, and
reproduce from that package's directory. `codegen:check` is one build over
the whole workspace and names each stale file as `package|path`. All of them
are `melos run <script>` from `apps/mobile` (scripts in its `pubspec.yaml`);
`melos run ci` runs them all in one go.

| Failing script | What it means | Reproduce |
| --- | --- | --- |
| `codegen:check` | committed generated code is stale in that package | `dart run build_runner build` in the package, commit |
| `l10n:check` | generated localizations stale or uncommitted, or a locale lacks a message | `flutter gen-l10n` in the package and commit; add the message to that locale's ARB file |
| `format` | formatting | `dart format .` in the package |
| `analyze` | `flutter_agent_lints` and the `emotely_lints` plugin via `packages/utility/analysis`; infos fail too | `dart analyze --fatal-infos` in the package (not `flutter analyze`: it hides plugin diagnostics) |
| `complexity` | a function in `lib/` is over complexity 15 or 60 lines, or a file over 400 lines (`[VIOLATION]` marks it) | `melos run complexity`; split it as `apps/mobile/AGENTS.md` describes |
| `test` | a test failed, or hand-written code is uncovered | see below |

On a pull request the job runs only the packages that changed plus their
dependents (`EMOTELY_SCOPE`); a change outside any package runs everything. A
package that passes locally but was skipped on the PR was not run, not fixed.

Coverage is a hard 100% gate on hand-written code per package, with generated
files (`*.freezed.dart`, `*.g.dart`, `*.mocks.dart`) excluded and `main.dart`
carrying a `coverage:ignore-file` marker; `analysis` and `testing` have no
tests and are not measured. A coverage failure on a PR that added code means
the new code needs tests — not that the threshold needs lowering.

Regenerating with `--delete-conflicting-outputs` and `--build-filter` together
is blocked by a global hook, and rightly: the first deletes every generated
file while the second regenerates only a subset, leaving the tree broken. Use
one or the other.

## `web` — `apps/web` (Jaspr, Dart)

Runs `dart format --set-exit-if-changed .`, `dart analyze --fatal-infos`,
`dart test`, `dart test -p chrome test/client`, `jaspr build`, then
`git diff --exit-code -- lib`.

Two failure modes are specific to this job:

- **`git diff --exit-code -- lib`** — the build rewrote a committed
  `*.options.dart`. Run the build and commit the generated file.
- **`dart test -p chrome test/client`** — the browser half. Running it through
  the very_good CLI MCP tool requires `optimization: false`, because the test
  optimizer bundles everything into one VM entrypoint and the
  `@TestOn('browser')` files then fail to compile on `dart:js_interop`.

## `supabase` — `supabase/**`

`stack.sh up --db-only` (the supabase skill's script), `supabase test db
--local` (pgTAP), then `supabase db lint --local --fail-on warning`.

A pgTAP failure is usually a row-level-security assertion, and RLS is the point
of the suite (ADR 0010) — a failing policy test is a security finding, not a
flake. Reproduce on the checkout's own stack:
`bash .claude/skills/supabase/scripts/stack.sh up --db-only`,
`supabase db reset --local`, `supabase test db --local`.

`supabase-deploy` only runs on `main`; it is never part of a PR's checks.

## Flaky vs branch-related

Treat as **flaky/infrastructural** — re-run, up to 3 per SHA:

- runner provisioning or image startup failure
- DNS, registry or network timeout while fetching dependencies
- GitHub Actions service degradation
- a container failing to start (for example `supabase db start` timing out)

Treat as **branch-related** — fix it:

- anything deterministic in code the PR touched
- lint, analyze, format, typecheck, coverage
- a tripwire (`contract.schema.json`, `*.options.dart`, `build_runner`)

The tripwires look like infrastructure and are not: they fail because
committed generated output drifted from its source, which is a branch problem
with a one-command fix.

When the same job fails twice on the same SHA with the same log, stop calling
it flaky.
