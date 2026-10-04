# scripts

`setup-dev-environment.sh` brings a fresh Linux machine to where every job in
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs locally. It wants
root on x86_64 Debian/Ubuntu and Docker already installed (it starts the daemon,
it does not install Engine); `--verify` then runs every job that needs no secret
and names the ones it skipped.

It carries no version numbers of its own — Node from `.nvmrc`, pnpm from
`packageManager`, Flutter from `apps/mobile/app/.fvmrc`, Dart from the checksum-pinned
`apps/web/scripts/vercel-install.sh`, the Supabase CLI and `jaspr_cli` from
`ci.yml`. Bump a pin in the file that owns it, never here, and expect a hard
failure when a tool pinned in two files disagrees.

The toolchain installs into `/opt/emotely-toolchain`. Two Dart SDKs live there
on purpose: `dart` is the standalone SDK `apps/web` is pinned to, and
`flutter-dart` is Flutter's bundled one — the only one that resolves
`sdk: flutter` packages, so it is what `apps/mobile/app` uses wherever CI says `dart`.

`release-status.sh` records one store channel's version and build in the README badges' `status.json`.

`feature-map.sh` fails when a typed route in the Flutter workspace's tracked
library code and the entries of
`.claude/skills/run-app/references/feature-map.yaml` disagree, or when an
entry lacks a field. The routes come from the ast-grep rule `typed-go-route`,
which is `severity: off` so the ast-grep scan skips it. `pnpm feature-map`
runs the script after its own tests (`feature-map.test.sh`), and so does
CI's `ast-grep` job, after the steps of `pnpm ast-grep:check`. It stays out
of `ast-grep:check` because it needs yq, which nothing else there does.

`ast-grep.sh` runs every ast-grep rule over every file git tracks, so an
untracked scratch file never fails it, and fails a bare `ast-grep-ignore`
(`no-suppress-all`). `ast-grep.sh test` runs the rule tests, those of
`severity: off` rules included, and, unlike `ast-grep test`, fails a test
whose rule id no rule has. `pnpm
ast-grep:check` runs the rule tests, the script's own tests
(`ast-grep.test.sh`) and the scan, all three of which CI's `ast-grep` job
runs. A rule's `files` and `ignores` are tested only in
`ast-grep.test.sh`, since a rule test case has no path.

`l10n-check.sh` is what `melos run l10n:check` runs in each Flutter package
with an `l10n.yaml` (ADR 0020): it regenerates the localizations and fails
on stale or uncommitted generated code and on a message a locale lacks.
`l10n-check.test.sh` drives it with a fake `flutter` on the PATH.

`vercel-ignore.sh` is the Ignored Build Step of both Vercel projects: each
`apps/<project>/scripts/vercel-ignore.sh` passes its own build inputs, and
this script picks what to diff them against — the branch's last successful
deployment, else its merge base with `main`, else it builds. Vercel's clone
is shallow and may have no remote, so it fetches from the public GitHub
repository the deployment names. `vercel-ignore.test.sh` runs it in
throwaway shallow clones.

`store-listing-check.sh` checks the store listings in
`apps/mobile/app/fastlane/metadata` against each store's field limits (App
Store keywords count bytes, everything else characters; Play's release
notes, the beta notes in `changelogs/`, 500), fails a locale that
lacks a field English has, and a Play file ending in a newline (supply
uploads it verbatim). A limit the stores change goes into its `case` table.

Shell here is linted by the `scripts` CI job: `shellcheck --external-sources
--severity=style scripts/*.sh`, clean (with the skills' and
`apps/*/scripts` shell); the same job runs `bash
scripts/release-status.test.sh`, `bash scripts/l10n-check.test.sh`, `bash
scripts/vercel-ignore.test.sh`, `bash scripts/store-listing-check.test.sh`
and the listing check itself (the job also runs when only a listing
changed).
