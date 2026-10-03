# Coverage

- CI gate: `very_good test --coverage --min-coverage 100` per package
  (`melos run test` from `apps/mobile`) — hard failure below 100% in any
  package that has a `test/` directory. `analysis` and `testing` have none
  and are not measured; test support is not behavior.
- Exemptions are per-file and explicit: `// coverage:ignore-file` on its own
  line, reserved for composition roots (main.dart). Generated files
  (`*.freezed.dart`, `*.g.dart`, `*.gen.dart`, `*.mocks.dart`) are excluded
  via `--exclude-coverage '**/*.{freezed,g,gen,mocks}.dart'` on the same
  command.
- Generated files are committed; CI runs `dart run build_runner build
  --only-check` and fails on drift, so regenerate before pushing.
- Never chase the gate with tautological tests; if a line can't be reached
  through the UI or a justified bloc test, question the line.
