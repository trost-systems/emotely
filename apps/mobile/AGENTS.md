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

## Strings (ADR 0020)

Every string a user reads is a message in the ARB files of the package that
shows it, never a literal in Dart.

- Every feature, `design_system` and the app own `l10n.yaml`,
  `l10n/<name>_en.arb` (the template) and one ARB per other locale,
  generated into their `lib/` by
  `flutter gen-l10n` and committed. Add a message to the English template
  with its `@description` (what the screen is and what the words do there:
  the translator's only context), to every other ARB in the same change,
  then run `flutter gen-l10n` in the package.
- Text belongs to whatever renders it. A `design_system` component words
  its own chrome — heading, buttons, screen-reader labels, its empty and
  error states — in `design_system`'s ARB files, the same on every screen;
  what it displays is passed in, and no parameter overrides its wording. A
  feature words everything else it shows, even a word another feature also
  says. When the same text and widgets recur across features, extract a
  component. The other utilities show no text.
- Blocs and repositories carry no text either. A failure is a typed reason
  (an enum, a sealed class) and the view words it; an exception's message
  is for error tracking, in English, and never shown.
- German says "du", informal and warm like the English, and keeps "emotely"
  lower case. One thing has one name in every package:

  | English | German |
  | --- | --- |
  | session | die Session (never "Sitzung": a meeting, or therapy) |
  | entry, journal | der Eintrag, das Tagebuch |
  | reflection | die Reflexion |
  | account, profile | das Konto, das Profil |
  | the More tab | „Mehr“ |
  | privacy notice, privacy settings | die Datenschutzerklärung, die Datenschutzeinstellungen |
  | consent, withdraw | die Einwilligung, widerrufen |
- Look a string up with `XLocalizations.of(context)`; outside a widget
  (a test, a digest), `lookupXLocalizations(locale)`.
- `melos run l10n:check` regenerates every package in scope and fails on
  stale generated code or a message missing from a locale; it is part of
  `melos run ci`.

## Duplication

`dart run dedupe .` finds clones across the workspace; it reports, it does
not gate. Run it from here before extracting a shared helper, and before a
pull request as `dart run dedupe --git-diff=origin/main --only-changed .`,
which lists only the clones the change introduces. Keep the `.`: without a
target, dedupe analyzes zero files here and reports a clean result. Fold a clone into a shared
helper in `lib/`. In tests, fold one only when a file repeats the same setup
often enough that a robot or `setUp` reads better; one explicit arrange block
per test is the norm there.
