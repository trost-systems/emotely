import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
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

void main() {
  group(SignInPage, () {
    const code = '482913';

    testWidgets('asks for the email, then the code, then opens the journal', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      expect(robot.signIn, findsOneWidget);
      expect(robot.canSendCode, isFalse);

      await robot.enterEmail('not an email');
      expect(robot.canSendCode, isFalse);

      await robot.requestCode();

      expect(
        supabase.bodies('/auth/v1/otp').single['email'],
        SupabaseStub.email,
      );
      expect(robot.codeField, findsOneWidget);
      expect(find.textContaining(SupabaseStub.email), findsOneWidget);
      expect(robot.canSubmitCode, isFalse);

      await robot.enterCode('12');
      expect(robot.canSubmitCode, isFalse);
      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      final verify = supabase.bodies('/auth/v1/verify').single;
      expect(verify['email'], SupabaseStub.email);
      expect(verify['token'], code);
      expect(verify['type'], 'email');
      expect(robot.home, findsOneWidget);
      expect(robot.signIn, findsNothing);
    });

    testWidgets('shows progress while Supabase answers', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [delayedAuth(codeSent())],
          verify: [delayedAuth(sessionGranted())],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.enterEmail(SupabaseStub.email);
      await robot.tapSendCode();

      expect(robot.busy, findsOneWidget);
      expect(robot.sendCode, findsNothing);

      await robot.settle();

      expect(robot.busy, findsNothing);
      expect(robot.codeField, findsOneWidget);

      await robot.enterCode(code);
      await robot.tapSignIn();

      expect(robot.busy, findsOneWidget);
      expect(robot.submitCode, findsNothing);

      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('explains when Supabase refuses the email', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [
            authRefused(
              statusCode: 400,
              errorCode: 'validation_failed',
              message: 'Unable to validate email address',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode('nobody@example.invalid');

      expect(robot.emailField, findsOneWidget);
      expect(robot.errorText, SignInPage.couldNotSendMessage);
      // GoTrue's error code and status travel; its message, which quotes
      // the address it validated, does not.
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'validation_failed',
            statusCode: 400,
          ),
          {'step': 'sign_in_code_request'},
        ),
      ]);
      for (final leaving in robot.analytics.outgoingStrings) {
        expect(leaving, isNot(contains('nobody@example.invalid')));
      }
    });

    testWidgets('treats a code answer without a session as rejected', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionWithheld()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.requestCode();

      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.codeField, findsOneWidget);
      expect(robot.errorText, SignInPage.wrongCodeMessage);
      expect(robot.analytics.events, [
        event('sign_in_code_requested'),
        event('sign_in_code_rejected'),
      ]);
    });

    testWidgets('explains when no more codes can be sent', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [
            authRefused(
              statusCode: 429,
              errorCode: 'over_email_send_rate_limit',
              message: 'email rate limit exceeded',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();

      expect(robot.emailField, findsOneWidget);
      expect(robot.errorText, SignInPage.tooManyCodesMessage);
    });

    testWidgets('tells the user when Supabase is unreachable', (tester) async {
      final supabase = SupabaseStub()..script(otp: [authUnreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();

      expect(robot.errorText, SignInPage.unreachableMessage);
      // No status: the request never got an answer.
      expect(robot.analytics.exceptions, [
        captured(withheld(AuthRetryableFetchException), {
          'step': 'sign_in_code_request',
        }),
      ]);
    });

    testWidgets('rejects a wrong code and lets the user try again', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [codeSent()],
          verify: [
            authRefused(
              statusCode: 403,
              errorCode: 'otp_expired',
              message: 'Token has expired or is invalid',
            ),
            sessionGranted(),
          ],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();
      await robot.requestCode();

      await robot.enterCode('000000');
      await robot.tapSignIn();
      await robot.settle();

      // A refused code is a handled failure like a refused request.
      expect(robot.analytics.exceptions, [
        captured(
          withheld(AuthApiException, code: 'otp_expired', statusCode: 403),
          {'step': 'sign_in_code_verify'},
        ),
      ]);
      expect(robot.codeField, findsOneWidget);
      expect(robot.errorText, SignInPage.wrongCodeMessage);

      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('tells the user to wait when code checks are rate limited', (
      tester,
    ) async {
      // The `token_verifications` bucket, per IP: the code may well be
      // right, so the message must not call it wrong.
      final supabase = SupabaseStub()
        ..script(
          otp: [codeSent()],
          verify: [
            authRefused(
              statusCode: 429,
              errorCode: 'over_request_rate_limit',
              message: 'Request rate limit reached',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.requestCode();

      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.codeField, findsOneWidget);
      expect(robot.errorText, SignInPage.tooManyAttemptsMessage);
    });

    testWidgets('lets the user go back and change the email', (tester) async {
      final supabase = SupabaseStub()..script(otp: [codeSent(), codeSent()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.requestCode('first@example.com');

      await robot.tapChangeEmail();

      expect(robot.emailField, findsOneWidget);
      expect(robot.error, findsNothing);

      await robot.requestCode('second@example.com');

      expect(supabase.bodies('/auth/v1/otp').map((b) => b['email']), [
        'first@example.com',
        'second@example.com',
      ]);
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

      testWidgets('is cleared for an outside address signing in with a code', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(otp: [codeSent()], verify: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.requestCode();
        await robot.enterCode(code);
        await robot.tapSignIn();
        await robot.settle();

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

        tester
            .element(robot.home)
            .read<AuthBloc>()
            .add(const AuthEvent.signOutRequested());
        await robot.settle();

        expect(robot.signIn, findsOneWidget);
        expect(supabase.to('POST /auth/v1/logout'), hasLength(1));
        expect(robot.analytics.events.last, event('signed_out'));
        expect(robot.analytics.resets, 1);
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

        tester
            .element(robot.home)
            .read<AuthBloc>()
            .add(const AuthEvent.signOutRequested());
        await robot.settle();

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

      expect(launcher.launched, [privacyNoticeUrl]);
    });

    testWidgets('renders nothing once signed in; the root swaps the screen', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      await supabase.signedIn();
      final spy = AnalyticsSpy();

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => AuthBloc(
            supabase: supabase.supabase,
            analytics: spy.authAnalytics,
            errors: spy.errorReporter,
            providers: ProviderSignIn(google: SignInRobot.googleClients),
          ),
          child: const MaterialApp(home: SignInPage()),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    group('a review account', () {
      const address = 'google-play-review@getemotely.com';
      const password = 'correct horse battery staple';
      const tokenGrant = 'POST /auth/v1/token';
      final wrongPassword = authRefused(
        statusCode: 400,
        errorCode: 'invalid_credentials',
        message: 'Invalid login credentials',
      );

      testWidgets('signs in with a password and is never sent a code', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        // However the address is typed: the check trims and ignores case
        // (Supabase matches the address case-insensitively too).
        const typed = 'Google-Play-Review@getemotely.com';
        await robot.submitEmail('  $typed ');

        expect(supabase.to('POST /auth/v1/otp'), isEmpty);
        expect(robot.codeField, findsNothing);
        expect(robot.passwordField, findsOneWidget);
        expect(robot.passwordObscured, isTrue);
        expect(find.textContaining(typed), findsOneWidget);
        expect(robot.canSubmitPassword, isFalse);

        await robot.enterPassword(password);
        expect(robot.canSubmitPassword, isTrue);
        await robot.tapPasswordSignIn();
        await robot.settle();

        final grant = supabase.to(tokenGrant).single;
        expect(grant.query['grant_type'], 'password');
        expect((grant.body! as Map)['email'], typed);
        expect((grant.body! as Map)['password'], password);
        expect(supabase.to('POST /auth/v1/otp'), isEmpty);
        expect(supabase.to('POST /auth/v1/signup'), isEmpty);
        expect(robot.home, findsOneWidget);
        expect(robot.signIn, findsNothing);
        // No code was requested.
        expect(
          robot.analytics.events.first,
          event('signed_in', {'method': 'password'}),
        );
        expect(
          robot.analytics.events.map((captured) => captured['event']),
          isNot(contains(startsWith('sign_in_code'))),
        );
        expect(robot.analytics.identified, [SupabaseStub.userId]);
      });

      testWidgets('is the only kind of address that skips the code', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(otp: [codeSent()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        // One character off a review address is an ordinary user.
        await robot.submitEmail('google-play-review@getemotely.co');

        expect(
          supabase.bodies('/auth/v1/otp').single['email'],
          ['google-play-review@getemotely.co'].single,
        );
        expect(supabase.to(tokenGrant), isEmpty);
        expect(robot.codeField, findsOneWidget);
        expect(robot.passwordField, findsNothing);
      });

      testWidgets('is told when the password is not accepted and may retry', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(password: [wrongPassword, sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();
        await robot.submitEmail(address);

        await robot.enterPassword('wrong');
        await robot.tapPasswordSignIn();
        await robot.settle();

        expect(robot.passwordField, findsOneWidget);
        expect(robot.errorText, SignInPage.wrongPasswordMessage);
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

        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();
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
        await robot.submitEmail(address);

        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();
        await robot.settle();

        expect(robot.passwordField, findsOneWidget);
        expect(robot.errorText, SignInPage.tooManyAttemptsMessage);
        expect(robot.analytics.exceptions, [
          captured(
            withheld(
              AuthApiException,
              code: 'over_request_rate_limit',
              statusCode: 429,
            ),
            {'step': 'sign_in_password'},
          ),
        ]);
      });

      testWidgets('submits the password from the keyboard', (tester) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final agent = AgentStub()..script([unreachable()]);
        final robot = SignInRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();
        await robot.submitEmail(address);

        // An empty field submits nothing.
        await robot.submitPasswordFromKeyboard();
        expect(supabase.to(tokenGrant), isEmpty);
        expect(robot.passwordField, findsOneWidget);

        await robot.enterPassword(password);
        await robot.submitPasswordFromKeyboard();
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
        await robot.submitEmail(address);

        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();

        expect(robot.busy, findsOneWidget);
        expect(robot.submitPassword, findsNothing);
        expect(tester.widget<TextField>(robot.passwordField).enabled, isFalse);

        await robot.settle();

        expect(robot.home, findsOneWidget);
      });

      testWidgets('can go back to the email step', (tester) async {
        final supabase = SupabaseStub()
          ..script(password: [wrongPassword], otp: [codeSent()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();
        await robot.submitEmail(address);
        await robot.enterPassword('wrong');
        await robot.tapPasswordSignIn();
        await robot.settle();
        expect(robot.error, findsOneWidget);

        await robot.tapChangeEmail();

        expect(robot.emailField, findsOneWidget);
        expect(robot.passwordField, findsNothing);
        expect(robot.error, findsNothing);

        await robot.requestCode();

        expect(robot.codeField, findsOneWidget);
        expect(
          supabase.bodies('/auth/v1/otp').single['email'],
          SupabaseStub.email,
        );
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
        await robot.submitEmail(address);

        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();
        await robot.settle();

        expect(robot.passwordField, findsOneWidget);
        expect(robot.errorText, SignInPage.wrongPasswordMessage);
        expect(robot.analytics.events, [event('sign_in_password_failed')]);
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
        await robot.submitEmail(address);

        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();
        await robot.settle();

        expect(robot.passwordField, findsOneWidget);
        expect(robot.errorText, SignInPage.unreachableMessage);
        expect(robot.analytics.exceptions, [
          captured(withheld(AuthRetryableFetchException), {
            'step': 'sign_in_password',
          }),
        ]);
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
        await robot.submitEmail(address);
        await robot.enterPassword(password);
        await robot.tapPasswordSignIn();

        // The whole app is torn down (bloc closed) before Supabase answers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
        expect(supabase.to(tokenGrant), hasLength(1));
      });

      testWidgets('meets accessibility guidelines on the password step', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [wrongPassword]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );

        // With the error showing: everything the step can render at once.
        await tester.expectMeetsAccessibilityGuidelines(
          robot.app,
          prepare: (tester) async {
            await robot.submitEmail(address);
            await robot.enterPassword('wrong');
            await robot.tapPasswordSignIn();
          },
        );
      });
    });

    group('an account the app names for a password', () {
      const smoke = 'smoke@example.com';

      testWidgets('signs in with a password like a review account', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(password: [sessionGranted()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
          passwordAccounts: const {smoke},
        );
        await robot.launch();

        // Trimmed and case-folded, like the review accounts.
        await robot.submitEmail('  Smoke@Example.com ');

        expect(supabase.to('POST /auth/v1/otp'), isEmpty);
        expect(robot.passwordField, findsOneWidget);

        await robot.enterPassword('made-up password');
        await robot.tapPasswordSignIn();
        await robot.settle();

        expect(robot.home, findsOneWidget);
      });

      testWidgets('is sent a code when the app does not name it', (
        tester,
      ) async {
        final supabase = SupabaseStub()..script(otp: [codeSent()]);
        final robot = SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub(),
        );
        await robot.launch();

        await robot.submitEmail(smoke);

        expect(supabase.bodies('/auth/v1/otp').single['email'], smoke);
        expect(robot.codeField, findsOneWidget);
        expect(robot.passwordField, findsNothing);
      });
    });

    testWidgets('meets accessibility guidelines on both steps', (tester) async {
      final supabase = SupabaseStub()..script(otp: [codeSent()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());

      await tester.expectMeetsAccessibilityGuidelines(robot.app);
      // A second composition in one test starts from an empty container.
      await GetIt.I.reset();
      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => robot.requestCode(),
      );
    });
  });
}
