import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_session/feature_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/helpers.dart';

/// Drives the consent gate through the real app against a scripted Supabase:
/// from the journal into the consent screen, through the box and the button,
/// and into (or away from) a session; and over the More tab to Privacy
/// settings, whose switch takes consent back and gives it again.
class ConsentRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
}) {
  final analytics = AnalyticsSpy();

  Finder get home => find.byType(JournalPage);
  Finder get more => find.byType(MorePage);
  Finder get signIn => find.byType(SignInPage);
  Finder get signInNotice => find.byKey(SignInPage.privacyNoticeKey);
  Finder get consent => find.byType(ConsentPage);
  Finder get session => find.byType(SessionPage);
  Finder get account => find.byType(AccountPage);

  Finder get start => find.byKey(JournalView.startKey);
  Finder get continueSession => find.byKey(JournalView.continueKey);
  Finder get journalTab => find.byKey(AppShell.journalTabKey);
  Finder get moreTab => find.byKey(AppShell.moreTabKey);

  Finder get checkbox => find.byKey(ConsentView.checkboxKey);
  Finder get agree => find.byKey(ConsentView.agreeKey);
  Finder get decline => find.byKey(ConsentView.declineKey);
  Finder get notice => find.byKey(ConsentView.noticeKey);
  Finder get retry => find.byKey(ConsentView.retryKey);
  Finder get consentFailure => find.text(consentFailureMessage);
  Finder get declined => find.text(consentDeclinedMessage);

  Finder get privacySettings => find.byKey(MoreView.privacySettingsKey);
  Finder get journalSwitch => find.byKey(PrivacySettingsPage.journalKey);
  Finder get confirmWithdrawal => find.byKey(PrivacySettingsPage.confirmKey);
  Finder get journalRetry => find.byKey(PrivacySettingsPage.journalRetryKey);
  Finder get moreNotice => find.byKey(MoreView.privacyNoticeKey);
  Finder get moreImprint => find.byKey(MoreView.imprintKey);
  Finder get withdrawFailure => find.text(withdrawFailureMessage);

  Widget get app =>
      appUnderTest(agent: agent, supabase: supabase, analytics: analytics);

  /// Launches the app signed in and lets the journal load.
  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
  }

  /// Taps Start a session, which is what puts the gate in the way.
  Future<void> startSession() => tap(start);

  /// The affirmative act: tick the box, then press the button.
  Future<void> consentAndContinue() async {
    await tap(checkbox);
    await tap(agree);
  }

  Future<void> settle() => tester.pumpAndSettle();

  /// Taps [finder], scrolling it into view first. The consent screen says
  /// more than fits a test viewport — deliberately, since it has to be read
  /// — so every control on it needs scrolling to before it can be tapped.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle();
    await tester.tap(finder);
    await settle();
  }

  /// Whether the journal switch on Privacy settings is on.
  bool get journalOn => tester.widget<SwitchListTile>(journalSwitch).value;

  /// Turns journal sessions off: the switch, then the confirmation.
  Future<void> withdraw() async {
    await tap(journalSwitch);
    await tap(confirmWithdrawal);
  }

  Future<void> back() async {
    await tester.pageBack();
    await settle();
  }
}
