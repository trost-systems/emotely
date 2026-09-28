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

      expect(robot.headingText, robot.strings.signInTitle);
      expect(find.text(robot.strings.signUpBody), findsNothing);
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

      robot.expectError(
        SignInProblem.noAccount,
        robot.strings.noAccountMessage,
      );
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
    expect(find.text(robot.strings.appleButton), findsOneWidget);
    expect(find.text(robot.strings.orWithEmail), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('in German', () {
    const german = Locale('de');
    final strings = lookupAuthLocalizations(german);

    testWidgets('greets, offers every way in and words each field', (
      tester,
    ) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: SignInMode.signUp,
        name: 'Peter',
        locale: german,
      );
      await robot.launch();

      expect(robot.headingText, 'Fast geschafft, Peter');
      expect(robot.headingText, strings.signUpTitleWithName('Peter'));
      for (final shown in [
        strings.signUpBody,
        strings.appleButton,
        strings.orWithEmail,
        strings.emailLabel,
        strings.emailHint,
        strings.sendCodeButton,
        strings.privacyNoticeButton,
      ]) {
        expect(find.text(shown), findsOneWidget, reason: shown);
      }
      expect(find.bySemanticsLabel(strings.googleButton), findsOneWidget);
      expect(find.bySemanticsLabel(strings.appleButton), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('asks for the code, and says why it was refused', (
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
          ],
        );
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        locale: german,
      );
      await robot.launch();
      expect(robot.headingText, strings.signInTitle);

      await robot.requestCode();
      expect(
        find.text(strings.codeSentMessage(SupabaseStub.email)),
        findsOneWidget,
      );
      expect(find.text(strings.codeLabel), findsOneWidget);
      expect(find.text(strings.signInButton), findsOneWidget);
      expect(find.text(strings.changeEmailButton), findsOneWidget);

      await robot.enterCode('000000');
      await robot.tapSignIn();
      await robot.settle();

      robot.expectError(SignInProblem.wrongCode, strings.wrongCodeMessage);
    });

    testWidgets('asks a review account for its password', (tester) async {
      const address = 'app-store-review@getemotely.com';
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        locale: german,
      );
      await robot.launch();

      await robot.submitEmail(address);

      expect(find.text(strings.passwordPrompt(address)), findsOneWidget);
      expect(find.text(strings.passwordLabel), findsOneWidget);
    });

    testWidgets('tags the way in used last', (tester) async {
      final semantics = tester.ensureSemantics();
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        locale: german,
      );
      await robot.keep(SignInOption.google);
      await robot.launch();

      expect(find.text('Zuletzt genutzt'), findsOneWidget);
      expect(
        find.bySemanticsLabel(strings.lastUsedButton(strings.googleButton)),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        mode: SignInMode.signUp,
        name: 'Peter',
        locale: german,
      );

      await tester.expectMeetsAccessibilityGuidelines(robot.app);
    });
  });

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
