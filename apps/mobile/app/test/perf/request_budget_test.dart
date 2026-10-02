// The performance budget's request counts (#169) as an ordinary widget
// test, so every app pull request is gated on them in seconds: the same
// three paths the nightly profile run drives (integration_test/perf_test.dart),
// over the same in-process fake backend, counted request by request and
// held to `requests:` in integration_test/perf_budget.yaml, the one place the
// counts are written down. The frames stay with the nightly emulator run:
// a widget test draws no real frames.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';
import 'package:yaml/yaml.dart';

import '../../integration_test/perf/fake_backend.dart';
import '../../integration_test/perf/perf_paths.dart';

void main() {
  testWidgets('the main paths make exactly the requests the budget allows', (
    tester,
  ) async {
    // PostHog's native side does not exist here: the spy stands in for the
    // SDK (and the device's preferences), and the screen observer's own
    // channel answers with nothing, as in the app harness.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('posthog_flutter'),
      (call) async => null,
    );
    final budget = budgetedRequests(
      File('integration_test/perf_budget.yaml').readAsStringSync(),
    );
    // A shorter journal than the profile run's 300 entries: under 64 KiB,
    // Supabase's JSON codec decodes it inline instead of on an isolate,
    // which a widget test's fake clock would never let finish. The journal
    // is read in one request however long it is, and 50 entries still
    // scroll well past a screen, so the counts are the same.
    final backend = FakeBackend.seeded(count: 50);
    final paths = PerfPaths(tester, backend);
    await paths.compose(posthog: AnalyticsSpy().posthog);

    await paths.record('journal_scroll', paths.openJournalAndScroll);
    await paths.record('entry_open', paths.openEntries);
    await paths.record('session_round', paths.answerRounds);

    // Exact, both ways: a new request fails, and so does one that went
    // away, which asks for the lower number in the budget in the same pull
    // request, so the budget stays as tight as the app.
    expect(
      paths.counts(),
      budget,
      reason:
          'requests per path and service; the requests themselves:\n'
          '${paths.requests}\n'
          'Change integration_test/perf_budget.yaml only on purpose, and say '
          'why in the pull request.',
    );
  });
}

/// The budget's `requests:` as `{path: {service: count}}`.
Map<String, Map<String, int>> budgetedRequests(String budget) {
  final requests = (loadYaml(budget) as YamlMap)['requests'] as YamlMap;
  return {
    for (final MapEntry(:key, :value) in requests.entries)
      key as String: {
        for (final MapEntry(:key, :value) in (value as YamlMap).entries)
          key as String: value as int,
      },
  };
}
