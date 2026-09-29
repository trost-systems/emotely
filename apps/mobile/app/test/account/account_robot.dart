import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/helpers.dart';

/// Drives the account screen through the real app against a scripted
/// Supabase: from the journal over the More tab to the screen, through the
/// confirmation, and back out to sign-in once the account is gone.
class AccountRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
}) {
  final analytics = AnalyticsSpy();

  Finder get home => find.byType(JournalPage);
  Finder get more => find.byType(MorePage);
  Finder get account => find.byType(AccountPage);
  Finder get welcome => find.byType(WelcomeStepView);
  Finder get moreTab => find.byKey(AppShell.moreTabKey);
  Finder get accountRow => find.byKey(MoreView.accountKey);
  Finder get deleteAccount => find.byKey(AccountView.deleteKey);
  Finder get confirmation => find.byType(AlertDialog);
  Finder get confirm => find.byKey(AccountView.confirmKey);
  Finder get cancel => find.byKey(AccountView.cancelKey);
  Finder get retry => find.byKey(AccountView.retryKey);
  Finder get signOut => find.byKey(AccountView.signOutKey);
  Finder get failure => find.text(strings.accountFailureMessage);
  Finder get busy => find.byType(CircularProgressIndicator);

  /// The account feature's strings in the language the app shows.
  AccountLocalizations get strings =>
      AccountLocalizations.of(tester.element(find.byType(Navigator).first));

  Widget get app =>
      appUnderTest(agent: agent, supabase: supabase, analytics: analytics);

  /// Launches the app signed in and opens the account screen.
  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
    await openAccount();
  }

  /// From wherever the app is: the More tab, then its account row.
  Future<void> openAccount() async {
    await tap(moreTab);
    await tap(accountRow);
  }

  /// Asks to delete the account; the confirmation is now open.
  Future<void> askToDelete() => tap(deleteAccount);

  Future<void> settle() => tester.pumpAndSettle();

  /// Scrolls to the target first: a list may be taller than the test
  /// viewport.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle();
  }

  Future<void> back() async {
    await tester.tapBack();
  }
}
