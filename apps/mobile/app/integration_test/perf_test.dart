// The performance budget's measurement (#169): the three main paths in
// profile mode, each traced into a timeline and each counted request by
// request. Run through the driver, never `flutter test`, and only in
// profile mode, which is what the numbers mean:
//
//   .claude/skills/run-app/scripts/perf.sh run
//
// The app is the production graph (`registerApp`) over one fake leaf: the
// http client, answering in the process from a seeded, made-up journal.
// Frames then measure the app and not the network, and the request counts
// are exact. The latency of the real backend is measured apart from this,
// against the deployed services (`perf.sh latency`).

import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:emotely/app/environment.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_session/feature_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

import 'perf/fake_backend.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Frames come from the engine as on a phone, never from the test's own
    // pumps, which would add frames no user sees.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('the main paths stay within the performance budget', (
    tester,
  ) async {
    final backend = FakeBackend.seeded();
    final paths = PerfPaths(tester, binding, backend);
    await paths.compose();

    // Each path repeats its gesture until it draws a few hundred frames:
    // "under 1% of frames" needs that many to allow any at all, and a p90
    // over a few dozen frames moves with every run.
    await paths.measure('journal_scroll', paths.openJournalAndScroll);
    await paths.measure('entry_open', paths.openEntries);
    await paths.measure('session_round', paths.answerRounds);

    binding.reportData!['requests'] = paths.requests;
  });
}

/// The three paths, and what each asked of the backend.
class PerfPaths(
  final WidgetTester tester,
  final IntegrationTestWidgetsFlutterBinding binding,
  final FakeBackend backend,
) {
  /// How often the journal is flung to its end and back.
  static const scrollPasses = 3;

  /// How many times an entry is opened and closed again.
  static const entryOpenings = 8;

  /// How many questions the session answers.
  static const sessionRounds = 8;

  /// Each path's requests as `service METHOD /path`, in order.
  final requests = <String, List<String>>{};

  /// The app, composed as `main` composes it, signed in, over [backend].
  Future<void> compose() async {
    // The same call `main` makes; without a POSTHOG_KEY define it sets
    // nothing up, and analytics stay off as in a build without the key.
    await Posthog().setup(PostHogConfig(posthogKey)..host = posthogHost);
    final supabase = SupabaseClient(
      FakeBackend.supabaseUrl,
      SupabaseStub.publishableKey,
      httpClient: backend,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    // A restored sign-in, as on every launch after the first.
    await supabase.auth.recoverSession(jsonEncode(SupabaseStub.session()));
    registerApp(
      GetIt.I,
      agentHttpClient: backend,
      configHttpClient: backend,
      supabase: supabase,
      posthog: Posthog(),
      appVersion: '1.0.0',
      build: testBuildInfo,
      agentUrl: FakeBackend.agentUrl,
      configUrl: FakeBackend.configUrl,
      passwordAccounts: const {},
      google: googleClients,
    );
  }

  /// Runs [path] under a timeline trace reported as [name], and records the
  /// requests it made.
  Future<void> measure(String name, Future<void> Function() path) async {
    final before = backend.requests.length;
    // Only the streams the frame summary reads: frames (Dart), the engine's
    // build and raster (Embedder) and garbage collection (GC). Every stream
    // overflows the ring buffer within a scroll, and an endless buffer runs
    // the app out of memory.
    await binding.traceAction(
      path,
      streams: const ['Dart', 'Embedder', 'GC'],
      reportKey: name,
    );
    requests[name] = backend.requests.sublist(before);
  }

  /// Launches onto the journal, then flings through all of it and back,
  /// [scrollPasses] times.
  Future<void> openJournalAndScroll() async {
    await tester.pumpWidget(const EmotelyApp());
    await tester.pumpAndSettle();
    expect(find.byKey(JournalView.entryKey(backend.firstId)), findsOneWidget);
    final list = find.byType(Scrollable).last;
    for (var pass = 0; pass < scrollPasses; pass++) {
      for (final direction in [-1, 1]) {
        for (var fling = 0; fling < 6; fling++) {
          await tester.fling(list, Offset(0, direction * 600), 3000);
          await tester.pumpAndSettle();
        }
      }
    }
  }

  /// Opens the newest entry, waits until it reads back and returns to the
  /// journal, [entryOpenings] times.
  Future<void> openEntries() async {
    for (var opening = 0; opening < entryOpenings; opening++) {
      await tester.tap(find.byKey(JournalView.entryKey(backend.firstId)));
      await tester.pumpAndSettle();
      expect(find.byKey(EntryView.summaryKey), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  }

  /// Starts a session and answers [sessionRounds] questions, each round
  /// ending on the agent's next one.
  Future<void> answerRounds() async {
    await tester.tap(find.byKey(JournalView.startKey));
    await tester.pumpAndSettle();
    for (var round = 1; round <= sessionRounds; round++) {
      expect(find.text('How would you rate made-up day $round?'), findsOne);
      await tapSliderAt(tester, find.byKey(RatingInput.sliderKey), 7);
      // Under benchmarkLive a pump draws nothing; the submit button is
      // enabled only once the frame after the tap has been built.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(RatingInput.submitKey));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('How would you rate made-up day ${sessionRounds + 1}?'),
      findsOne,
    );
  }
}
