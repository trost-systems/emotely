import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/view/password_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthException, AuthWeakPasswordException;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

final alreadyRegistered = authRefused(
  statusCode: 422,
  errorCode: 'user_already_exists',
  message: 'User already registered',
);

void main() {
  group('A new account', () {
    SignInRobot robotFor(WidgetTester tester, SupabaseStub supabase) =>
        SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub()..script([unreachable()]),
          mode: SignInMode.signUp,
          name: 'Peter',
        );

    testWidgets('is made with an email and a password, confirmed by the code '
        'mailed to it, then opens the journal', (tester) async {
      final supabase = SupabaseStub()
        ..script(signUp: [accountCreated()], verify: [sessionGranted()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      // The one rule: ten characters.
      await robot.enterEmail(SupabaseStub.email);
      await robot.enterPassword(shortPassword);
      expect(robot.canSubmit, isFalse);
      expect(
        find.text(robot.strings.passwordRule(minimumPasswordLength)),
        findsOneWidget,
      );

      await robot.submitCredentials();

      final signUp = robot.posted('signup').single;
      expect(signUp['email'], SupabaseStub.email);
      expect(signUp['password'], goodPassword);
      expect(robot.state, isA<AuthCodeSent>());
      expect(
        find.text(robot.strings.confirmationSentMessage(SupabaseStub.email)),
        findsOneWidget,
      );
      expect(robot.canConfirm, isFalse);

      await robot.enterCode('12');
      expect(robot.canConfirm, isFalse);
      await robot.confirmWith();

      final verify = robot.posted('verify').single;
      expect(verify['email'], SupabaseStub.email);
      expect(verify['token'], code);
      expect(verify['type'], 'signup');
      expect(robot.home, findsOneWidget);
      expect(robot.analytics.events, [
        event('sign_up_requested'),
        event('signed_in', {'method': 'password'}),
      ]);
      expect(await robot.kept(), SignInOption.email);
    });

    group('keeps the password typed last', () {
      const first = 'the first long password';
      const last = 'the last long password';
      const passwordChange = 'PUT /auth/v1/user';

      // GoTrue keeps an unconfirmed account's first password when the
      // address signs up again; the app sets the one typed last once the
      // confirmation code has opened the account.
      Future<SignInRobot> signUpTwice(
        WidgetTester tester,
        SupabaseStub supabase,
      ) async {
        final robot = robotFor(tester, supabase);
        await robot.launch();
        await robot.submitCredentials(password: first);
        await robot.tapChangeEmail();
        await robot.submitCredentials(password: last);
        await robot.confirmWith();
        return robot;
      }

      testWidgets('once the code opens the account', (tester) async {
        final supabase = SupabaseStub()
          ..script(
            signUp: [accountCreated(), accountCreated()],
            verify: [sessionGranted()],
          );

        final robot = await signUpTwice(tester, supabase);

        expect(
          robot.posted('user').where((body) => body.containsKey('password')),
          [
            {'password': last},
          ],
        );
        expect(robot.home, findsOneWidget);
      });

      testWidgets('and lets in an account that has it already', (tester) async {
        // The ordinary case: GoTrue answers that nothing changed.
        final supabase = SupabaseStub()
          ..script(
            signUp: [accountCreated(), accountCreated()],
            verify: [sessionGranted()],
          )
          ..rest(passwordChange, [
            authRefused(
              statusCode: 422,
              errorCode: 'same_password',
              message: 'New password should be different from the old one.',
            ),
          ]);

        final robot = await signUpTwice(tester, supabase);

        expect(robot.home, findsOneWidget);
        expect(robot.analytics.exceptions, isEmpty);
      });

      testWidgets('or asks for it again when it could not be set', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(
            signUp: [accountCreated(), accountCreated()],
            verify: [sessionGranted()],
          )
          ..rest(passwordChange, [authUnreachable()]);

        final robot = await signUpTwice(tester, supabase);

        expect(robot.signIn, findsOneWidget);
        expect(
          find.text(robot.strings.newPasswordPrompt(SupabaseStub.email)),
          findsOneWidget,
        );
        robot.expectError(
          SignInProblem.unreachable,
          robot.strings.unreachableMessage,
        );
        // Not a failed reset: no one asked for one.
        expect(
          robot.analytics.events.map((captured) => captured['event']),
          isNot(contains('password_reset_failed')),
        );
      });
    });

    testWidgets('signs in at once when the project confirms no addresses', (
      tester,
    ) async {
      // With `enable_confirmations` off, GoTrue answers with a session.
      final supabase = SupabaseStub()..script(signUp: [sessionGranted()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.submitCredentials();

      expect(robot.home, findsOneWidget);
      expect(supabase.to('POST /auth/v1/verify'), isEmpty);
    });

    testWidgets('shows progress while the account and the code are checked', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [delayedAuth(accountCreated())],
          verify: [delayedAuth(sessionGranted())],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.enterEmail(SupabaseStub.email);
      await robot.enterPassword(goodPassword);
      await robot.tapSubmit();
      expect(robot.busy, findsOneWidget);
      expect(robot.submit, findsNothing);
      await robot.settle();

      await robot.enterCode(code);
      await robot.tapConfirm();
      expect(robot.busy, findsOneWidget);
      expect(robot.confirm, findsNothing);
      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('rejects a wrong code and takes the right one', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [accountCreated()],
          verify: [
            authRefused(
              statusCode: 403,
              errorCode: 'otp_expired',
              message: 'Token has expired or is invalid',
            ),
            sessionGranted(),
          ],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.submitCredentials();

      await robot.confirmWith('000000');

      robot.expectError(
        SignInProblem.wrongCode,
        robot.strings.wrongCodeMessage,
      );
      expect(robot.analytics.exceptions, [
        captured(
          withheld(AuthApiException, code: 'otp_expired', statusCode: 403),
          {'step': 'auth_code_verify'},
        ),
      ]);
      expect(robot.analytics.events.last, event('sign_up_code_rejected'));

      await robot.confirmWith();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('treats a code answer without a session as rejected', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(signUp: [accountCreated()], verify: [sessionWithheld()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.submitCredentials();

      await robot.confirmWith();

      robot.expectError(
        SignInProblem.wrongCode,
        robot.strings.wrongCodeMessage,
      );
      expect(robot.analytics.exceptions, [
        captured(withheld(AuthException), {'step': 'auth_code_verify'}),
      ]);
    });

    testWidgets('mails a new code on request', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [accountCreated()],
          resend: [
            codeSent(),
            authRefused(
              statusCode: 429,
              errorCode: 'over_email_send_rate_limit',
              message: 'email rate limit exceeded',
            ),
          ],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.submitCredentials();
      expect(robot.codeResent, findsNothing);

      await robot.tapResendCode();
      await robot.settle();

      expect(robot.posted('resend').single['type'], 'signup');
      expect(robot.codeResent, findsOneWidget);

      await robot.tapResendCode();
      await robot.settle();

      expect(robot.codeField, findsOneWidget);
      expect(robot.codeResent, findsNothing);
      robot.expectError(
        SignInProblem.tooManyCodes,
        robot.strings.tooManyCodesMessage,
      );
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'over_email_send_rate_limit',
            statusCode: 429,
          ),
          {'step': 'auth_code_send'},
        ),
      ]);
    });

    testWidgets('goes back to the email, keeping it, for another address', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(signUp: [accountCreated(), accountCreated()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.submitCredentials(email: 'first@example.com');

      await robot.tapChangeEmail();

      expect(robot.codeField, findsNothing);
      expect(robot.error, findsNothing);
      expect(
        tester.widget<TextField>(robot.emailField).controller!.text,
        'first@example.com',
      );

      await robot.submitCredentials(email: 'second@example.com');

      expect(robot.posted('signup').map((body) => body['email']), [
        'first@example.com',
        'second@example.com',
      ]);
    });

    testWidgets('for an address with an account signs into it with the '
        'password typed', (tester) async {
      final supabase = SupabaseStub()
        ..script(signUp: [alreadyRegistered], password: [sessionGranted()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.submitCredentials();

      expect(
        (supabase.to('POST /auth/v1/token').single.body! as Map)['password'],
        goodPassword,
      );
      expect(robot.home, findsOneWidget);
      // Not a failed sign-up: the person is in.
      expect(robot.analytics.exceptions, isEmpty);
    });

    testWidgets('for an address with an account says so when the password '
        'is not its', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [alreadyRegistered],
          password: [
            authRefused(
              statusCode: 400,
              errorCode: 'invalid_credentials',
              message: 'Invalid login credentials',
            ),
          ],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.submitCredentials();

      robot.expectError(
        SignInProblem.accountExists,
        robot.strings.accountExistsMessage,
      );
      expect(robot.canReset, isTrue);
    });

    testWidgets('explains a password the server finds too weak', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(signUp: [passwordTooWeak()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.submitCredentials();

      robot.expectError(
        SignInProblem.weakPassword,
        robot.strings.weakPasswordMessage(minimumPasswordLength),
      );
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthWeakPasswordException,
            code: 'weak_password',
            statusCode: 422,
          ),
          {'step': 'sign_up'},
        ),
      ]);
      expect(robot.analytics.events.last, event('sign_up_failed'));
    });

    testWidgets('explains an address Supabase refuses', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [
            authRefused(
              statusCode: 400,
              errorCode: 'email_address_invalid',
              message: 'Email address "nobody@example.invalid" is invalid',
            ),
          ],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.submitCredentials(email: 'nobody@example.invalid');

      expect(robot.emailField, findsOneWidget);
      robot.expectError(
        SignInProblem.couldNotSend,
        robot.strings.couldNotSendMessage,
      );
      // GoTrue's message quotes the address; it never leaves.
      for (final leaving in robot.analytics.outgoingStrings) {
        expect(leaving, isNot(contains('nobody@example.invalid')));
      }
    });

    testWidgets('meets accessibility guidelines at the code step', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(signUp: [accountCreated()]);
      final robot = robotFor(tester, supabase);

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => robot.submitCredentials(),
      );
    });
  });
}
