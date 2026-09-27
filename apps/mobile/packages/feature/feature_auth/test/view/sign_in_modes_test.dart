import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

void main() {
  group('sign-up', () {
    testWidgets('greets by the name onboarding asked for, and says why an '
        'account', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: SignInMode.signUp,
        name: 'Peter',
      );
      await robot.launch();

      expect(robot.headingText, 'Almost there, Peter');
      expect(find.text(SignInPage.signUpBody), findsOneWidget);
      expect(
        tester.widget<Text>(robot.heading).style?.fontStyle,
        FontStyle.normal,
      );
    });

    testWidgets('still reads well without a name', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: SignInMode.signUp,
      );
      await robot.launch();

      expect(robot.headingText, 'Almost there');
    });

    testWidgets('asks for a code that creates the account when there is '
        'none', (tester) async {
      final supabase = SupabaseStub()..script(otp: [codeSent()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        mode: SignInMode.signUp,
        name: 'Peter',
      );
      await robot.launch();
      await robot.requestCode();

      expect(supabase.bodies('/auth/v1/otp').single['create_user'], isTrue);
      expect(robot.codeField, findsOneWidget);
    });

    testWidgets('goes back to the greeting, by arrow and by gesture', (
      tester,
    ) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: SignInMode.signUp,
      );
      await robot.launch();

      await tester.tap(robot.back);
      await tester.binding.handlePopRoute();
      await robot.settle();

      expect(robot.navigator.left, [SignInMode.signUp, SignInMode.signUp]);
      expect(robot.signIn, findsOneWidget);
    });
  });

  group('sign-in', () {
    testWidgets('welcomes back', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        name: 'Peter',
      );
      await robot.launch();

      expect(robot.headingText, 'Welcome back');
      expect(find.text(SignInPage.signUpBody), findsNothing);
    });

    testWidgets('asks for a code that never creates an account', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(otp: [codeSent()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.requestCode();

      expect(supabase.bodies('/auth/v1/otp').single['create_user'], isFalse);
    });

    testWidgets('tells an address without an account to get started', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [
            // What GoTrue answers a code asked for with create_user false
            // for an address it does not know.
            authRefused(
              statusCode: 422,
              errorCode: 'otp_disabled',
              message: 'Signups not allowed for otp',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.requestCode();

      expect(robot.errorText, SignInPage.noAccountMessage);
      expect(robot.emailField, findsOneWidget);
    });

    testWidgets('goes back to Welcome', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
      );
      await robot.launch();

      await tester.tap(robot.back);
      await robot.settle();

      expect(robot.navigator.left, [SignInMode.signIn]);
    });
  });

  testWidgets('offers Apple, then Google, then the email', (tester) async {
    final robot = SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
      mode: SignInMode.signUp,
    );
    await robot.launch();

    final apple = tester.getTopLeft(robot.appleButton).dy;
    final google = tester.getTopLeft(robot.googleButton).dy;
    final email = tester.getTopLeft(robot.emailField).dy;
    expect(apple, lessThan(google));
    expect(google, lessThan(email));
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('or with your email'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('meets accessibility guidelines in both modes', (tester) async {
    for (final mode in SignInMode.values) {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: mode,
        name: 'Peter',
      );
      await tester.expectMeetsAccessibilityGuidelines(robot.app);
      await GetIt.I.reset();
    }
  });
}
