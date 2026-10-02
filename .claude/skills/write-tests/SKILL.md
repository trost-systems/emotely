---
name: write-tests
description: Flutter testing conventions for apps/mobile/app. Use whenever writing or reviewing Dart/Flutter tests — widget tests, bloc tests, integration tests, mocks, or the coverage gate.
---

# Writing tests for apps/mobile

The philosophy: **drive tests through the UI with real blocs; mock the agent
API at the http seam — never a bloc.** Error states are injected by making the
mocked API return them. Coverage is a hard 100% CI gate, per package: run
`melos run test` from `apps/mobile` (or `very_good test --coverage
--min-coverage 100 --exclude-coverage '**/*.{freezed,g,gen,mocks}.dart'` inside
one package). `analysis` and `testing` have no tests and are not measured.

Read the reference for the kind of test you are writing:

- [Widget tests](references/widget-tests.md) — pump helper, finders, a11y
  check, pump discipline, naming
- [Bloc unit tests](references/bloc-tests.md) — when they are allowed, blocTest
  shape
- [Mocking](references/mocking.md) — mockito, the single mocks.dart, what may
  be mocked
- [Integration tests](references/integration-tests.md) — robot pattern, canned
  agent rounds, the nightly live smoke
- [Coverage](references/coverage.md) — the 100% gate and its exemptions

Non-negotiables that apply to every test file:

1. Every widget test file also runs the 3-line a11y guideline check
   (`expectMeetsAccessibilityGuidelines` from `package:testing`, the shared
   test-support package in `apps/mobile/packages/utility/testing`; the app's
   `test/helpers/helpers.dart` re-exports it).
2. No test may hit the network.
3. `group()` takes the class reference, not a string; test names are plain
   declarative sentences — no given/when/then, no "should", no Arrange/Act
   comments.
