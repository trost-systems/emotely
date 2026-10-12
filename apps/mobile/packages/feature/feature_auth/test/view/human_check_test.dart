import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// Supabase Auth refuses a code request and a password sign-in without a
/// Cloudflare Turnstile token once the hosted project enforces its captcha
/// (#94). The screen fetches one for every such request, and says so when
/// the check, or GoTrue's verdict on it, fails.
void main() {
  group(SignInPage, () {
    const reviewAccount = 'app-store-review@getemotely.com';
    final captchaRefused = authRefused(
      statusCode: 400,
      errorCode: 'captcha_failed',
      message:
          'captcha protection: request disallowed (invalid-input-response)',
    );

    testWidgets('asks for a code with a fresh token each time', (tester) async {
      final supabase = SupabaseStub()..script(otp: [codeSent(), codeSent()]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.requestCode();
      await robot.tapChangeEmail();
      await robot.requestCode();

      expect(
        supabase
            .bodies('/auth/v1/otp')
            .map((body) => body['gotrue_meta_security']),
        [HumanCheckStub.security(1), HumanCheckStub.security(2)],
      );
    });

    testWidgets('checks a review account password with a token', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(password: [sessionGranted()]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.submitEmail(reviewAccount);
      await robot.enterPassword('correct horse battery staple');
      await robot.tapPasswordSignIn();
      await robot.settle();

      final grant = supabase.to('POST /auth/v1/token').single;
      expect(
        (grant.body! as Map)['gotrue_meta_security'],
        HumanCheckStub.security(1),
      );
      expect(robot.home, findsOneWidget);
    });

    testWidgets('a failed check sends no code and says what happened', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: agent,
        humanCheck: HumanCheckStub()..fails = true,
      );
      await robot.launch();

      await robot.requestCode();

      expect(supabase.to('POST /auth/v1/otp'), isEmpty);
      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
      expect(robot.emailField, findsOneWidget);
      expect(robot.canSendCode, isTrue);
    });

    testWidgets("GoTrue's refusal of the token reads the same", (tester) async {
      final supabase = SupabaseStub()..script(otp: [captchaRefused]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.requestCode();

      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
    });

    testWidgets('a failed check never calls a password wrong', (tester) async {
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

      await robot.submitEmail(reviewAccount);
      await robot.enterPassword('correct horse battery staple');
      await robot.tapPasswordSignIn();
      await robot.settle();

      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );

      humanCheck.fails = true;
      await robot.tapPasswordSignIn();
      await robot.settle();

      // The second try never reached GoTrue.
      expect(supabase.to('POST /auth/v1/token'), hasLength(1));
      robot.expectError(
        SignInProblem.humanCheckFailed,
        robot.strings.humanCheckFailedMessage,
      );
      expect(robot.passwordField, findsOneWidget);
    });
  });
}
