import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInExceptionCode;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// Apple's button is offered on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group(LastUsedTag, () {
    SignInRobot robotFor(WidgetTester tester, {SupabaseStub? supabase}) =>
        SignInRobot(
          tester,
          supabase: supabase ?? SupabaseStub(),
          agent: AgentStub(),
        );

    /// Whether a screen reader finds a button labeled [label] that it can
    /// press: the tag's words are part of the button's own label.
    bool announced(WidgetTester tester, String label) => find.semantics
        .byPredicate((node) {
          final data = node.getSemanticsData();
          return data.label == label && data.hasAction(SemanticsAction.tap);
        })
        .evaluate()
        .isNotEmpty;

    testWidgets('marks nothing on a phone that never signed in', (
      tester,
    ) async {
      final robot = robotFor(tester);
      await robot.launch();

      expect(robot.lastUsed, findsNothing);
      expect(robot.lastUsedPill, findsNothing);
    }, variant: iOS);

    testWidgets('marks Google when Google was used last, in its label too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final robot = robotFor(tester);
      await robot.keep(SignInOption.google);
      await robot.launch();

      expect(robot.lastUsedPill, findsOneWidget);
      expect(robot.tagged(robot.googleButton), isTrue);
      expect(robot.tagged(robot.appleButton), isFalse);
      expect(robot.tagged(robot.sendCode), isFalse);
      final strings = robot.strings;
      expect(
        announced(tester, strings.lastUsedButton(strings.googleButton)),
        isTrue,
      );
      expect(announced(tester, strings.appleButton), isTrue);
      semantics.dispose();
    }, variant: iOS);

    testWidgets('marks Apple when Apple was used last, in its label too', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final robot = robotFor(tester);
      await robot.keep(SignInOption.apple);
      await robot.launch();

      expect(robot.tagged(robot.appleButton), isTrue);
      expect(robot.tagged(robot.googleButton), isFalse);
      final strings = robot.strings;
      expect(
        announced(tester, strings.lastUsedButton(strings.appleButton)),
        isTrue,
      );
      expect(announced(tester, strings.googleButton), isTrue);
      semantics.dispose();
    }, variant: iOS);

    testWidgets('marks the email code when it was used last, in its label '
        'too', (tester) async {
      final semantics = tester.ensureSemantics();
      final robot = robotFor(tester);
      await robot.keep(SignInOption.emailCode);
      await robot.launch();
      await robot.enterEmail(SupabaseStub.email);

      expect(robot.tagged(robot.sendCode), isTrue);
      expect(robot.tagged(robot.googleButton), isFalse);
      final strings = robot.strings;
      expect(
        announced(tester, strings.lastUsedButton(strings.sendCodeButton)),
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('remembers a code sign-in, and keeps it over sign-out', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [codeSent()],
          verify: [sessionGranted()],
          logout: [signedOut()],
        );
      final robot = robotFor(tester, supabase: supabase);
      await robot.keep(SignInOption.google);
      await robot.launch();

      await robot.requestCode();
      await robot.enterCode('123456');
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(await robot.kept(), SignInOption.emailCode);

      await robot.signOut();

      expect(robot.signIn, findsOneWidget);
      expect(robot.tagged(robot.sendCode), isTrue);
      expect(robot.tagged(robot.googleButton), isFalse);
    });

    testWidgets('remembers a Google sign-in', (tester) async {
      GoogleSignInFake.setup().script([googleToken('google-id-token')]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = robotFor(tester, supabase: supabase);
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(await robot.kept(), SignInOption.google);
    });

    testWidgets('remembers an Apple sign-in', (tester) async {
      AppleSignInFake.setup().script([appleToken('apple-id-token')]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = robotFor(tester, supabase: supabase);
      await robot.launch();

      await robot.tapApple();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(await robot.kept(), SignInOption.apple);
    }, variant: iOS);

    testWidgets('counts a review account’s password as the email, where it '
        'started', (tester) async {
      final supabase = SupabaseStub()..script(password: [sessionGranted()]);
      final robot = robotFor(tester, supabase: supabase);
      await robot.launch();

      await robot.submitEmail('google-play-review@getemotely.com');
      await robot.enterPassword('correct horse battery staple');
      await robot.tapPasswordSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(await robot.kept(), SignInOption.emailCode);
    });

    testWidgets('keeps the last method when a sign-in is dismissed', (
      tester,
    ) async {
      GoogleSignInFake.setup().script([
        googleFailed(GoogleSignInExceptionCode.canceled),
      ]);
      final robot = robotFor(tester);
      await robot.keep(SignInOption.apple);
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(await robot.kept(), SignInOption.apple);
      expect(robot.tagged(robot.appleButton), isTrue);
    }, variant: iOS);

    testWidgets('never tells PostHog which method was used last', (
      tester,
    ) async {
      final robot = robotFor(tester);
      await robot.keep(SignInOption.google);
      await robot.launch();

      expect(robot.analytics.events, isEmpty);
      expect(robot.analytics.identities, isEmpty);
    });

    testWidgets('stays clear of the button above it at twice the text size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final robot = robotFor(tester);
      await robot.keep(SignInOption.google);
      await robot.launch();

      expect(tester.takeException(), isNull);
      expect(robot.lastUsedPill, findsOneWidget);
      final pill = tester.getRect(robot.lastUsedPill);
      expect(pill.overlaps(tester.getRect(robot.appleButton)), isFalse);
      // It still sits on the edge of the button it marks.
      final google = tester.getRect(robot.googleButton);
      expect(pill.bottom, greaterThan(google.top));
      expect(pill.right, lessThanOrEqualTo(google.right));
    }, variant: iOS);

    testWidgets('meets accessibility guidelines on each button it marks', (
      tester,
    ) async {
      for (final option in SignInOption.values) {
        final robot = robotFor(tester);
        await robot.keep(option);

        await tester.expectMeetsAccessibilityGuidelines(robot.app);
        expect(robot.lastUsedPill, findsOneWidget);
        await GetIt.I.reset();
      }
    }, variant: iOS);
  });
}
