import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../strings.dart';

/// Drives the consent screen on its own route, mounted the way the app
/// mounts it and pushed from a launcher the way the journal pushes it —
/// and records what the route popped with.
class _ConsentRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  final Locale? locale,
}) {
  final analytics = AnalyticsSpy();

  /// What the consent route popped with, once it has.
  ConsentOutcome? result;

  static const openKey = Key('launcher.open');

  Finder get launcher => find.byKey(openKey);
  Finder get consent => find.byType(ConsentPage);
  Finder get checkbox => find.byKey(ConsentView.checkboxKey);
  Finder get agree => find.byKey(ConsentView.agreeKey);
  Finder get decline => find.byKey(ConsentView.declineKey);
  Finder get notice => find.byKey(ConsentView.noticeKey);
  Finder get retry => find.byKey(ConsentView.retryKey);
  Finder get busy => find.byType(CircularProgressIndicator);

  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    registerAccount(GetIt.I);
    // The consent route as the app mounts it, pushed from a launcher the
    // way the journal pushes it; the route brings its own bloc.
    final routes = [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              key: openKey,
              onPressed: () async {
                result = await const ConsentRoute().push<ConsentOutcome>(
                  context,
                );
              },
              child: const Text('Start'),
            ),
          ),
        ),
      ),
      $consentRoute,
    ];
    // The helpers' own locale unless a test asks for another.
    return switch (locale) {
      final locale? => featureUnderTest(
        routes: routes,
        initialLocation: '/',
        localizations: accountLocalizations,
        locale: locale,
      ),
      null => featureUnderTest(
        routes: routes,
        initialLocation: '/',
        localizations: accountLocalizations,
      ),
    };
  }

  /// Signed in, with the consent screen open.
  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
    await tap(launcher);
  }

  /// The affirmative act: tick the box, then press the button.
  Future<void> consentAndContinue() async {
    await tap(checkbox);
    await tap(agree);
  }

  Future<void> settle() => tester.pumpAndSettle();

  /// Taps [finder], scrolling it into view first: the screen says more than
  /// fits a test viewport, deliberately.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle();
  }

  Future<void> back() async {
    await tester.tapBack();
  }
}

void main() {
  group(ConsentPage, () {
    const version = {'version': testConsentVersion};

    _ConsentRobot robotWith(
      WidgetTester tester, {
      bool granted = false,
      List<AuthRound> grants = const [],
      List<AuthRound> reads = const [],
      Locale? locale,
    }) {
      final supabase = SupabaseStub()
        ..rest(consentRead, reads)
        ..always(consentRead, consentStands(granted: granted))
        ..rest(consentGrant, grants);
      return _ConsentRobot(tester, supabase: supabase, locale: locale);
    }

    testWidgets('asks, and records the consent once box and button agree', (
      tester,
    ) async {
      final robot = robotWith(tester, grants: [rpcReturned(null)]);
      await robot.launch();

      final strings = tester.strings;
      expect(find.text(strings.consentTitle), findsOneWidget);
      // Three points, each read as one sentence by a screen reader: the
      // lead and its body are one text, not a heading and a paragraph.
      for (final point in consentPoints(strings)) {
        expect(find.text('${point.lead} ${point.body}'), findsOneWidget);
      }
      // The box starts unticked, and until it is ticked the button cannot
      // be pressed at all: no pre-ticked box, and no "by continuing".
      expect(tester.widget<CheckboxListTile>(robot.checkbox).value, isFalse);
      expect(tester.widget<FilledButton>(robot.agree).enabled, isFalse);

      await robot.consentAndContinue();

      // Recorded server-side, naming the wording that was agreed to, and
      // only then does the route answer yes.
      expect(robot.supabase.bodies('/rest/v1/rpc/record_consent'), [version]);
      expect(robot.result, ConsentOutcome.granted);
      expect(robot.consent, findsNothing);
      expect(robot.analytics.events, [event('consent_granted', version)]);
    });

    testWidgets('declining records nothing and answers no', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.decline);

      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.result, ConsentOutcome.declined);
      expect(robot.analytics.events, [event('consent_declined', version)]);
    });

    testWidgets('leaving by the back arrow is not an answer', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.back();

      expect(robot.result, isNull);
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.analytics.events, isEmpty);
    });

    testWidgets('the notice is a link the screen can open', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.notice);

      expect(launcher.launched, [privacyNoticeUrl]);
    });

    testWidgets('the checkbox row spans the whole width', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      // The row is the tap target for the decision, so it runs edge to edge
      // with its box and label 16 in, rather than being a strip inside the
      // page margin that highlights narrower than it looks.
      final screen = tester.getRect(
        find.descendant(of: robot.consent, matching: find.byType(Scaffold)),
      );
      final row = tester.getRect(robot.checkbox);
      expect(row.left, screen.left);
      expect(row.width, screen.width);
      expect(
        tester.getRect(find.byType(Checkbox)).left,
        greaterThanOrEqualTo(screen.left + 16),
      );
    });

    testWidgets('shows progress while it reads, and while it writes', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        reads: [delayedAuth(consentStands(granted: false))],
        grants: [delayedAuth(rpcReturned(null))],
      );
      await robot.supabase.signedIn();
      await tester.pumpWidget(robot.app);
      await tester.pump();
      await tester.tap(robot.launcher);
      await tester.pump();
      await tester.pump();

      expect(robot.busy, findsOneWidget);
      expect(robot.agree, findsNothing);

      await robot.settle();
      await robot.tap(robot.checkbox);
      await tester.tap(robot.agree);
      await tester.pump();

      expect(robot.busy, findsOneWidget);
      // The write is in flight; leaving now would strand it.
      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(robot.consent, findsOneWidget);

      await robot.settle();

      expect(robot.result, ConsentOutcome.granted);
    });

    testWidgets('a consent that cannot be recorded starts nothing', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        grants: [restRefused(), rpcReturned(null)],
      );
      await robot.launch();

      await robot.consentAndContinue();

      expect(robot.result, isNull);
      expect(find.text(tester.strings.consentFailureMessage), findsOneWidget);
      expect(robot.analytics.events, isEmpty);
      expect(robot.analytics.exceptions, hasLength(1));

      await robot.tap(robot.retry);

      expect(robot.supabase.to(consentGrant), hasLength(2));
      expect(robot.result, ConsentOutcome.granted);
    });

    testWidgets('leaving after a failed write answers with the failure', (
      tester,
    ) async {
      // Someone who ticked the box and hit a network error did not say
      // "Not now"; what the route answers keeps the two apart.
      final robot = robotWith(tester, grants: [restRefused()]);
      await robot.launch();
      await robot.consentAndContinue();

      await robot.tap(robot.decline);

      expect(robot.result, ConsentOutcome.writeFailed);
    });

    testWidgets('a consent that cannot be read is asked to be read again', (
      tester,
    ) async {
      // Re-asking someone who has already consented, every time the
      // network hiccups, trains them to tick the box without reading it.
      final robot = robotWith(tester, reads: [restRefused()]);
      await robot.launch();

      expect(find.text(tester.strings.consentUnknownMessage), findsOneWidget);
      expect(robot.checkbox, findsNothing);
      expect(robot.analytics.exceptions, hasLength(1));

      await robot.tap(robot.retry);

      expect(robot.checkbox, findsOneWidget);
    });

    testWidgets('a failed read can be backed out of', (tester) async {
      final robot = robotWith(tester, reads: [restRefused()]);
      await robot.launch();

      await robot.tap(robot.decline);

      // Not an answer: nothing was asked.
      expect(robot.result, isNull);
      expect(robot.analytics.events, isEmpty);
    });

    testWidgets('asks in German on a German phone', (tester) async {
      final german = lookupAccountLocalizations(const Locale('de'));
      final robot = robotWith(
        tester,
        grants: [rpcReturned(null)],
        locale: const Locale('de'),
      );
      await robot.launch();

      // The German wording the version names, as the screen shows it.
      expect(find.text(german.consentTitle), findsOneWidget);
      for (final point in consentPoints(german)) {
        expect(find.text('${point.lead} ${point.body}'), findsOneWidget);
      }
      for (final text in [
        german.consentCheckboxLabel,
        german.consentAgreeButton,
        german.consentDeclineButton,
        german.consentReadNoticeLink,
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }

      await robot.consentAndContinue();

      // The record names the one version, whatever the language.
      expect(robot.supabase.bodies('/rest/v1/rpc/record_consent'), [version]);
      expect(robot.result, ConsentOutcome.granted);
    });

    testWidgets('meets accessibility guidelines asking and failing', (
      tester,
    ) async {
      final robot = robotWith(tester, grants: [restRefused()]);
      await robot.supabase.signedIn();
      Future<Widget> freshApp() async {
        await GetIt.I.reset();
        return KeyedSubtree(key: UniqueKey(), child: robot.app);
      }

      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) => robot.tap(robot.launcher),
      );
      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) async {
          await robot.tap(robot.launcher);
          await robot.consentAndContinue();
        },
      );
    });
  });
}
