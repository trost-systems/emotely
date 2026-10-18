import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/register.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthApiException,
        AuthException,
        AuthRetryableFetchException,
        UserAttributes;

import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

const tokenGrant = 'POST /auth/v1/token';

final wrongPassword = authRefused(
  statusCode: 400,
  errorCode: 'invalid_credentials',
  message: 'Invalid login credentials',
);

void main() {
  group(SignInPage, () {
    group('signing in with a password', () {
      testWidgets('asks for the email and password, then opens the journal', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        expect(robot.signIn, findsOneWidget);
        expect(robot.obscured(robot.passwordField), isTrue);
        expect(robot.canSubmit, isFalse);
        expect(robot.canReset, isFalse);

        await robot.enterEmail('not an email');
        await robot.enterPassword(goodPassword);
        expect(robot.canSubmit, isFalse);

        // Signing in takes the password the account has, however short:
        // only a new password must be long enough.
        await robot.enterEmail('  ${SupabaseStub.email} ');
        await robot.enterPassword('short');
        expect(robot.canSubmit, isTrue);
        await robot.tapSubmit();
        await robot.settle();

        final grant = supabase.to(tokenGrant).single;
        expect(grant.query['grant_type'], 'password');
        expect((grant.body! as Map)['email'], SupabaseStub.email);
        expect((grant.body! as Map)['password'], 'short');
        expect(supabase.to('POST /auth/v1/otp'), isEmpty);
        expect(supabase.to('POST /auth/v1/signup'), isEmpty);
        expect(robot.home, findsOneWidget);
        expect(robot.signIn, findsNothing);
        expect(
          robot.analytics.events.first,
          event('signed_in', {'method': 'password'}),
        );
        expect(robot.analytics.identified, [SupabaseStub.userId]);
      });

      testWidgets('shows the password on request, and hides it again', (
        tester,
      ) async {
        final robot = SignInRobot(
          tester,
          supabase: SupabaseStub(),
          agent: AgentStub(),
        );
        await robot.launch();
        await robot.enterPassword(goodPassword);

        await tester.tap(find.byTooltip(robot.strings.showPassword));
        await tester.pump();
        expect(robot.obscured(robot.passwordField), isFalse);

        await tester.tap(find.byTooltip(robot.strings.hidePassword));
        await tester.pump();
        expect(robot.obscured(robot.passwordField), isTrue);
      });

      testWidgets('is told when the password is not accepted and may retry', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(password: [wrongPassword, sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.submitCredentials(password: 'wrong');

        expect(robot.passwordField, findsOneWidget);
        robot.expectError(
          SignInProblem.wrongPassword,
          robot.strings.wrongPasswordMessage,
        );
        // GoTrue's code and status travel; its message does not, and the
        // password never does.
        expect(robot.analytics.exceptions, [
          captured(
            withheld(
              AuthApiException,
              code: 'invalid_credentials',
              statusCode: 400,
            ),
            {'step': 'sign_in_password'},
          ),
        ]);
        expect(robot.analytics.events, [event('sign_in_password_failed')]);

        await robot.enterPassword(goodPassword);
        await robot.tapSubmit();
        await robot.settle();

        expect(robot.home, findsOneWidget);
        expect(supabase.to(tokenGrant), hasLength(2));
      });

      testWidgets('is told to wait when the sign-in bucket is exhausted', (
        tester,
      ) async {
        // Many crawler instances behind one egress hit the per-IP limit
        // (`sign_in_sign_ups`); that is not a wrong password.
        final supabase = SupabaseStub()
          ..script(
            password: [
              authRefused(
                statusCode: 429,
                errorCode: 'over_request_rate_limit',
                message: 'Request rate limit reached',
              ),
            ],
          );
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        await robot.submitCredentials();

        robot.expectError(
          SignInProblem.tooManyAttempts,
          robot.strings.tooManyAttemptsMessage,
        );
      });

      testWidgets('submits from the keyboard once both are typed', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        // Nothing typed yet submits nothing.
        await robot.submitFromKeyboard(robot.passwordField);
        expect(supabase.to(tokenGrant), isEmpty);

        await robot.enterEmail(SupabaseStub.email);
        await robot.enterPassword(goodPassword);
        await robot.submitFromKeyboard(robot.passwordField);
        await robot.settle();

        expect(supabase.to(tokenGrant), hasLength(1));
        expect(robot.home, findsOneWidget);
      });

      testWidgets('shows progress while the password is checked', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(password: [delayedAuth(sessionGranted())]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.enterEmail(SupabaseStub.email);
        await robot.enterPassword(goodPassword);
        await robot.tapSubmit();

        expect(robot.busy, findsOneWidget);
        expect(robot.submit, findsNothing);
        expect(tester.widget<TextField>(robot.passwordField).enabled, isFalse);
        expect(robot.canTapGoogle, isFalse);

        await robot.settle();

        expect(robot.home, findsOneWidget);
      });

      testWidgets('treats a password answer without a session as rejected', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionWithheld()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        await robot.submitCredentials();

        robot.expectError(
          SignInProblem.wrongPassword,
          robot.strings.wrongPasswordMessage,
        );
        // supabase_auth 3 throws rather than answer without a session; a
        // 200 that signs no one in is the server misbehaving, so it is
        // reported like any other failed password grant.
        expect(robot.analytics.exceptions, [
          captured(withheld(AuthException), {'step': 'sign_in_password'}),
        ]);
      });

      testWidgets('is told when Supabase is unreachable', (tester) async {
        final supabase = SupabaseStub()..script(password: [authUnreachable()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        await robot.submitCredentials();

        robot.expectError(
          SignInProblem.unreachable,
          robot.strings.unreachableMessage,
        );
        expect(robot.analytics.exceptions, [
          captured(withheld(AuthRetryableFetchException), {
            'step': 'sign_in_password',
          }),
        ]);
      });

      testWidgets('sends an unconfirmed account a new confirmation code', (
        tester,
      ) async {
        // An account made with a password whose code was never typed in:
        // GoTrue grants it no session until it is.
        final supabase = SupabaseStub()
          ..script(
            password: [
              authRefused(
                statusCode: 400,
                errorCode: 'email_not_confirmed',
                message: 'Email not confirmed',
              ),
            ],
            resend: [codeSent()],
            verify: [sessionGranted()],
          );
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.submitCredentials();

        expect(robot.posted('resend').single, {
          'email': SupabaseStub.email,
          'type': 'signup',
          // The password grant took the first.
          'gotrue_meta_security': HumanCheckStub.security(2),
          'code_challenge': null,
          'code_challenge_method': null,
        });
        expect(
          find.text(robot.strings.confirmationSentMessage(SupabaseStub.email)),
          findsOneWidget,
        );
        expect(robot.analytics.exceptions, isEmpty);

        await robot.confirmWith();

        expect(robot.posted('verify').single['type'], 'signup');
        expect(robot.home, findsOneWidget);
      });

      testWidgets('survives the screen going away mid-request', (tester) async {
        final supabase = SupabaseStub()
          ..script(password: [delayedAuth(sessionGranted())]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();
        await robot.enterEmail(SupabaseStub.email);
        await robot.enterPassword(goodPassword);
        await robot.tapSubmit();

        // The whole app is torn down (bloc closed) before Supabase answers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
        expect(supabase.to(tokenGrant), hasLength(1));
      });
    });

    group("PostHog's internal-user flag", () {
      const internalEmail = 'test@getemotely.com';

      testWidgets('is set on a session restored for an internal address', (
        tester,
      ) async {
        final supabase = SupabaseStub();
        await supabase.signedIn(email: internalEmail);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();
        await robot.settle();

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.identities, [
          identity(SupabaseStub.userId, {r'$internal_or_test_user': true}),
        ]);
      });

      testWidgets('is set for a store review account signing in', (
        tester,
      ) async {
        const reviewer = 'google-play-review@getemotely.com';
        final supabase = SupabaseStub()
          ..script(password: [sessionGranted(email: reviewer)]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.submitCredentials(email: reviewer);

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.identities, [
          identity(SupabaseStub.userId, {r'$internal_or_test_user': true}),
        ]);
      });

      testWidgets('is cleared for an outside address signing in', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.submitCredentials();

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.identities, [
          identity(SupabaseStub.userId, {r'$internal_or_test_user': false}),
        ]);
      });

      testWidgets('is set when a session for an internal address arrives', (
        tester,
      ) async {
        final supabase = SupabaseStub();
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();
        await robot.settle();

        expect(robot.signIn, findsOneWidget);

        await supabase.signedIn(email: internalEmail);
        await robot.settle();

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.identities, [
          identity(SupabaseStub.userId, {r'$internal_or_test_user': true}),
        ]);
      });

      testWidgets('is refreshed when the same user changes address', (
        tester,
      ) async {
        final supabase = SupabaseStub();
        await supabase.signedIn();
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();
        await robot.settle();

        // An email change: same user, new address, no new sign-in.
        supabase.rest('PUT /auth/v1/user', [userUpdated(email: internalEmail)]);
        await supabase.supabase.auth.updateUser(
          UserAttributes(email: internalEmail),
        );
        await robot.settle();

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.identities, [
          identity(SupabaseStub.userId, {r'$internal_or_test_user': false}),
          identity(SupabaseStub.userId, {r'$internal_or_test_user': true}),
        ]);
      });
    });

    testWidgets('returns to sign-in when the session ends', (tester) async {
      final supabase = SupabaseStub()..script(logout: [signedOut()]);
      await supabase.signedIn();
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();
      await robot.settle();

      expect(robot.home, findsOneWidget);

      await supabase.supabase.auth.signOut();
      await robot.settle();

      expect(robot.signIn, findsOneWidget);
    });

    testWidgets('opens the journal when a session arrives after launch', (
      tester,
    ) async {
      // The SDK restores a persisted session on its own time; the app must
      // follow its auth stream, not only the answer it read at launch.
      final supabase = SupabaseStub();
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();
      await robot.settle();

      expect(robot.signIn, findsOneWidget);

      await supabase.signedIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('stays put when the SDK reports an auth error', (tester) async {
      final supabase = SupabaseStub()..script(logout: [signedOut()]);
      await supabase.signedIn();
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();
      await robot.settle();

      // A corrupt persisted session: the SDK signs out locally and reports
      // the error on its auth stream. The app must not crash on the report.
      await expectLater(
        supabase.supabase.auth.recoverSession('{}'),
        throwsA(isA<AuthException>()),
      );
      await robot.settle();

      expect(robot.signIn, findsOneWidget);
    });

    group('signing out', () {
      testWidgets('forgets the user and returns to sign-in', (tester) async {
        final supabase = SupabaseStub()..script(logout: [signedOut()]);
        await supabase.signedIn();
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        expect(robot.home, findsOneWidget);

        await robot.signOut();

        expect(robot.signIn, findsOneWidget);
        expect(supabase.to('POST /auth/v1/logout'), hasLength(1));
        expect(robot.analytics.events.last, event('signed_out'));
        expect(robot.analytics.resets, 1);
      });

      testWidgets('tells PostHog, and forgets the choice, before the session '
          'ends', (tester) async {
        final supabase = SupabaseStub();
        await supabase.signedIn();
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        // What PostHog had heard when the SDK told the server; the session
        // was dropped on the device just before, and the router follows it.
        late List<CapturedEvent> heard;
        late int resets;
        supabase.script(
          logout: [
            () {
              heard = [...robot.analytics.events];
              resets = robot.analytics.resets;
              return signedOut()();
            },
          ],
        );
        await robot.launch();

        await robot.signOut();

        expect(heard.last, event('signed_out'));
        expect(resets, 1);
      });

      testWidgets('signs out even when the server cannot be told', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(logout: [authUnreachable()]);
        await supabase.signedIn();
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        await robot.signOut();

        expect(robot.signIn, findsOneWidget);
        expect(robot.analytics.resets, 1);
      });
    });

    testWidgets('links the privacy notice before an account exists', (
      tester,
    ) async {
      // Play expects the policy to be findable without signing in; this is
      // the first screen anyone sees, so the link lives here too.
      final launcher = UrlLauncherSpy.setup();
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
      );
      await robot.launch();

      await tester.tap(find.byKey(SignInPage.privacyNoticeKey));
      await robot.settle();

      expect(launcher.launched, [privacyNoticeUrl(const Locale('de'))]);
    });

    testWidgets('renders nothing once signed in; the root swaps the screen', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      await supabase.signedIn();
      addTearDown(GetIt.I.reset);
      registerUtilitiesUnderTest(
        GetIt.I,
        agent: AgentStub(),
        supabase: supabase,
        analytics: AnalyticsSpy(),
      );
      registerAuth(GetIt.I, google: SignInRobot.googleClients);
      GetIt.I.registerSingleton<SignInNavigator>(FakeSignInNavigator());

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GetIt.I<AuthBloc>(),
          child: pageUnderTest(
            const SignInPage(),
            localizations: SignInRobot.localizations,
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('meets accessibility guidelines with an error showing', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(password: [wrongPassword]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());

      await tester.expectMeetsAccessibilityGuidelines(robot.app);
      // A second composition in one test starts from an empty container.
      await GetIt.I.reset();
      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => robot.submitCredentials(password: 'wrong'),
      );
    });
  });
}
