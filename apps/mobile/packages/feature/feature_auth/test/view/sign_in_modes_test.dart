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

      expect(robot.headingText, robot.strings.signUpTitleWithName('Peter'));
      expect(find.text(robot.strings.signUpBody), findsOneWidget);
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

      expect(robot.headingText, robot.strings.signUpTitle);
    });

    testWidgets('creates an account with the email and password', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(signUp: [accountCreated()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        mode: SignInMode.signUp,
        name: 'Peter',
      );
      await robot.launch();

      expect(
        tester
            .widget<Text>(
              find.descendant(of: robot.submit, matching: find.byType(Text)),
            )
            .data,
        robot.strings.createAccountButton,
      );
      await robot.submitCredentials();

      expect(supabase.to('POST /auth/v1/signup'), hasLength(1));
      expect(supabase.to('POST /auth/v1/token'), isEmpty);
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

      expect(robot.headingText, robot.strings.signInTitle);
      expect(find.text(robot.strings.signUpBody), findsNothing);
    });

    testWidgets('signs in, and never creates an account', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          password: [
            authRefused(
              statusCode: 400,
              errorCode: 'invalid_credentials',
              message: 'Invalid login credentials',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      expect(
        tester
            .widget<Text>(
              find.descendant(of: robot.submit, matching: find.byType(Text)),
            )
            .data,
        robot.strings.signInButton,
      );
      // Its password is whatever the account has: no rule is shown.
      expect(find.text(robot.strings.passwordRule(10)), findsNothing);
      await robot.submitCredentials();

      expect(supabase.to('POST /auth/v1/signup'), isEmpty);
      robot.expectError(
        SignInProblem.wrongPassword,
        robot.strings.wrongPasswordMessage,
      );
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
    expect(find.text(robot.strings.appleButton), findsOneWidget);
    expect(find.text(robot.strings.orWithEmail), findsOneWidget);
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
