import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

const passwordChange = 'PUT /auth/v1/user';

void main() {
  group('A forgotten password', () {
    SignInRobot robotFor(WidgetTester tester, SupabaseStub supabase) =>
        SignInRobot(
          tester,
          supabase: supabase,
          agent: AgentStub()..script([unreachable()]),
        );

    testWidgets('is reset with the code mailed to the address and a new '
        'password, which signs in', (tester) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.requestReset();

      expect(robot.posted('recover').single['email'], SupabaseStub.email);
      expect(
        find.text(robot.strings.resetSentMessage(SupabaseStub.email)),
        findsOneWidget,
      );
      expect(robot.canSavePassword, isFalse);

      // The code alone is not enough, nor is a short password.
      await robot.enterCode(code);
      await robot.enterNewPassword(shortPassword);
      expect(robot.canSavePassword, isFalse);
      await robot.submitFromKeyboard(robot.newPasswordField);
      expect(supabase.to('POST /auth/v1/verify'), isEmpty);

      // The keyboard's "done" saves it, like the button.
      await robot.enterNewPassword(goodPassword);
      await robot.submitFromKeyboard(robot.newPasswordField);
      await robot.settle();

      final verify = robot.posted('verify').single;
      expect(verify['token'], code);
      expect(verify['type'], 'recovery');
      expect(robot.posted('user').first, {'password': goodPassword});
      expect(robot.home, findsOneWidget);
      expect(robot.analytics.events, [
        event('password_reset_requested'),
        event('signed_in', {'method': 'password'}),
      ]);
      expect(robot.analytics.identified, [SupabaseStub.userId]);
    });

    testWidgets('keeps the user on the screen until the password is saved', (
      tester,
    ) async {
      // The recovery code signs the account in before the new password is
      // set, and the SDK says so on its stream; the screen must not let go.
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()])
        ..rest(passwordChange, [delayedAuth(userUpdated())]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.enterCode(code);
      await robot.enterNewPassword(goodPassword);
      await robot.tapSavePassword();
      await tester.pump(const Duration(milliseconds: 500));

      expect(robot.signIn, findsOneWidget);
      expect(robot.busy, findsOneWidget);
      expect(robot.state, isA<AuthCheckingCode>());

      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('gives an account without a password its first one', (
      tester,
    ) async {
      // Made with a sign-in code before #187: the password grant refuses it
      // like a wrong password, and "Forgot password?" is the way in.
      final supabase = SupabaseStub()
        ..script(
          password: [
            authRefused(
              statusCode: 400,
              errorCode: 'invalid_credentials',
              message: 'Invalid login credentials',
            ),
          ],
          recover: [codeSent()],
          verify: [sessionGranted(provider: 'email')],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.submitCredentials();
      expect(robot.problem, SignInProblem.wrongPassword);

      // The address typed stays; "Forgot password?" takes it.
      await robot.tapForgotPassword();
      await robot.settle();
      await robot.resetWith();

      expect(robot.posted('recover').single['email'], SupabaseStub.email);
      expect(robot.home, findsOneWidget);
    });

    testWidgets('lets in a user who chose the password they had', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()])
        ..rest(passwordChange, [
          authRefused(
            statusCode: 422,
            errorCode: 'same_password',
            message: 'New password should be different from the old password.',
          ),
        ]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.resetWith();

      expect(robot.home, findsOneWidget);
      expect(robot.analytics.exceptions, isEmpty);
    });

    testWidgets('asks for the new password again when it could not be saved', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()])
        ..rest(passwordChange, [
          authUnreachable(),
          passwordTooWeak(),
          delayedAuth(userUpdated()),
        ]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.resetWith();

      // Signed in by the code, but not past the screen.
      expect(robot.signIn, findsOneWidget);
      expect(robot.codeField, findsNothing);
      expect(
        find.text(robot.strings.newPasswordPrompt(SupabaseStub.email)),
        findsOneWidget,
      );
      robot.expectError(
        SignInProblem.unreachable,
        robot.strings.unreachableMessage,
      );
      expect(robot.analytics.exceptions, [
        captured(withheld(AuthRetryableFetchException), {
          'step': 'password_save',
        }),
      ]);
      expect(robot.analytics.events.last, event('password_reset_failed'));

      await robot.enterNewPassword(shortPassword);
      expect(robot.canSavePassword, isFalse);
      await robot.enterNewPassword(goodPassword);
      await robot.tapSavePassword();
      await robot.settle();

      robot.expectError(
        SignInProblem.weakPassword,
        robot.strings.weakPasswordMessage(10),
      );

      await robot.submitFromKeyboard(robot.newPasswordField);
      expect(robot.busy, findsOneWidget);
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(
        robot.posted('user').where((body) => body.containsKey('password')),
        hasLength(3),
      );
    });

    testWidgets('names any other failure to save as such', (tester) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()])
        ..rest(passwordChange, [
          authRefused(
            statusCode: 400,
            errorCode: 'unexpected_failure',
            message: 'Unexpected failure',
          ),
        ]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.resetWith();

      robot.expectError(
        SignInProblem.passwordNotSaved,
        robot.strings.passwordNotSavedMessage,
      );
    });

    testWidgets('rejects a wrong code, and saves nothing', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          recover: [codeSent()],
          verify: [
            authRefused(
              statusCode: 403,
              errorCode: 'otp_expired',
              message: 'Token has expired or is invalid',
            ),
          ],
        );
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.resetWith(typed: '000000');

      expect(robot.codeField, findsOneWidget);
      robot.expectError(
        SignInProblem.wrongCode,
        robot.strings.wrongCodeMessage,
      );
      expect(supabase.to(passwordChange), isEmpty);
      expect(
        robot.analytics.events.last,
        event('password_reset_code_rejected'),
      );
      expect(robot.analytics.exceptions, [
        captured(
          withheld(AuthApiException, code: 'otp_expired', statusCode: 403),
          {'step': 'auth_code_verify'},
        ),
      ]);
    });

    testWidgets('mails a new reset code on request', (tester) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent(), codeSent()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();
      await robot.requestReset();

      await robot.tapResendCode();
      await robot.settle();

      expect(robot.posted('recover'), hasLength(2));
      expect(robot.codeResent, findsOneWidget);
    });

    testWidgets('explains when no code could be sent', (tester) async {
      final supabase = SupabaseStub()..script(recover: [authUnreachable()]);
      final robot = robotFor(tester, supabase);
      await robot.launch();

      await robot.requestReset();

      expect(robot.emailField, findsOneWidget);
      robot.expectError(
        SignInProblem.unreachable,
        robot.strings.unreachableMessage,
      );
      expect(robot.analytics.events, [
        event('password_reset_requested'),
        event('password_reset_failed'),
      ]);
      expect(robot.analytics.exceptions, [
        captured(withheld(AuthRetryableFetchException), {
          'step': 'auth_code_send',
        }),
      ]);
    });

    testWidgets('needs an address that could be one', (tester) async {
      final robot = robotFor(tester, SupabaseStub());
      await robot.launch();

      await robot.enterEmail('peter');
      expect(robot.canReset, isFalse);
      await robot.enterEmail('peter@example.com');
      expect(robot.canReset, isTrue);
    });

    testWidgets('meets accessibility guidelines at the reset step', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(recover: [codeSent()]);
      final robot = robotFor(tester, supabase);

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => robot.requestReset(),
      );
    });
  });
}
