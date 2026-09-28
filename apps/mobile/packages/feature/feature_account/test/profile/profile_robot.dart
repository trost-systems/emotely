import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../fake_account_navigator.dart';
import '../strings.dart';

/// Drives the Profile screen, composed the way the app composes it: the
/// utilities and this feature registered over a scripted Supabase, a fake
/// navigator for what the app would do, opened on its own.
class ProfileRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  final Locale? locale,
}) {
  final analytics = AnalyticsSpy();
  final navigator = FakeAccountNavigator();

  Finder get profile => find.byType(ProfilePage);
  Finder get nameField => find.byKey(ProfileView.nameKey);
  Finder get avatar => find.byKey(ProfileView.avatarKey);
  Finder get email => find.byKey(ProfileView.emailKey);
  Finder get method => find.byKey(ProfileView.methodKey);
  Finder get placeholderLine => find.byKey(ProfileView.placeholderKey);
  Finder get retry => find.byKey(ProfileView.retryKey);
  Finder get signOut => find.byKey(ProfileView.signOutKey);
  Finder get busy => find.byType(CircularProgressIndicator);

  /// What the name field holds right now.
  String get name => tester.widget<TextField>(nameField).controller!.text;

  /// The letter in the avatar, or nothing when it shows an icon.
  String? get initial {
    final letters = find.descendant(of: avatar, matching: find.byType(Text));
    return letters.evaluate().isEmpty
        ? null
        : tester.widget<Text>(letters).data;
  }

  /// The message shown at the foot of the screen, if any.
  String? get message {
    final bar = find.byType(SnackBar);
    if (bar.evaluate().isEmpty) {
      return null;
    }
    final text = find.descendant(of: bar, matching: find.byType(Text));
    return tester.widget<Text>(text.first).data;
  }

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
    // The page alone rather than its route under More: More reads the
    // profile too, and would take the rounds a test scripts for this screen.
    // The helpers' own locale unless a test asks for another.
    return switch (locale) {
      final locale? => pageUnderTest(
        const ProfilePage(),
        localizations: accountLocalizations,
        locale: locale,
      ),
      null => pageUnderTest(
        const ProfilePage(),
        localizations: accountLocalizations,
      ),
    };
  }

  /// Opens the screen for an account of [provider] with address [email].
  Future<void> launch({
    String email = SupabaseStub.email,
    String? provider = 'google',
  }) async {
    await supabase.signedIn(email: email, provider: provider);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> settle() => tester.pumpAndSettle();

  /// Types [text] over whatever the field holds.
  Future<void> type(String text) async {
    await tester.enterText(nameField, text);
    await tester.pump();
  }

  /// The keyboard's done key.
  Future<void> done() async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();
  }

  /// Leaves the field without the done key: a tap elsewhere on the screen.
  Future<void> leaveField() async {
    await tester.tap(find.text(tester.strings.profileSignedInAsLabel));
    await settle();
  }

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle();
    await tester.tap(finder);
    await settle();
  }
}
