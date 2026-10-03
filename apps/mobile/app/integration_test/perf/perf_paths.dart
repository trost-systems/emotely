import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:design_system/design_system.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:emotely/app/environment.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_session/feature_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

import 'fake_backend.dart';

/// The performance budget's three main paths (#169), and what each asked
/// of the backend. Two drivers share them, so they measure the same thing:
/// the nightly profile run (integration_test/perf_test.dart), which traces
/// each path's frames, and the request-count test every pull request runs
/// (test/perf/request_budget_test.dart).
class PerfPaths(final WidgetTester tester, final FakeBackend backend) {
  /// How often the journal is flung to its end and back.
  static const scrollPasses = 1;

  /// How many times an entry is opened and closed again.
  static const entryOpenings = 12;

  /// How many questions the session answers.
  static const sessionRounds = 16;

  /// Each path's requests as `service METHOD /path`, in order.
  final requests = <String, List<String>>{};

  /// The app as `main` composes it, over [backend]: signed in, and past
  /// the first-launch usage-analytics sheet.
  late EmotelyApp app;

  /// Composes [app] as `main` does, signed in, over [backend].
  /// [posthog] is the SDK the gate opens: the real one on a device, the
  /// test package's spy in a widget test, where no native side exists.
  Future<void> compose({Posthog? posthog}) async {
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
    addTearDown(GetIt.I.reset);
    registerApp(
      GetIt.I,
      agentHttpClient: backend,
      configHttpClient: backend,
      supabase: supabase,
      posthog: posthog ?? Posthog(),
      // Without a POSTHOG_KEY define the gate sets nothing up, and
      // analytics stay off as in a build without the key.
      posthogConfig: PostHogConfig(posthogKey)..host = posthogHost,
      appVersion: '1.0.0',
      build: testBuildInfo,
      agentUrl: FakeBackend.agentUrl,
      configUrl: FakeBackend.configUrl,
      passwordAccounts: const {},
      google: googleClients,
    );
    // What `main` reads before the first frame. Usage analytics are
    // allowed, as a tester would on the first-launch sheet, so the sheet
    // never covers the journal and the analytics calls run as they do for
    // most users (#204).
    final gate = GetIt.I<PostHogGate>();
    await gate.restore(account: supabase.auth.currentUser?.id);
    await gate.allow();
    final onboarding = GetIt.I<OnboardingStore>();
    await onboarding.restore();
    app = EmotelyApp(
      screenViews: gate.screenObserver(),
      onboarding: onboarding,
      debugBanner: debugBanner,
    );
    // What the restored sign-in sets off before the first frame (the
    // usage-analytics record checks its consent) belongs to the launch, not
    // to the first path. On a device it is done by now; under a widget
    // test's fake clock it waits for this.
    await tester.idle();
  }

  /// Runs [path] and records the requests it made as [name]. [around]
  /// wraps the run, as the profile run wraps it in a timeline trace.
  Future<void> record(
    String name,
    Future<void> Function() path, {
    Future<void> Function(Future<void> Function() path)? around,
  }) async {
    final before = backend.requests.length;
    await (around ?? (path) => path())(path);
    requests[name] = backend.requests.sublist(before);
  }

  /// The requests per path and service, as the budget counts them.
  Map<String, Map<String, int>> counts() => {
    for (final MapEntry(:key, :value) in requests.entries)
      key: {for (final request in value) request.split(' ').first: 0}
        ..updateAll(
          (service, _) =>
              value.where((request) => request.startsWith('$service ')).length,
        ),
  };

  /// Launches onto the journal, then flings through all of it and back,
  /// [scrollPasses] times.
  Future<void> openJournalAndScroll() async {
    await tester.pumpWidget(app);
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
