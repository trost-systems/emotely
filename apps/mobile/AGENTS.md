# apps/mobile — the Flutter workspace

The app and every package beside it, resolved and gated together.

## Size and complexity

Hand-written code in `lib/` stays within three limits: cognitive complexity
15 per function (SonarSource's scoring), 60 lines per function, 400 lines per
file. Tests and generated files are exempt. `melos run complexity` checks
them and is part of `melos run ci`. The gate is absolute: every function in
scope counts on every run, so a change that lengthens an old function pays
for it.

- A long `build` becomes private widgets, one per row or block, each with its
  own `build`; `MoreView` in `feature_account` is the pattern. A long
  configuration object moves into a method of its own.
- Branching logic splits into named helpers, or into the bloc when a widget
  carries it.
- The limits are lints: `// cognitive_complexity:ignore` on the line above a
  declaration exempts it only with a comment beside it saying why it cannot
  be split, the same bar as a rule override.

## Duplication

`dart run dedupe .` finds clones across the workspace; it reports, it does
not gate. Run it from here before extracting a shared helper, and before a
pull request as `dart run dedupe --git-diff=origin/main --only-changed .`,
which lists only the clones the change introduces. Keep the `.`: without a
target, dedupe analyzes zero files here and reports a clean result. Fold a clone into a shared
helper in `lib/`. In tests, fold one only when a file repeats the same setup
often enough that a robot or `setUp` reads better; one explicit arrange block
per test is the norm there.
