# Localization: every package owns its strings, the app composes them

The Flutter client is localized with Flutter's own generator, `flutter
gen-l10n`, from ARB files. Every package that shows text (each feature,
`design_system` and the app itself) owns its strings, its generated
localizations class and its delegate. A component in `design_system` words
its own chrome, the same on every screen that shows it; what it displays is
passed in. The app lists every package's delegate and
decides which locales ship. English is the template, German the first
translation. A literal string handed to the UI is an analyzer error, reported
by an analyzer plugin of our own. Decided on 2026-09-28.

## Context

Every string in the app was hard-coded English, with no ARB files and no
`localizationsDelegates` (#217 hit this first: the sign-in buttons cannot
follow the app's language). About 300 strings sit across five feature
packages, the app and one widget in `design_system`.

The layering of [ADR 0015](0015-lego-package-layering.md) shapes the answer:
features are separate packages, the app is the glue, and CI runs only the
packages a change touches plus their dependents. The reference the layering
came from, Tide's "Project Miniclient" series, says nothing about
localization. The talk behind it (Leushchenko, "Building Flutter apps in
Lego style", Flutter Vikings 2022) and its demo repository give each feature
its own ARB files and its own generated class, which is the model here.

Measured with `melos list --include-dependents` on the 18 packages of the
workspace on 2026-09-28, which counts dev dependencies:

| A change to | Packages CI runs |
| --- | --- |
| one feature's strings | 2 (the feature, the app) |
| the app's strings | 1 |
| `design_system` or `testing` | 15 (all but `analysis`, `contract`, `supabase_schema`) |

`testing` depends on `design_system`, and nearly every package dev-depends on
`testing`, so anything in `design_system` fans out to the whole workspace —
its text as much as its code, and both change rarely.

## Decisions

1. **Flutter's generator, ARB files, English as the template.** `flutter
   gen-l10n` ships with the SDK, is configured per package by an
   `l10n.yaml`, and needs no `build_runner` step. Since Flutter 3.32 it
   writes into the package's own source tree; the synthetic
   `package:flutter_gen` is gone. English (`*_en.arb`) is the template every
   other locale is checked against.

2. **Every package that shows text owns its strings.** Each feature,
   `design_system` and the app has, at its root:

   ```
   feature_session/
   ├─ l10n.yaml
   ├─ l10n/session_en.arb      the template
   ├─ l10n/session_de.arb
   └─ lib/src/l10n/…           generated, committed
   ```

   - The files and the class carry the package's name (`session_de.arb`,
     `SessionLocalizations`), so eight packages never produce eight files
     called `app_de.arb`.
   - The ARB files sit at the package root, not in `lib/`: a translator or a
     reviewer finds them without reading Dart.
   - The barrel exports only the class; the app needs its delegate, a test
     its `localizationsDelegates`.
   - `l10n.yaml` is the same everywhere but for the names:
     `nullable-getter: false` (no `!` at every call site),
     `required-resource-attributes: true` (every message carries a
     `@description`, the context a translator or an agent needs to render
     "Save" or "Done" correctly), `format: true`,
     `preferred-supported-locales: [en]` (Flutter falls back to the first
     supported locale when the device speaks none of them, and the default
     order is alphabetical: German would greet every French phone),
     `untranslated-messages-file` pointing into `build/`, and a header that
     exempts the generated files from the coverage gate.

3. **Text belongs to whatever renders it.** Three owners, and nothing
   between them:
   - **A `design_system` component words its own chrome**: its heading, its
     own buttons, the labels a screen reader announces, the empty and error
     states it draws. A component reused across features says the same thing
     everywhere, and a rewording is one change in one place, not one per
     consumer kept in step by hand. `EntryView`, shown by the journal and at
     the end of a session, heads every entry "Your entry" from
     `design_system`'s own ARB files.
   - **What a component displays is passed in**: a name, a question, an
     answer, whatever the caller decides. A component takes no parameter
     that overrides its own wording; a screen that needs other words needs
     another component, or the words are content.
   - **A feature words everything else it shows**, including words another
     feature also uses. Two screens that both say "Try again" are not one
     component until someone extracts one; when the same block of text and
     widgets recurs across features, that is the cue to move it into
     `design_system`, words and all.

   The other utilities show no text: `legal_links` and `feedback_link` hand
   over a URL or an action, and the screen that offers them words the
   link. Blocs, states and repositories carry no text either: a failure is a
   typed reason (an enum, a sealed class) the view words, and an exception's
   message is for error tracking, in English, never on screen. The startup
   gate's `ConfigProblem` is the pattern.

   A string in `design_system` runs 15 packages in CI rather than two. That
   is the price of any change there, and component chrome changes as rarely
   as the components do.

4. **The app composes.** `app/lib/app/localizations.dart` lists every
   package's delegate, followed by Flutter's own
   (`GlobalMaterialLocalizations.delegates` from `material_ui`, whose widgets
   the app uses — not the copy in `flutter_localizations` that gen-l10n's own
   `localizationsDelegates` list names), and takes `supportedLocales` from
   the app's own class. A test in the app checks that
   every listed delegate supports every locale the app ships, so a package
   that lacks a translation fails before release. The features do not wrap
   themselves in `Localizations.override`, as the Lego demo does: their
   routes are mounted into the app's one router
   ([ADR 0016](0016-declarative-routing-with-go-router.md)), there is no
   feature root widget to wrap, and the app is where composition belongs.
   iOS reports only the languages named in `CFBundleLocalizations` in
   `Info.plist`, so a new locale is added there too.

5. **Generated code is committed and checked.** Like the freezed and
   json_serializable output, the generated files are in git.
   `melos run l10n:check` regenerates each package in scope, fails on any
   difference, and fails when `untranslated-messages-file` lists a message:
   a key added in English and not in German is a red build, not an English
   word on a German screen. It runs in `melos run ci`, scoped like every
   other gate.

6. **A literal string in the UI is an analyzer error.** A rule in our own
   analyzer plugin, `avoid_hardcoded_ui_text` in `tools/emotely_lints`,
   reports a string literal that holds a letter — or a `const` holding one,
   the usual way round such a rule — given to a `String` parameter of a
   widget, or to a text parameter (`label`, `hintText`, `tooltip`,
   `semanticLabel`, `title`, `message`, …) of any other Flutter class. It
   runs in every package's `lib/`, `design_system` and the other utilities
   included. Exceptions, URLs, asset paths and strings without a letter
   pass.
   - **Why the analyzer and not ast-grep** ([ADR 0018](0018-custom-checks-are-engine-rules-first.md)):
     the rule needs types. Whether `label:` is a `String` parameter of a
     widget, of an `InputDecoration`, or of an exception class is not in the
     syntax.
   - **Existing rules checked first:** the SDK lint set and
     `flutter_agent_lints` (every SDK rule, decided) have no rule about
     literal UI text; the string rules there (`prefer_single_quotes`,
     `unnecessary_string_interpolations`, `use_raw_strings` and the like)
     are about a literal's form, never about where it ends up.
   - **How it is wired** (read from the Dart 3.13.2 source, and tried): the
     pub workspace is one analysis context, and the analyzer starts plugins
     only from its root's options, so `apps/mobile/analysis_options.yaml`
     exists and includes the shared rule set, whose `plugins.yaml` declares
     the plugin. It is the workspace's only options file: packages drop
     their one-line `analysis_options.yaml`, because the plugin resolves
     the workspace once per options file it meets — with one per package a
     cold analyze took 325 s on a laptop and outlived GitHub's runner, with
     one in all 31 s. `flutter analyze` reports no plugin diagnostic
     (flutter/flutter#187999), so the analyze gate is `dart analyze
     --fatal-infos`, one run over the packages in scope.
   - **Outside the workspace:** `analyzer_testing` and `flutter_test` pin
     `test_api` apart, so the plugin cannot resolve inside `apps/mobile`. It
     has its own CI job, and the emotely-lints skill says how to add a rule.
   - **CI scope:** a plugin is wired through `analysis_options.yaml`, which
     melos's dependency graph does not see. A change to the plugin runs every
     package, the same way a change to `analysis` already does.
   - **Rolled out last:** the rule lands off and is switched on by the pull
     request that moves the last feature's strings, so no pull request in
     between is red or littered with ignores.

7. **German is the first translation.** `de` joins `en` as the second locale.
   It says "du", informal and warm like the English, and keeps "emotely"
   lower case. One thing has one name in every package and every surface:
   [`CONTEXT.md`](../../CONTEXT.md), the project's glossary, gives each term
   its German form and the words to avoid, and a spell check over the ARB
   files (cspell, English and German, run in CI) fails on a misspelling or
   on an avoided word. Machine-drafted translations are reviewed by a German
   speaker in the pull request that adds them.

8. **Code reads `context.l10n`; tests assert keys, never words.** Each
   package declares `context.l10n` for its own class and never exports it,
   so the getter always means the package the code is in. A test finds a
   message by its key, read from the pumped widget tree, so rewording copy
   changes no test. Widget tests run under German by default, so a string
   that bypassed the ARB files — still English under any locale — fails the
   test that reads it by its key. One test in the app looks at the words
   themselves and proves a German phone gets German; no other test does.

9. **Consent wording is hashed across every locale.** The consent screens'
   strings move into `feature_account`'s ARB files like any other. The
   version tests of [ADR 0014](0014-explicit-consent-as-an-append-only-record.md)
   hash the decision strings of *every* supported locale, so a consent
   version names the set of texts, one per language, and editing the German
   trips the same tripwire as editing the English. Adding a faithful
   translation changes the digest but not the meaning, so it updates the
   digest alone and re-gates nobody.

## What this does not cover

- **What the server says.** The question texts come from the agent
  (`apps/agent/src/default-question-set.ts`), and the companion writes the
  entry. Both stay English until the app sends its locale in `userContext`
  ([ADR 0019](0019-onboarding-before-sign-up.md) already names `locale` as a
  later field) and the agent answers in it (#228).
- **The web, the privacy notice, mail templates and store listings.** Each
  is its own surface with its own review; the in-app consent links to the
  English notice until the notice is translated (#229).
- **A translation platform.** Agents edit the ARB files directly; a platform
  (Crowdin, Lokalise, Phrase) is worth its setup once a translator who does
  not work in the repository joins.

## Consequences

- A string on screen is a key in the owning package's template ARB, with a
  description, and its translation in every other ARB, in the same pull
  request, in the words `CONTEXT.md` gives. The analyzer, `l10n:check`, the
  spell check and the app's locale test each fail if one of them is
  missing.
- A feature's string change runs two packages in CI; a component's, in
  `design_system`, runs 15.
- Tests pump a feature with its own delegate: the pump helpers in `testing`
  take `localizations:` and `locale:`, add `design_system`'s delegate and
  Flutter's themselves, and `tapBack()` replaces `pageBack()`, which finds
  the back button by its English tooltip.
- The analyze gate starts the plugin on every CI run (half a minute cold,
  a minute in CI for the whole workspace) and needs pub.dev at analysis
  time.
- The localization skill holds the steps: adding a message, a package that
  shows text, a locale.
- Adding a locale is one ARB file per package, one entry in `Info.plist`,
  its column in `CONTEXT.md` and its dictionary in the spell check;
  `supportedLocales` follows the app's ARB files.

## Sources

- Flutter, [Internationalizing Flutter apps](https://docs.flutter.dev/ui/internationalization)
  (updated 2026-09-02, Flutter 3.47) and
  [the removal of the synthetic `flutter_gen` package](https://docs.flutter.dev/release/breaking-changes/flutter-generate-i10n-source).
- Anna and Oleksandr Leushchenko, [Building Flutter apps in Lego style](https://fluttervikings.com/building-flutter-apps-in-lego-style/),
  Flutter Vikings 2022; demo: [olexale/lego_style_demo](https://github.com/olexale/lego_style_demo).
- Dart, [Analyzer plugins](https://dart.dev/tools/analyzer-plugins) and the
  SDK's [analysis_server_plugin docs](https://github.com/dart-lang/sdk/tree/main/pkg/analysis_server_plugin/doc);
  the context and plugin loading read from the SDK at tag 3.13.2
  (`pkg/analyzer/lib/src/dart/analysis/driver.dart`,
  `pkg/analysis_server/lib/src/plugin/plugin_manager.dart`).
- [flutter/flutter#187999](https://github.com/flutter/flutter/issues/187999),
  `flutter analyze` not reporting plugin diagnostics.
- Tide Engineering, [Project Miniclient](https://medium.com/tide-engineering-team/project-miniclient-introduction-0a94aefa5638)
  (2024), the layering reference of ADR 0015.
