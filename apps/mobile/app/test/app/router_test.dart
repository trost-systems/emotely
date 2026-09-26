import 'package:emotely/app/router.dart';
import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('authRedirect', () {
    final signIn = const SignInRoute().location;
    final journal = const JournalRoute().location;
    final account = const AccountRoute().location;
    final entry = const EntryRoute(id: 'e-1').location;

    String? redirect({required bool signedIn, required String location}) =>
        authRedirect(signedIn: signedIn, uri: Uri.parse(location));

    test('sends a signed-out user to sign-in, remembering where they were '
        'going', () {
      expect(
        redirect(signedIn: false, location: entry),
        SignInRoute(from: entry).location,
      );
      expect(
        redirect(signedIn: false, location: '$account?x=1'),
        SignInRoute(from: '$account?x=1').location,
      );
    });

    test('remembers nothing for the journal itself', () {
      expect(redirect(signedIn: false, location: journal), signIn);
    });

    test('leaves a signed-out user on sign-in', () {
      expect(redirect(signedIn: false, location: signIn), isNull);
      expect(
        redirect(signedIn: false, location: SignInRoute(from: entry).location),
        isNull,
      );
    });

    test('sends a signed-in user on sign-in where they were going', () {
      expect(
        redirect(signedIn: true, location: SignInRoute(from: entry).location),
        entry,
      );
    });

    test('sends a signed-in user on sign-in to the journal otherwise', () {
      expect(redirect(signedIn: true, location: signIn), journal);
    });

    test('honours only a location of this app that is not sign-in', () {
      for (final from in ['https://example.com/x', 'entries/e-1', signIn]) {
        expect(
          redirect(signedIn: true, location: SignInRoute(from: from).location),
          journal,
          reason: from,
        );
      }
    });

    test('leaves a signed-in user wherever they are', () {
      expect(redirect(signedIn: true, location: journal), isNull);
      expect(redirect(signedIn: true, location: account), isNull);
    });
  });

  group('the router', () {
    final entry = entryRow(
      id: 'e-1',
      summary: 'A calm day.',
      createdAt: DateTime.utc(2026, 9, 7, 20),
    );

    testWidgets('honours a deep link opened while signed out once the user '
        'signs in', (tester) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()])
        ..always('GET /rest/v1/entries', rows([entry]));
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: AnalyticsSpy(),
        ),
      );
      await tester.pumpAndSettle();

      await deepLink(tester, const EntryRoute(id: 'e-1').location);

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(EntryPage), findsNothing);

      await signInThroughTheScreen(tester);

      expect(find.byType(EntryPage), findsOneWidget);
      expect(find.text('A calm day.'), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    });

    testWidgets('returns to the screen the user was on when the session '
        'ended under them', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          logout: [signedOut()],
          otp: [codeSent()],
          verify: [sessionGranted()],
        );
      await supabase.signedIn();
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: AnalyticsSpy(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppShell.moreTabKey));
      await tester.pumpAndSettle();
      // Deleting the account sits alone at the bottom of More.
      await tester.ensureVisible(find.byKey(MoreView.accountKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MoreView.accountKey));
      await tester.pumpAndSettle();

      expect(find.byType(AccountPage), findsOneWidget);

      // The session ends under the user: revoked elsewhere, expired, or the
      // account deleted on another device.
      await supabase.supabase.auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(AccountPage), findsNothing);

      await signInThroughTheScreen(tester);

      expect(find.byType(AccountPage), findsOneWidget);
    });

    testWidgets('lands on the journal after a plain sign-in', (tester) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()]);
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: AnalyticsSpy(),
        ),
      );
      await tester.pumpAndSettle();

      await signInThroughTheScreen(tester);

      expect(find.byType(JournalPage), findsOneWidget);
    });
  });
}
