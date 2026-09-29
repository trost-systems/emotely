# Widget tests

- Use the `pumpApp` extension from `package:testing` — real themes, real
  localization. `pageUnderTest(page)` is the same for a whole page that
  brings its own `Scaffold`, `featureUnderTest(routes:)` for a feature's
  routes. Each takes `localizations:` (the package's own delegate,
  `const [JournalLocalizations.delegate]`; design_system's and Flutter's
  are always added) and `locale:`.
- Read expected text through the package's class,
  `lookupJournalLocalizations(locale).entryTitle`, never as a literal: the
  test then holds in every locale, and a string that skipped the ARB files
  stays English under German and fails. Run the screens that matter once
  under `Locale('de')` too.
- Go back with `tester.tapBack()` from `package:testing`, not
  `tester.pageBack()`: the latter finds the button by its English tooltip.
- A feature package's page tests compose the way the app does, in a robot:
  `registerUtilitiesUnderTest(GetIt.I, agent:, supabase:, analytics:)`
  (every utility over the scripted leaves), then the feature's own
  `registerX(GetIt.I)`, then `pageUnderTest(TheFeaturePage())`. Nothing
  else is registered from a test; see mocking.md.
- Each test file defines a local `pumpTestWidget(tester, {...})` closure in
  `main()`'s scope; named parameters carry variation, mocks stay in scope.
- Provide REAL blocs backed by the mocked agent API. Never mock a bloc; reach
  rare states (errors, timeouts) by making the mocked API produce them.
- Finders, in order of preference: static `Key` constants declared on the
  widget class (`find.byKey(SubmitButton.submitKey)`), `find.byType`,
  localized text via the real l10n object
  (`tester.element(find.byType(WidgetUnderTest))`) — never hardcoded strings.
- Explicit `pump()` over `pumpAndSettle()`; settle only for animated
  transitions/navigation.
- Assert widget properties via `tester.widget<FilledButton>(finder).onPressed`
  for enabled/disabled.
- Run one test across locales with a `ValueVariant` subclass declared at the
  end of the file.
- Close every file's suite with the a11y check:
  `await tester.expectMeetsAccessibilityGuidelines(widgetUnderTest);`
