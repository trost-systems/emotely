import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';
import '../consent_robot.dart';

/// Taking consent back, and giving it again, from Privacy settings under
/// More. Art. 7 (3): withdrawal must be as easy as giving, and it must never
/// require deleting the account.
void main() {
  group('withdrawing consent', () {
    const journalViewed = {'entries': 0, 'open_session': false};
    const version = {'version': consentVersion};
    const deletion = 'POST /rest/v1/rpc/delete_account';

    ConsentRobot robotWith(
      WidgetTester tester, {
      bool granted = true,
      List<AuthRound> withdrawals = const [],
      List<AuthRound> grants = const [],
      List<AuthRound> reads = const [],
    }) {
      final supabase = SupabaseStub()
        ..rest(consentRead, reads)
        ..always(consentRead, consentStands(granted: granted))
        ..rest(consentWithdraw, withdrawals)
        ..rest(consentGrant, grants);
      final agent = AgentStub()
        ..script([awaiting(toolCallId: 'c1', question: rateQuestion)]);
      return ConsentRobot(tester, supabase: supabase, agent: agent);
    }

    /// From the journal over to the More tab and into Privacy settings,
    /// where consent is managed. More reads the record once for its status
    /// line, Privacy settings once for its switch.
    Future<void> openPrivacySettings(ConsentRobot robot) async {
      await robot.launch();
      await robot.tap(robot.moreTab);
      await robot.tap(robot.privacySettings);
    }

    testWidgets('is a switch and one confirmation, and touches neither the '
        'account nor the entries', (tester) async {
      final robot = robotWith(tester);
      await openPrivacySettings(robot);

      expect(robot.journalOn, isTrue);

      await robot.withdraw();

      expect(robot.supabase.to(consentWithdraw), hasLength(1));
      expect(robot.supabase.bodies('/rest/v1/rpc/withdraw_consent'), [
        {'version': consentVersion},
      ]);
      // The account is untouched: withdrawing is not deleting.
      expect(robot.supabase.to(deletion), isEmpty);
      expect(robot.journalOn, isFalse);
      expect(find.text(robot.strings.privacyJournalOffNote), findsOneWidget);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_withdrawn', version),
      ]);
    });

    testWidgets('stops the next session without deleting anything', (
      tester,
    ) async {
      // The server answers "stands" to More and Privacy settings and "does
      // not" from the withdrawal on, which is what it would really do.
      final robot = robotWith(
        tester,
        granted: false,
        reads: [consentStands(), consentStands()],
      );
      await openPrivacySettings(robot);
      await robot.withdraw();
      await robot.back();

      await robot.tap(robot.journalTab);

      // Back on the journal, Start now asks again rather than sending.
      expect(robot.home, findsOneWidget);
      await robot.startSession();

      expect(robot.consent, findsOneWidget);
      expect(robot.session, findsNothing);
    });

    testWidgets('can be given again, through the same question', (
      tester,
    ) async {
      // Four reads: More's, Privacy settings', the consent screen's (on its
      // own route, with a bloc of its own), and Privacy settings' again once
      // that route closes — which is when the server says it stands.
      final robot = robotWith(
        tester,
        reads: [
          consentStands(),
          consentStands(),
          consentStands(granted: false),
          consentStands(),
        ],
      );
      await openPrivacySettings(robot);
      await robot.withdraw();

      expect(robot.journalOn, isFalse);

      await robot.tap(robot.journalSwitch);

      // Not a one-tap re-grant: the second consent is the same paragraphs
      // and the same unticked box as the first. Art. 7 (3) makes withdrawal
      // as easy as giving, not giving easier the second time.
      expect(robot.consent, findsOneWidget);
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(tester.widget<CheckboxListTile>(robot.checkbox).value, isFalse);

      await robot.consentAndContinue();

      expect(robot.supabase.to(consentGrant), hasLength(1));
      expect(robot.journalOn, isTrue);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_withdrawn', version),
        event('consent_granted', version),
      ]);
    });

    testWidgets(
      'a withdrawal that fails leaves consent standing, and says so',
      (tester) async {
        final robot = robotWith(tester, withdrawals: [restRefused()]);
        await openPrivacySettings(robot);

        await robot.withdraw();

        // The server still has the consent, so the screen must not pretend
        // otherwise; it offers the same act again.
        expect(robot.withdrawFailure, findsOneWidget);
        expect(robot.journalOn, isTrue);
        expect(
          robot.analytics.events,
          isNot(contains(event('consent_withdrawn', version))),
        );

        await robot.withdraw();

        expect(robot.supabase.to(consentWithdraw), hasLength(2));
        expect(robot.journalOn, isFalse);
      },
    );

    testWidgets('says so, and retries, when the answer cannot be read', (
      tester,
    ) async {
      final robot = robotWith(tester, reads: [consentStands(), restRefused()]);
      await openPrivacySettings(robot);

      // A read that failed says nothing about whether consent stands, so
      // the switch is off-limits — but the card says why rather than
      // leaving someone who came here to withdraw with nothing, which is
      // the one thing Art. 7 (3) cannot tolerate.
      expect(
        tester.widget<SwitchListTile>(robot.journalSwitch).onChanged,
        isNull,
      );
      expect(find.text(robot.strings.consentUnknownMessage), findsOneWidget);

      await robot.tap(robot.journalRetry);

      // Looking again brings the control back.
      expect(robot.journalOn, isTrue);
      expect(find.text(robot.strings.consentUnknownMessage), findsNothing);
    });

    testWidgets('the notice is reachable before an account exists', (
      tester,
    ) async {
      // Play expects the policy to be findable without signing in: sign-in
      // links it, one tap from Welcome, before any account exists.
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await tester.pumpWidget(robot.app);
      await robot.settle();

      expect(robot.welcome, findsOneWidget);
      await robot.tap(robot.haveAccount);
      await robot.tap(robot.signInNotice);

      expect(launcher.launched, [privacyNoticeUrl(const Locale('en'))]);
    });

    testWidgets('the More tab links the notice and the imprint', (
      tester,
    ) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();
      await robot.tap(robot.moreTab);

      await robot.tap(robot.moreNotice);
      await robot.tap(robot.moreImprint);

      expect(launcher.launched, [
        privacyNoticeUrl(const Locale('en')),
        imprintUrl(const Locale('en')),
      ]);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      final robot = robotWith(tester);
      await robot.supabase.signedIn();

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) async {
          await robot.settle();
          await robot.tap(robot.moreTab);
          await robot.tap(robot.privacySettings);
        },
      );
    });
  });
}
