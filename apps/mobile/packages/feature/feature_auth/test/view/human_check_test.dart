import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// Supabase Auth refuses a sign-up, a password sign-in, a reset and a
/// resent code without a Cloudflare Turnstile token once the hosted project
/// enforces its captcha (#94). The screen fetches one for every such
/// request, and says so when the check, or GoTrue's verdict on it, fails.
/// Checking a code needs none.
void main() {
  group(SignInPage, () {
    final captchaRefused = authRefused(
      statusCode: 400,
      errorCode: 'captcha_failed',
      message:
          'captcha protection: request disallowed (invalid-input-response)',
    );

    Object? security(Map<String, dynamic> body) => body['gotrue_meta_security'];

    testWidgets('signs in with a fresh token each time', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          password: [
            authRefused(
              statusCode: 400,
              errorCode: 'invalid_credentials',
              message: 'Invalid login credentials',
            ),
            sessionGranted(),
          ],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.submitCredentials(password: 'wrong');
      await robot.enterPassword(goodPassword);
      await robot.tapSubmit();
      await robot.settle();

      expect(robot.posted('token').map(security), [
        HumanCheckStub.security(1),
        HumanCheckStub.security(2),
      ]);
      expect(robot.home, findsOneWidget);
    });

    testWidgets('creates an account and resends its code with a token each, '
        'and confirms it with none', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          signUp: [accountCreated()],
          resend: [codeSent()],
          verify: [sessionGranted()],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: agent,
        mode: SignInMode.signUp,
      );
      await robot.launch();

      await robot.submitCredentials();
      await robot.tapResendCode();
      await robot.settle();
      await robot.confirmWith();

      expect(
        security(robot.posted('signup').single),
        HumanCheckStub.security(1),
      );
      expect(
        security(robot.posted('resend').single),
        HumanCheckStub.security(2),
      );
      expect(security(robot.posted('verify').single), {'captcha_token': null});
      expect(robot.home, findsOneWidget);
    });

    testWidgets('asks for a reset code with a token', (tester) async {
      final supabase = SupabaseStub()..script(recover: [codeSent()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestReset();

      expect(
        security(robot.posted('recover').single),
        HumanCheckStub.security(1),
      );
    });

    testWidgets('a failed check sends nothing and says what happened', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        mode: SignInMode.signUp,
        humanCheck: HumanCheckStub()..fails = true,
      );
      await robot.launch();

      await robot.submitCredentials();

      expect(supabase.to('POST /auth/v1/signup'), isEmpty);
      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
      expect(robot.emailField, findsOneWidget);
      expect(robot.canSubmit, isTrue);
    });

    testWidgets("GoTrue's refusal of the token never calls a password wrong", (
      tester,
    ) async {
      final humanCheck = HumanCheckStub();
      final supabase = SupabaseStub()..script(password: [captchaRefused]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: agent,
        humanCheck: humanCheck,
      );
      await robot.launch();

      await robot.submitCredentials();

      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );

      humanCheck.fails = true;
      await robot.tapSubmit();
      await robot.settle();

      // The second try never reached GoTrue.
      expect(supabase.to('POST /auth/v1/token'), hasLength(1));
      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
      expect(robot.passwordField, findsOneWidget);
    });

    testWidgets('a failed check for a new code stays on the code step', (
      tester,
    ) async {
      final humanCheck = HumanCheckStub();
      final supabase = SupabaseStub()..script(recover: [codeSent()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        humanCheck: humanCheck,
      );
      await robot.launch();
      await robot.requestReset();

      humanCheck.fails = true;
      await robot.tapResendCode();
      await robot.settle();

      expect(robot.codeField, findsOneWidget);
      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
      expect(supabase.to('POST /auth/v1/recover'), hasLength(1));
    });
  });
}
