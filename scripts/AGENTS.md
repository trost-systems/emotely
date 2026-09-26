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

`tripwire.sh` runs the ast-grep rules over every file git tracks, so an
untracked scratch file never fails it; `pnpm tripwire` runs it after the rule
tests and its own tests (`tripwire.test.sh`), all three of which CI's
`tripwire` job runs.

Shell here is linted by the `scripts` CI job: `shellcheck --external-sources
--severity=style scripts/*.sh`, clean; the same job runs
`bash scripts/release-status.test.sh`.
