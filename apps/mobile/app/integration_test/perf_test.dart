// The performance budget's frames (#169): the three main paths in profile
// mode, each traced into a timeline and each counted request by request.
// Run through the driver, never `flutter test`, and only in profile mode,
// which is what the numbers mean:
//
//   .claude/skills/run-app/scripts/perf.sh run
//
// The app is the production graph (`registerApp`) over one fake leaf: the
// http client, answering in the process from a seeded, made-up journal.
// Frames then measure the app and not the network. The paths live in
// perf/perf_paths.dart, which the request-count widget test drives too: that
// test gates every pull request on the counts, this run reports them
// nightly beside the frames. The latency of the real backend is measured
// apart from this, against the deployed services (`perf.sh latency`).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/fake_backend.dart';
import 'perf/perf_paths.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Frames come from the engine as on a phone, never from the test's own
    // pumps, which would add frames no user sees.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('the main paths stay within the performance budget', (
    tester,
  ) async {
    final backend = FakeBackend.seeded();
    final paths = PerfPaths(tester, backend);
    await paths.compose();

    // Each path under a timeline trace reported by its name. Only the
    // streams the frame summary reads: frames (Dart), the engine's build
    // and raster (Embedder) and garbage collection (GC). Every stream
    // overflows the ring buffer within a scroll, and an endless buffer
    // runs the app out of memory.
    Future<void> Function(Future<void> Function()) traced(String name) =>
        (path) => binding.traceAction(
          path,
          streams: const ['Dart', 'Embedder', 'GC'],
          reportKey: name,
        );

    // Each path repeats its gesture until it draws several hundred frames,
    // even on the slow nightly emulator: "under 1% of frames" needs that
    // many to allow any at all, and a p90 over a few dozen frames moves
    // with every run.
    for (final (name, path) in [
      ('journal_scroll', paths.openJournalAndScroll),
      ('entry_open', paths.openEntries),
      ('session_round', paths.answerRounds),
    ]) {
      await paths.record(name, path, around: traced(name));
    }

    binding.reportData!['requests'] = paths.requests;
  });
}
