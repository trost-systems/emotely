import 'package:analytics/analytics.dart' show OnboardingPhase;
import 'package:emotely/app/router.dart';
import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

void main() {
  group('authRedirect', () {
    final welcome = const OnboardingRoute().location;
    final journal = const JournalRoute().location;
    final account = const AccountRoute().location;
    final entry = const EntryRoute(id: 'e-1').location;
    String signIn({String? from}) => SignInRoute(from: from).location;
    String signUp({String? from}) =>
        SignInRoute(mode: SignInMode.signUp, from: from).location;
    String onboarding({String? from}) => OnboardingRoute(from: from).location;
    String afterSignIn({String? from}) => OnboardingRoute(
      phase: OnboardingPhase.afterSignIn,
      from: from,
    ).location;

    String? redirect({
      required bool signedIn,
      required String location,
      bool ready = false,
    }) => authRedirect(
      signedIn: signedIn,
      readyForAccount: ready,
      uri: Uri.parse(location),
    );

    group('signed out, onboarding not done', () {
      test('sends every location to onboarding, remembering where the user '
          'was going', () {
        expect(
          redirect(signedIn: false, location: entry),
          onboarding(from: entry),
        );
        expect(
          redirect(signedIn: false, location: '$account?x=1'),
          onboarding(from: '$account?x=1'),
        );
        expect(redirect(signedIn: false, location: journal), welcome);
      });

      test('leaves the user in onboarding', () {
        expect(redirect(signedIn: false, location: welcome), isNull);
        expect(
          redirect(signedIn: false, location: onboarding(from: entry)),
          isNull,
        );
      });

      test('keeps sign-up closed until onboarding is done', () {
        expect(
          redirect(signedIn: false, location: signUp(from: entry)),
          onboarding(from: entry),
        );
      });

      test('keeps "I have an account" open', () {
        expect(redirect(signedIn: false, location: signIn()), isNull);
        expect(
          redirect(signedIn: false, location: signIn(from: entry)),
          isNull,
        );
      });

      test('turns the step after sign-in back into onboarding', () {
        expect(
          redirect(signedIn: false, location: afterSignIn(from: entry)),
          onboarding(from: entry),
        );
      });
    });

    group('signed out, onboarding done on this device', () {
      test('sends onboarding and every other location to sign-up', () {
        expect(
          redirect(signedIn: false, location: welcome, ready: true),
          signUp(),
        );
        expect(
          redirect(
            signedIn: false,
            location: onboarding(from: entry),
            ready: true,
          ),
          signUp(from: entry),
        );
        expect(
          redirect(signedIn: false, location: entry, ready: true),
          signUp(from: entry),
        );
      });

      test('leaves the user on sign-up, and on sign-in', () {
        expect(
          redirect(signedIn: false, location: signUp(), ready: true),
          isNull,
        );
        expect(
          redirect(signedIn: false, location: signIn(), ready: true),
          isNull,
        );
      });
    });

    group('signed in', () {
      test('leads the moment of sign-in through the step after sign-in, '
          'with where the user was going', () {
        expect(
          redirect(signedIn: true, location: signUp(from: entry)),
          afterSignIn(from: entry),
        );
        expect(
          redirect(signedIn: true, location: signIn(from: entry)),
          afterSignIn(from: entry),
        );
        expect(redirect(signedIn: true, location: signIn()), afterSignIn());
      });

      test('honours only a location of this app that leads nowhere back', () {
        for (final from in [
          'https://example.com/x',
          'entries/e-1',
          signIn(),
          welcome,
        ]) {
          expect(
            redirect(signedIn: true, location: signIn(from: from)),
            afterSignIn(),
            reason: from,
          );
        }
      });

      test('saves a name the device still holds before anything else', () {
        expect(
          redirect(signedIn: true, location: journal, ready: true),
          afterSignIn(),
        );
        expect(
          redirect(signedIn: true, location: entry, ready: true),
          afterSignIn(from: entry),
        );
      });

      test('leaves the user on the step after sign-in', () {
        expect(redirect(signedIn: true, location: afterSignIn()), isNull);
        expect(
          redirect(signedIn: true, location: afterSignIn(), ready: true),
          isNull,
        );
      });

      test('has no business before sign-up any more', () {
        expect(redirect(signedIn: true, location: welcome), journal);
        expect(
          redirect(signedIn: true, location: onboarding(from: entry)),
          entry,
        );
      });

      test('leaves the user wherever else they are', () {
        expect(redirect(signedIn: true, location: journal), isNull);
        expect(redirect(signedIn: true, location: account), isNull);
      });
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

      expect(find.byType(WelcomeStepView), findsOneWidget);
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

      expect(find.byType(WelcomeStepView), findsOneWidget);
      expect(find.byType(AccountPage), findsNothing);

      // The usage-analytics answer went with the session: whoever signs in
      // next answers for themselves first.
      await tester.tap(find.byKey(UsageAnalyticsSheet.allowKey));
      await tester.pumpAndSettle();
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
