import 'package:design_system/design_system.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_session/feature_session.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../perf/fake_backend.dart';
import 'frame_watch.dart';

/// The screens of the feature map (`.claude/skills/run-app/references/
/// feature-map.yaml`), each walked by a gesture a user makes there, in the
/// order the walk visits them. Every walk starts and ends on the signed-in
/// journal, except the sign-in screen's, which signs out and so comes last.
/// The names are the survey's (`integration_test/survey.yaml`), which maps
/// each to its route.
const surveyScreens = [
  'journal',
  'entry',
  'session',
  'more',
  'account',
  'consent',
  'sign_in',
];

/// The survey's walk over the app, composed over [backend]: the launch,
/// then each screen in [surveyScreens] that [run] is asked for, each under
/// a frame watch and with the requests it made.
class SurveyWalk(
  final WidgetTester tester,
  final FakeBackend backend,
  final EmotelyApp app,
) {
  /// How often each walk repeats its gesture, so that every screen draws
  /// enough frames for a percentile to mean something.
  static const repeats = 6;

  /// Walks the app and reports what it measured, as `survey.json` holds it:
  /// the launch, the display's refresh rate and each screen's frames and
  /// requests. [only] names the screens to walk; empty, it walks them all.
  Future<Map<String, Object?>> run(Set<String> only) async {
    final startup = await _launch();
    final screens = <String, Object?>{};
    for (final name in surveyScreens) {
      if (only.isNotEmpty && !only.contains(name)) {
        continue;
      }
      final before = backend.requests.length;
      final frames = await watchFrames(_walks[name]!);
      screens[name] = {...frames, 'requests': backend.requests.sublist(before)};
    }
    return {
      'schema': 1,
      'startup_ms': startup,
      'refresh_hz': tester.view.display.refreshRate,
      'screens': screens,
    };
  }

  late final Map<String, Future<void> Function()> _walks = {
    'journal': _journal,
    'entry': _entry,
    'session': _session,
    'more': _more,
    'account': _account,
    'consent': _consent,
    'sign_in': _signIn,
  };

  /// Launches signed in and returns the milliseconds until the journal's
  /// newest entry is on screen: the start-up a user waits through, from
  /// the app's first widget to its first useful frame, inside the process.
  Future<int> _launch() async {
    final clock = Stopwatch()..start();
    await tester.pumpWidget(app);
    final newest = find.byKey(JournalView.entryKey(backend.firstId));
    while (newest.evaluate().isEmpty) {
      if (clock.elapsed > const Duration(seconds: 30)) {
        fail('the journal did not show its newest entry within 30 s');
      }
      await SchedulerBinding.instance.endOfFrame;
    }
    final startup = clock.elapsedMilliseconds;
    await tester.pumpAndSettle();
    return startup;
  }

  /// The journal: flung to its end and back.
  Future<void> _journal() async {
    final list = find.byType(Scrollable).last;
    for (final direction in [-1, 1]) {
      for (var fling = 0; fling < repeats; fling++) {
        await tester.fling(list, Offset(0, direction * 600), 3000);
        await tester.pumpAndSettle();
      }
    }
  }

  /// An entry: the newest opened and closed again.
  Future<void> _entry() async {
    for (var opening = 0; opening < repeats; opening++) {
      await _tap(find.byKey(JournalView.entryKey(backend.firstId)));
      expect(find.byKey(EntryView.summaryKey), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  }

  /// A session: started, a round answered per repeat, then left.
  Future<void> _session() async {
    await _tap(find.byKey(JournalView.startKey));
    for (var round = 0; round < repeats * 2; round++) {
      await tapSliderAt(tester, find.byKey(RatingInput.sliderKey), 7);
      // Under benchmarkLive a pump draws nothing; the submit button is
      // enabled only once the frame after the tap has been built.
      await tester.pumpAndSettle();
      await _tap(find.byKey(RatingInput.submitKey));
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// More: its rows scrolled through, and the tab left and entered again.
  Future<void> _more() async {
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(find.byKey(AppShell.moreTabKey));
      final rows = find.byType(Scrollable).last;
      await tester.fling(rows, const Offset(0, -400), 2000);
      await tester.pumpAndSettle();
      await tester.fling(rows, const Offset(0, 400), 2000);
      await tester.pumpAndSettle();
      await _tap(find.byKey(AppShell.journalTabKey));
    }
  }

  /// The account screen: opened, its deletion asked for and cancelled.
  Future<void> _account() async {
    await _tap(find.byKey(AppShell.moreTabKey));
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(find.byKey(MoreView.accountKey));
      await _tap(find.byKey(AccountView.deleteKey));
      await _tap(find.byKey(AccountView.cancelKey));
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await _tap(find.byKey(AppShell.journalTabKey));
  }

  /// The consent screen: consent withdrawn on More, then given again there.
  Future<void> _consent() async {
    await _tap(find.byKey(AppShell.moreTabKey));
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(find.byKey(MoreView.withdrawConsentKey));
      await _tap(find.byKey(MoreView.restoreConsentKey));
      final checkbox = find.byKey(ConsentView.checkboxKey);
      await tester.dragUntilVisible(
        checkbox,
        find.byType(Scrollable).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await _tap(checkbox);
      await _tap(find.byKey(ConsentView.agreeKey));
      expect(find.byKey(MoreView.withdrawConsentKey), findsOneWidget);
    }
    await _tap(find.byKey(AppShell.journalTabKey));
  }

  /// Sign-in: signed out from More, then an address typed and a code
  /// asked for, and the address changed again.
  Future<void> _signIn() async {
    await _tap(find.byKey(AppShell.moreTabKey));
    await tester.ensureVisible(find.byKey(MoreView.signOutKey));
    await tester.pumpAndSettle();
    await _tap(find.byKey(MoreView.signOutKey));
    // Typing goes through the test's own text input, not the phone's
    // keyboard: a live binding leaves the platform's in place, and there
    // `enterText` types nothing.
    tester.testTextInput.register();
    try {
      for (var attempt = 0; attempt < repeats; attempt++) {
        await tester.enterText(
          find.byKey(SignInPage.emailKey),
          'made-up-$attempt@example.com',
        );
        await tester.pumpAndSettle();
        await _tap(find.byKey(SignInPage.sendCodeKey));
        _expectShown(find.byKey(SignInPage.codeKey), 'the code step');
        await _tap(find.byKey(SignInPage.changeEmailKey));
      }
    } finally {
      tester.testTextInput.unregister();
    }
  }

  /// Fails unless [target] is on screen, saying what is instead: the texts
  /// shown and the backend's last requests, which is all a run on Test Lab
  /// leaves to go on.
  void _expectShown(Finder target, String what) {
    if (target.evaluate().isNotEmpty) {
      return;
    }
    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .nonNulls;
    final requests = backend.requests.reversed.take(5).toList().reversed;
    fail(
      'expected $what; the screen shows ${texts.join(' | ')}; '
      'the last requests were ${requests.join(', ')}',
    );
  }

  Future<void> _tap(Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }
}
