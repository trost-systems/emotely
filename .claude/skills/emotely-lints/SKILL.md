---
name: emotely-lints
description: How to add, change, enable or silence a rule in emotely's own Dart analyzer plugin (tools/emotely_lints), and how the plugin is wired into analysis and CI. Use whenever a custom check needs types, a diagnostic named `emotely_lints/…` appears, `avoid_hardcoded_ui_text` misfires, or analysis_server_plugin / analyzer need a bump.
---

# emotely's analyzer plugin

`tools/emotely_lints` holds the lint rules neither the SDK nor
`flutter_agent_lints` has. A rule lives here only when it needs **types**;
a check that syntax alone decides is an ast-grep rule in `ast-grep/rules`
([ADR 0018](../../../docs/adr/0018-custom-checks-are-engine-rules-first.md)).
Today it has two rules: `avoid_hardcoded_ui_text`
([ADR 0020](../../../docs/adr/0020-localization-per-package.md)) and
`avoid_returning_widgets` (a function, method or getter in `lib/` that
returns a widget; overrides, closures and tests pass).

Only production code is held to `avoid_returning_widgets`. A package
with `flutter_test` or `test` under `dependencies` (not
`dev_dependencies`) can never ship in the app, so the rule treats its
`lib/` as test support and skips it, like `test/`: that is how
`testing`'s `pageUnderTest` and friends stay functions. Never move a test
framework into a production package's `dependencies` to silence it.

## Adding a rule

1. **Justify it.** List the analyzer, `flutter_agent_lints` and ast-grep
   rules you checked and why each falls short; the list goes in the pull
   request. Cover only the gap.
2. **Red first.** Add `test/<rule>_test.dart` beside
   `test/avoid_hardcoded_ui_text_test.dart` and copy its shape: an
   `AnalysisRuleTest` with `addFlutterPackageDep => true` when the rule looks
   at Flutter types, one `test_…` method per case, `assertDiagnostics` for
   what it reports and `assertNoDiagnostics` for each look-alike it must
   leave alone (tests, identifiers, exceptions: whatever the rule's false
   positives would be). Run it and watch it fail.
3. **The rule.** `lib/src/<rule>.dart`: an `AnalysisRule` whose `LintCode`
   is one `static const` (a second instance breaks `// ignore:`), visitors
   registered in `registerNodeProcessors`. Report in `lib/` only unless the
   rule is about tests (`context.isInLibDir`).
4. **Register it** in `lib/main.dart` with `registerLintRule`, and extend
   `test/plugin_test.dart`'s list. Every rule is a lint, off by default.
5. **Enable it** under `diagnostics:` in
   `apps/mobile/packages/utility/analysis/lib/plugins.yaml` as
   `<rule>: error` (the workspace's lints are all errors). Only that file:
   a `plugins:` block anywhere else is ignored or warned about.
6. **Green everywhere.** In `tools/emotely_lints`: `dart format .`,
   `dart analyze --fatal-infos`, and the tests at 100 % coverage through the
   very_good_cli MCP `test` tool with `dart: true` (a hook blocks
   `dart test` in Bash). Then from `apps/mobile`: `melos run analyze`, which
   runs the plugin over every package; fix or justify every hit before the
   rule is switched on.

Done when the rule's tests pass at 100 %, `melos run analyze` is clean with
the rule enabled, and the pull request lists the rules it checked.

## Silencing one hit

`// ignore: emotely_lints/<rule>` on the line above, with the reason beside
it (`document_ignores` applies). A bare `// ignore: <rule>` does nothing, and
`unnecessary_ignore` cannot flag a stale plugin ignore, so check yours still
matches when the code around it changes.

## Changing `avoid_hardcoded_ui_text`

It reports a string literal with a letter in it — or a `const` holding one —
given to a `String` parameter of a widget (any but the identifiers in
`_identifierParameters`) or to a text-named parameter of any other Flutter
class (`_textParameters`), in `lib/` only. Exceptions, URLs, asset paths and
letterless strings pass. A misfire is a new test case first, then a change
to one of those sets or predicates.

## Wiring, CI and gotchas

The analyzer starts plugins only from the workspace root's options, and
`flutter analyze` never shows their diagnostics; the melos `analyze` script
is `dart analyze` for that reason. Packages carry no `analysis_options.yaml`
(one per package made a cold analyze ten times slower). Changing the
wiring, bumping the analyzer or the plugin API, a slow or silent analyze, or
the CI job — read [references/wiring.md](references/wiring.md) first.
