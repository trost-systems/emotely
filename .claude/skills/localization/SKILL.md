---
name: localization
description: How user-facing text works in the Flutter app (apps/mobile, ADR 0020) — which package owns a string, adding or changing a message in the ARB files, context.l10n, typed failure reasons, testing text by its key, the glossary and the copy spell check, adding a locale or a package that shows text. Use whenever writing or changing app copy, adding a screen or a design_system component, touching an ARB file or l10n.yaml, translating, or when l10n:check, the copy spell check or avoid_hardcoded_ui_text fails.
---

# Text in the app

Every string a user reads or hears is a message in the ARB files of the
package that renders it, never a literal in Dart
([ADR 0020](../../../docs/adr/0020-localization-per-package.md)). English
is the template; every other locale the app ships has the same keys.

## Which package owns a string

- **A `design_system` component words its own chrome**: its heading, its
  own buttons, what a screen reader announces, the empty and error states it
  draws. Same words on every screen that shows it, from
  `design_system_{en,de}.arb`.
- **What a component displays is passed in**: a name, a question, an
  answer. No parameter overrides a component's own wording; a screen that
  needs other words needs another component, or the words are content.
- **A feature words everything else it shows**, even a word another feature
  also says. The same text and widgets in several features is the cue to
  extract a component, words and all.
- **The app** words its own screens (the tabs, the startup gate).
- **Nothing else shows text.** Other utilities hand over URLs and actions;
  blocs, states and repositories carry typed reasons (an enum, a sealed
  class) that the view words. An exception's message is for error
  tracking, in English, never on screen — `ConfigProblem` in the app's
  startup gate is the pattern.

## Adding or changing a message

1. **The words.** Use [`CONTEXT.md`](../../../CONTEXT.md)'s terms, in
   English and German; a term missing there is added there first, with its
   German form. English is US English ("color", "journaling"); German says
   "du". "emotely" stays lower case in both.
2. **The template.** Add the key to `l10n/<package>_en.arb` with an
   `@description`: which screen, what the words do there, who reads them —
   the translator's only context. Keys name the role (`deleteAccountButton`),
   not the words. Placeholders get `type` and `example`; counts are ICU
   plurals.
3. **Every other locale**, in the same change: `l10n/<package>_de.arb`.
4. **Generate** in the package: `flutter gen-l10n`, and commit
   `lib/src/l10n/` (`lib/l10n/` in the app).
5. **Use it** as `context.l10n.theKey`. Each package declares `context.l10n`
   for its own class in `lib/src/l10n/l10n.dart` (the app's in
   `lib/l10n/l10n.dart`) and never exports it, so `context.l10n` always
   means the strings of the package the code is in.

**Leave room for German.** It runs about a third longer than English, and
a slot that holds one line — an app bar title, a button, a tab label —
cuts the rest off with "…". Such a slot gets a word or two; a sentence goes
in the body, where it wraps (the consent screen's title is a heading there
for that reason). Widget tests do not see an ellipsis: look at a new or
reworded screen on the simulator in German (`run-app.sh up --locale
de_DE`) before calling it done.

A message that is part of a consent's versioned wording (`feature_account`,
ADR 0014) changes a digest test: read that test's failure message before
touching the digest or the version.

## Testing text

- **Assert a message by its key, never by its words**:
  `find.text(tester.element(find.byType(ThePage)).l10n.theKey)`, or a
  `strings` getter on the package's robot that does the same. A rewording
  then changes no test, and a string that bypassed the ARB files still
  fails wherever the test runs in German, because it renders English.
- **Data stays literal**: a user's name, an answer, a question the agent
  sent.
- **One test in the whole app looks at words themselves**:
  `apps/mobile/app/test/app/localizations_test.dart` proves a German phone
  gets German. Write no second one.
- The pump helpers (`pumpApp`, `pageUnderTest`, `featureUnderTest`) take
  `localizations: const [TheFeatureLocalizations.delegate]` and `locale:`;
  design_system's and Flutter's delegates are always added. Go back with
  `tester.tapBack()`: `pageBack()` looks for an English tooltip.

## The checks, and what a failure means

| Check | Fails when | Fix |
| --- | --- | --- |
| `avoid_hardcoded_ui_text` (analyze) | a literal, or a `const` holding one, reaches the UI in `lib/` | move it to the ARB files |
| `melos run l10n:check` | generated code is stale or uncommitted, or a locale lacks a key | `flutter gen-l10n`, commit; add the key |
| `pnpm spell` (tripwire job) | a word is misspelt, or a term `CONTEXT.md` says to avoid appears | fix the copy; a real word goes into `cspell/project-words.txt` (names, any language) or `cspell/de-words.txt` |
| `test/app/localizations_test.dart` | a package lacks a shipped locale, or iOS or Android does not declare it | add the ARB file; `Info.plist`; `locale_config.xml` |

## Adding a package that shows text, or a locale

- **A package**: copy another feature's `l10n.yaml` and rename the ARB
  files and the class; add `flutter_localizations` (SDK), `intl` at the
  app's pin and `generate: true` to its pubspec; export the class from the
  barrel; add its delegate to `apps/mobile/app/lib/app/localizations.dart`;
  add `lib/src/l10n/l10n.dart` with its `context.l10n`.
- **A locale**: one ARB file per package that shows text, one entry in
  `CFBundleLocalizations` in `apps/mobile/app/ios/Runner/Info.plist`, one
  `<locale>` in
  `apps/mobile/app/android/app/src/main/res/xml/locale_config.xml` (the
  languages Android 13+ offers as emotely's per-app language), its column
  in `CONTEXT.md`, and its dictionary in `cspell.config.yaml`.
