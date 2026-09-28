# How the plugin is wired, and what bites

Facts for Dart 3.13 / Flutter 3.47, analysis_server_plugin 0.3.23,
analyzer 14.4.0 (checked 2026-09-28 against the SDK source at tag 3.13.2).

## Where the configuration lives, and why

- **The whole `apps/mobile` pub workspace is one analysis context**, rooted
  at `apps/mobile`, even when `dart analyze` runs inside one member.
- **The analyzer starts plugins only from that root's options file**,
  `apps/mobile/analysis_options.yaml`, with its includes merged in; it
  includes `package:analysis/analysis_options.yaml`.
- **It is the only options file of the workspace: packages carry none.**
  Which rules run on a file is decided by the nearest options file, and the
  plugin resolves the workspace once per options file it meets. With one
  per package, a cold `dart analyze` took 325 s on an M-series laptop, and
  on GitHub's runner 9 minutes or until the runner was shut down; with the
  root file alone, 31 s, plugin compile included (2026-09-29). A package
  that needs an exclusion gets it in the root file, by path. Never add an
  `analysis_options.yaml` to a package.
- **The block is in `packages/utility/analysis/lib/plugins.yaml`**, included
  from `analysis_options.yaml` beside it. A `plugins:` key written directly
  in any file named `analysis_options.yaml` other than the root one raises
  `plugins_in_inner_options`, a warning that fails `--fatal-infos`.
- **`path:` is relative to the file that declares it** (plugins.yaml).
- **A package re-declaring `plugins: emotely_lints:` replaces the whole
  entry**, path and diagnostics together; there is no per-package switch.
  A rule is on for every package or for none.

## Why the plugin is outside the workspace

- `analyzer_testing` needs a `test` whose `test_api` is newer than the one
  `flutter_test` pins, so the plugin cannot resolve inside `apps/mobile`.
- A package with its own `.dart_tool` *inside* `apps/mobile` would become a
  second context and start a second plugin isolate (twice the cold start).
  `tools/` keeps it out of the tree.
- Its pubspec pins analysis_server_plugin and analyzer exactly. Each
  analysis_server_plugin release requires one exact analyzer, and
  analyzer_testing the same one: bump the three together, reading each
  release's CHANGELOG (the analyzer's AST API moves: `NamedExpression` went
  in 13.0; `Argument.argumentExpression` is the current accessor).

## How the analysis server runs it

- **`flutter analyze` does not report plugin diagnostics**
  (flutter/flutter#187999). The melos `analyze` script therefore runs
  `dart analyze --fatal-infos` once over the packages in scope. Never in
  parallel: every run starts the plugin, and parallel runs in one checkout
  race on its build folder.
- **Point `dart analyze` at package directories.** Pointed at `lib/`
  directories it runs no plugin rule at all, silently.
- **A slow cold analyze is the first thing to measure** after any change to
  the wiring: `dart analyze --fatal-infos --cache=<empty dir>` from
  `apps/mobile`, against 31 s today. Every CI run is cold.
- **Every start runs `dart pub upgrade`** on a generated package under
  `~/.dartServer/.plugin_manager/<hash of the workspace path>/`, then
  compiles the plugin to an AOT snapshot there. pub.dev must be reachable;
  offline, the plugin does not load and `dart analyze` exits 4 when there is
  nothing else to report (with other diagnostics, the failure shows only on
  stderr).
- **Cold start ~15 s, warm 2–5 s** (per checkout path: every worktree has
  its own folder and pays its own cold start). The snapshot is rebuilt
  whenever a plugin source is newer than it, so a fresh CI checkout always
  compiles; caching `~/.dartServer` does not help.
- `print` in a rule goes nowhere; debug through the rule's tests.

## CI

- **`lints` job** (`.github/workflows/ci.yml`): the plugin's own format,
  analyze and tests at 100 %, with the app's Flutter SDK, when
  `tools/emotely_lints/**` changes.
- **`app` job**: runs on `tools/emotely_lints/**` too, and the scope step
  treats a plugin change as workspace-wide, because melos cannot see the
  plugin as a dependency of anything. A rule changed alone would otherwise
  be analyzed against no package.
- `scripts/setup-dev-environment.sh --verify` runs the same `lints` gates.
