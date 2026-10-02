import 'package:analytics/analytics.dart';
import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../fake_account_navigator.dart';
import '../strings.dart';

/// Drives Privacy settings on its own route under More, composed the way
/// the app composes it: the utilities and this feature over a scripted
/// Supabase and a spied PostHog, and a fake navigator for the consent
/// screen the app would push.
class _PrivacyRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  final AnalyticsChoice? stored = AnalyticsChoice.allowed,
}) {
  late final analytics = AnalyticsSpy(stored: stored);
  final navigator = FakeAccountNavigator();

  Finder get journal => find.byKey(PrivacySettingsPage.journalKey);
  Finder get usage => find.byKey(PrivacySettingsPage.usageAnalyticsKey);
  Finder get confirm => find.byKey(PrivacySettingsPage.confirmKey);
  Finder get cancel => find.byKey(PrivacySettingsPage.cancelKey);
  Finder get retry => find.byKey(PrivacySettingsPage.journalRetryKey);
  Finder get notice => find.byKey(PrivacySettingsPage.noticeKey);

  bool isOn(Finder finder) => tester.widget<SwitchListTile>(finder).value;
  bool isEnabled(Finder finder) =>
      tester.widget<SwitchListTile>(finder).onChanged != null;

  /// Reading this composes the container, so read it once per test.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    registerAccount(GetIt.I);
    GetIt.I.registerSingleton<AccountNavigator>(navigator);
    return featureUnderTest(
      routes: [$moreRoute],
      initialLocation: const PrivacySettingsRoute().location,
      localizations: accountLocalizations,
    );
  }

  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
  }

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle();
    await tester.tap(finder);
    await settle();
  }
}

void main() {
  group(PrivacySettingsPage, () {
    _PrivacyRobot robotWith(
      WidgetTester tester, {
      bool granted = true,
      List<AuthRound> reads = const [],
      List<AuthRound> withdrawals = const [],
      AnalyticsChoice? stored = AnalyticsChoice.allowed,
    }) {
      // More sits under Privacy settings on the route stack and reads
      // first; [reads] are the ones Privacy settings makes.
      final supabase = SupabaseStub()
        ..rest(consentRead, [consentStands(granted: granted), ...reads])
        ..always(consentRead, consentStands(granted: granted))
        ..rest(consentWithdraw, withdrawals);
      return _PrivacyRobot(tester, supabase: supabase, stored: stored);
    }

    testWidgets('shows where both consents stand', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      expect(find.text(tester.strings.privacySettingsTitle), findsOneWidget);
      expect(robot.isOn(robot.journal), isTrue);
      expect(find.text(tester.strings.privacyJournalOnNote), findsOneWidget);
      expect(robot.isOn(robot.usage), isTrue);
      expect(
        find.text(tester.strings.privacyUsageAnalyticsNote),
        findsOneWidget,
      );
    });

    group('journal sessions', () {
      testWidgets('says when consent was given', (tester) async {
        final given = DateTime(2026, 9, 20, 18, 30);
        final robot = robotWith(tester);
        robot.supabase.rest('GET /rest/v1/consent_events', [
          rows([
            {'recorded_at': given.toUtc().toIso8601String()},
          ]),
        ]);
        await robot.launch();

        expect(
          find.text(
            '${tester.strings.privacyJournalGiven(given)} '
            '${tester.strings.privacyJournalOnNote}',
          ),
          findsOneWidget,
        );
      });

      testWidgets('leaves the date out when it cannot be read', (tester) async {
        final robot = robotWith(tester);
        robot.supabase.rest('GET /rest/v1/consent_events', [restRefused()]);
        await robot.launch();

        expect(robot.isOn(robot.journal), isTrue);
        expect(find.text(tester.strings.privacyJournalOnNote), findsOneWidget);
        // Not worth a report: nothing but a line of text depends on it.
        expect(robot.analytics.exceptions, isEmpty);
      });

      testWidgets('asks before turning off, then withdraws', (tester) async {
        final robot = robotWith(tester, withdrawals: [rpcReturned(null)]);
        await robot.launch();

        await robot.tap(robot.journal);

        expect(find.text(tester.strings.privacyConfirmMessage), findsOneWidget);
        expect(robot.supabase.to(consentWithdraw), isEmpty);

        await robot.tap(robot.confirm);

        expect(robot.supabase.to(consentWithdraw), hasLength(1));
        expect(robot.isOn(robot.journal), isFalse);
        expect(find.text(tester.strings.privacyJournalOffNote), findsOneWidget);
        expect(robot.analytics.events, [
          event('consent_withdrawn', {'version': testConsentVersion}),
        ]);
      });

      testWidgets('stays on when the question is cancelled', (tester) async {
        final robot = robotWith(tester);
        await robot.launch();

        await robot.tap(robot.journal);
        await robot.tap(robot.cancel);

        expect(robot.supabase.to(consentWithdraw), isEmpty);
        expect(robot.isOn(robot.journal), isTrue);
      });

      testWidgets('turning on opens the consent screen, then reads again', (
        tester,
      ) async {
        final robot = robotWith(tester, reads: [consentStands(granted: false)]);
        await robot.launch();

        expect(robot.isOn(robot.journal), isFalse);

        await robot.tap(robot.journal);

        // Not a grant on the spot: the wording is read on its own screen.
        expect(robot.navigator.consentRequests, 1);
        expect(robot.supabase.to(consentGrant), isEmpty);
        // The server, asked again once that screen closed, says it stands.
        expect(robot.isOn(robot.journal), isTrue);
      });

      testWidgets('a withdrawal that fails leaves it on, and says so', (
        tester,
      ) async {
        final robot = robotWith(tester, withdrawals: [restRefused()]);
        await robot.launch();

        await robot.tap(robot.journal);
        await robot.tap(robot.confirm);

        expect(robot.isOn(robot.journal), isTrue);
        expect(robot.isEnabled(robot.journal), isTrue);
        expect(
          find.text(tester.strings.consentWithdrawFailureMessage),
          findsOneWidget,
        );
      });

      testWidgets('cannot be switched while the answer is not in hand', (
        tester,
      ) async {
        final robot = robotWith(tester, reads: [restRefused()]);
        await robot.launch();

        expect(robot.isEnabled(robot.journal), isFalse);
        expect(find.text(tester.strings.consentUnknownMessage), findsOneWidget);

        await robot.tap(robot.retry);

        expect(robot.isEnabled(robot.journal), isTrue);
        expect(robot.isOn(robot.journal), isTrue);
      });

      testWidgets('shows progress while the answer is read', (tester) async {
        final robot = robotWith(tester, reads: [delayedAuth(consentStands())]);
        await robot.supabase.signedIn();
        await tester.pumpWidget(robot.app);
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(robot.isEnabled(robot.journal), isFalse);

        await robot.settle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('usage analytics', () {
      testWidgets('switches off at once, and PostHog with it', (tester) async {
        final robot = robotWith(tester);
        await robot.launch();

        await robot.tap(robot.usage);

        expect(robot.isOn(robot.usage), isFalse);
        expect(GetIt.I<PostHogGate>().choice, AnalyticsChoice.denied);
        expect(robot.analytics.lifecycle, ['setup', 'disable', 'close']);
      });

      testWidgets('switches on at once, and PostHog with it', (tester) async {
        final robot = robotWith(tester, stored: AnalyticsChoice.denied);
        await robot.launch();

        expect(robot.isOn(robot.usage), isFalse);

        await robot.tap(robot.usage);

        expect(robot.isOn(robot.usage), isTrue);
        expect(GetIt.I<PostHogGate>().choice, AnalyticsChoice.allowed);
        expect(robot.analytics.lifecycle, ['setup', 'reset']);
      });
    });

    testWidgets('links the privacy notice', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.notice);

      expect(launcher.launched, [privacyNoticeUrl(const Locale('de'))]);
    });

    testWidgets('meets accessibility guidelines with both on and both off', (
      tester,
    ) async {
      final on = robotWith(tester);
      await on.supabase.signedIn();
      await tester.expectMeetsAccessibilityGuidelines(on.app);

      await GetIt.I.reset();
      final off = robotWith(
        tester,
        granted: false,
        stored: AnalyticsChoice.denied,
      );
      await off.supabase.signedIn();
      await tester.expectMeetsAccessibilityGuidelines(
        KeyedSubtree(key: UniqueKey(), child: off.app),
      );
    });
  });
}
