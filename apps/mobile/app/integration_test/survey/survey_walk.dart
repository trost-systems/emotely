import 'package:feature_journal/feature_journal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../perf/fake_backend.dart';
import '../perf/perf_paths.dart';
import 'frame_watch.dart';
import 'screen_deadline.dart';

/// The screens of the feature map (`.claude/skills/run-app/references/
/// feature-map.yaml`), each walked by a gesture a user makes there, in the
/// order the walk visits them. Every walk starts and ends on the signed-in
/// journal, except the last two: onboarding is where signing out lands, and
/// sign-in is reached from it. The names are the survey's
/// (`integration_test/survey.yaml`), which maps each to its route.
const surveyScreens = [
  'journal',
  'entry',
  'session',
  'more',
  'profile',
  'account',
  'privacy_settings',
  'consent',
  'onboarding',
  'sign_in',
];

/// A widget key as the feature map names it (`more_view.profile`): the
/// walk reaches every screen the way the map says an agent does.
Finder _key(String name) => find.byKey(Key(name));

/// The survey's walk over the app [paths] composed: the launch, then each
/// screen in [surveyScreens] that [run] is asked for, each under a frame
/// watch and with the requests it made. The entry and the session walk the
/// performance budget's own paths (`perf/perf_paths.dart`), so a phone's
/// numbers for them compare with the nightly emulator's.
class SurveyWalk(final WidgetTester tester, final PerfPaths paths) {
  /// How often each walk repeats its gesture, so that every screen draws
  /// enough frames for a percentile to mean something.
  static const repeats = 6;

  /// How long one screen's walk may take before it fails as hung: the
  /// slowest so far, the session on an iPhone, took about a minute.
  static const screenDeadline = Duration(minutes: 4);

  FakeBackend get backend => paths.backend;

  /// Where the walk is, in the device's log as it goes.
  final _crumbs = Breadcrumbs(debugPrintSynchronously);

  /// Runs [walk] as the screen [name], failing it as hung after
  /// [screenDeadline] with the step it was at and what the screen shows.
  Future<T> _guarded<T>(String name, Future<T> Function() walk) {
    _crumbs.screen(name);
    final clock = Stopwatch()..start();
    return withinDeadline(
      name,
      screenDeadline,
      walk,
      waitingOn: () => '${_crumbs.last}; ${_onScreen()}',
    ).whenComplete(
      () => debugPrintSynchronously(
        'survey: $name took ${clock.elapsedMilliseconds} ms',
      ),
    );
  }

  /// Walks the app and reports what it measured, as `survey.json` holds it:
  /// the launch, the display's refresh rate and each screen's frames and
  /// requests. [only] names the screens to walk; empty, it walks them all.
  /// Onboarding and sign-in need the sign-out before them, so asking for
  /// sign-in alone walks onboarding's way there unmeasured.
  Future<Map<String, Object?>> run(Set<String> only) async {
    final startup = await _guarded('launch', _launch);
    final screens = <String, Object?>{};
    for (final name in surveyScreens) {
      final wanted = only.isEmpty || only.contains(name);
      if (!wanted) {
        if (name == 'onboarding' && only.contains('sign_in')) {
          await _guarded('sign-out', _signOut);
        }
        continue;
      }
      final before = backend.requests.length;
      final frames = await _guarded(name, () => watchFrames(_walks[name]!));
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
    'entry': () {
      _crumbs.step("the budget's entry openings");
      return paths.openEntries();
    },
    'session': _session,
    'more': _more,
    'profile': _profile,
    'account': _account,
    'privacy_settings': _privacySettings,
    'consent': _consent,
    'onboarding': _onboarding,
    'sign_in': _signIn,
  };

  /// Launches signed in and returns the milliseconds until the journal's
  /// newest entry is on screen: the start-up a user waits through, from
  /// the app's first widget to its first useful frame, inside the process.
  Future<int> _launch() async {
    final clock = Stopwatch()..start();
    await tester.pumpWidget(paths.app);
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

  /// The journal: flung to its end and back. The budget's journal path
  /// launches the app as well; here the launch is measured on its own.
  Future<void> _journal() async {
    final list = find.byType(Scrollable).last;
    for (final direction in [-1, 1]) {
      for (var fling = 0; fling < repeats; fling++) {
        await _fling(list, Offset(0, direction * 600), 3000);
      }
    }
  }

  /// A session: the budget's rounds, then left.
  Future<void> _session() async {
    _crumbs.step("the budget's session rounds");
    await paths.answerRounds();
    await _back();
  }

  /// More: its rows scrolled through, and the tab left and entered again.
  Future<void> _more() async {
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(_key('app_shell.more'));
      final rows = find.byType(Scrollable).last;
      await _fling(rows, const Offset(0, -400), 2000);
      await _fling(rows, const Offset(0, 400), 2000);
      await _tap(_key('app_shell.journal'));
    }
  }

  /// The profile: opened from More and closed again.
  Future<void> _profile() => _onMore(() async {
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(_key('more_view.profile'));
      _expectShown(_key('profile_view.name'), 'the profile');
      await _back();
    }
  });

  /// The account screen: opened, its deletion asked for and canceled.
  Future<void> _account() => _onMore(() async {
    for (var visit = 0; visit < repeats; visit++) {
      await _tapVisible(_key('more_view.account'));
      await _tap(_key('account_view.delete'));
      await _tap(_key('account_view.cancel'));
      await _back();
    }
  });

  /// Privacy settings: opened from More and closed again.
  Future<void> _privacySettings() => _onMore(() async {
    for (var visit = 0; visit < repeats; visit++) {
      await _tapVisible(_key('more_view.privacy_settings'));
      _expectShown(_key('privacy_settings.journal'), 'privacy settings');
      await _back();
    }
  });

  /// The consent screen: the journal's consent turned off in privacy
  /// settings, then given again on the screen it opens.
  Future<void> _consent() => _onMore(() async {
    await _tapVisible(_key('more_view.privacy_settings'));
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(_key('privacy_settings.journal'));
      await _tap(_key('privacy_settings.confirm'));
      await _tap(_key('privacy_settings.journal'));
      final checkbox = _key('consent_view.checkbox');
      await tester.dragUntilVisible(
        checkbox,
        find.byType(Scrollable).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await _tap(checkbox);
      await _tap(_key('consent_view.agree'));
      _expectShown(_key('privacy_settings.journal'), 'privacy settings again');
    }
    await _back();
  });

  /// Onboarding: signed out onto Welcome, then its first steps taken and
  /// taken back.
  Future<void> _onboarding() async {
    await _signOut();
    for (var visit = 0; visit < repeats; visit++) {
      await _tap(_key('onboarding.welcome.get_started'));
      await _tap(_key('onboarding.value.continue'));
      await _tap(_key('onboarding.back'));
      await _tap(_key('onboarding.back'));
    }
  }

  /// Sign-in, from Welcome: an address typed and a reset code asked for
  /// ("Forgot password?"), and the address changed again.
  Future<void> _signIn() async {
    await _tap(_key('onboarding.welcome.have_account'));
    // Typing goes through the test's own text input, not the phone's
    // keyboard: a live binding leaves the platform's in place, and there
    // `enterText` types nothing.
    tester.testTextInput.register();
    // On iOS a focused field's cursor fades in and out by an animation
    // that never stops, so `pumpAndSettle` after typing never settled: the
    // walk hung there on an iPhone in Test Lab until the 20-minute timeout
    // (run 37105150605), and on the iOS simulator, where the screen
    // deadline caught it in the fourth address. Android blinks the cursor
    // by a timer and settles between blinks. A cursor that holds still is
    // the testing hook for exactly this, and its frames are no user's.
    EditableText.debugDeterministicCursor = true;
    try {
      for (var attempt = 0; attempt < repeats; attempt++) {
        _crumbs.step('type an address');
        await tester.enterText(
          _key('sign_in_page.email'),
          'made-up-$attempt@example.com',
        );
        await tester.pumpAndSettle();
        await _tapVisible(_key('sign_in_page.forgot_password'));
        _expectShown(_key('sign_in_page.code'), 'the reset code step');
        await _tapVisible(_key('sign_in_page.change_email'));
      }
    } finally {
      EditableText.debugDeterministicCursor = false;
      tester.testTextInput.unregister();
    }
  }

  /// Signs out from the profile and answers the usage-analytics sheet that
  /// comes up over Welcome, as a tester would.
  Future<void> _signOut() async {
    await _tap(_key('app_shell.more'));
    await _tap(_key('more_view.profile'));
    await _tapVisible(_key('profile_view.sign_out'));
    await _tap(_key('usage_analytics_sheet.allow'));
    _expectShown(_key('onboarding.welcome.get_started'), 'Welcome');
  }

  /// Runs [walk] on the More tab and returns to the journal.
  Future<void> _onMore(Future<void> Function() walk) async {
    await _tap(_key('app_shell.more'));
    await walk();
    await _tap(_key('app_shell.journal'));
  }

  /// Fails unless [target] is on screen, saying what is instead: the texts
  /// shown and the backend's last requests, which is all a run on Test Lab
  /// leaves to go on.
  void _expectShown(Finder target, String what) {
    if (target.evaluate().isNotEmpty) {
      return;
    }
    fail('expected $what; ${_onScreen()}');
  }

  /// What is on screen and what the backend was asked last.
  String _onScreen() {
    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .nonNulls;
    final requests = backend.requests.reversed.take(5).toList().reversed;
    return 'the screen shows ${texts.join(' | ')}; '
        'the last requests were ${requests.join(', ')}';
  }

  Future<void> _tap(Finder target) async {
    final what = target.describeMatch(Plurality.one);
    _expectShown(target, what);
    _crumbs.step('tap $what');
    await tester.tap(target);
    _crumbs.step('settle after tapping $what');
    await tester.pumpAndSettle();
  }

  /// Scrolls [target] into view first: rows below the fold on a small phone.
  Future<void> _tapVisible(Finder target) async {
    final what = target.describeMatch(Plurality.one);
    _expectShown(target, what);
    _crumbs.step('scroll to $what');
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await _tap(target);
  }

  Future<void> _back() async {
    _crumbs.step('back');
    await tester.pageBack();
    _crumbs.step('settle after back');
    await tester.pumpAndSettle();
  }

  Future<void> _fling(Finder target, Offset offset, double speed) async {
    _crumbs.step('fling $offset');
    await tester.fling(target, offset, speed);
    await tester.pumpAndSettle();
  }
}
