import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthRetryableFetchException;
import 'package:testing/testing.dart';

import 'sign_in_robot.dart';

/// Apple's button is offered on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  // The sign-in mail (supabase/templates/sign_in_code.html) is written in
  // the language the account keeps as `user_metadata.app_locale`, English
  // when it keeps none. The app shows the screen in one language; the
  // account learns it when a code is asked for (a new account) and after
  // every sign-in (an existing one).
  group('The sign-in mail language', () {
    const code = '482913';

    Map<String, dynamic>? languageKept(SupabaseStub supabase) =>
        [for (final body in supabase.bodies('/auth/v1/user')) body['data']]
                .singleOrNull
            as Map<String, dynamic>?;

    testWidgets('is asked for with the code, in the screen’s language', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(otp: [codeSent()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();

      // Supabase keeps it only for an account the request creates.
      expect(supabase.bodies('/auth/v1/otp').single['data'], {
        'app_locale': 'de',
      });
    });

    testWidgets('follows the language the screen is shown in', (tester) async {
      final supabase = SupabaseStub()..script(otp: [codeSent()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        locale: const Locale('en'),
      );
      await robot.launch();

      await robot.requestCode();

      expect(supabase.bodies('/auth/v1/otp').single['data'], {
        'app_locale': 'en',
      });
    });

    testWidgets('is kept on an account that signs in without it', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();
      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(languageKept(supabase), {'app_locale': 'de'});
      // Nothing else about the account changes.
      expect(supabase.bodies('/auth/v1/user').single.keys, ['data']);
      expect(robot.analytics.exceptions, isEmpty);
    });

    testWidgets('replaces the one an account kept from another language', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [codeSent()],
          verify: [
            sessionGranted(userMetadata: {'app_locale': 'en'}),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();
      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(languageKept(supabase), {'app_locale': 'de'});
    });

    testWidgets('is not written again when the account has it', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          otp: [codeSent()],
          verify: [
            sessionGranted(userMetadata: {'app_locale': 'de'}),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();
      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(supabase.to(SupabaseStub.updateUserEndpoint), isEmpty);
    });

    testWidgets('is kept after Sign in with Google', (tester) async {
      GoogleSignInFake.setup().script([googleToken('google-id-token')]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(languageKept(supabase), {'app_locale': 'de'});
    });

    testWidgets('is kept after Sign in with Apple', (tester) async {
      AppleSignInFake.setup().script([appleToken('apple-id-token')]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapApple();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(languageKept(supabase), {'app_locale': 'de'});
    }, variant: iOS);

    testWidgets('is kept after a review account’s password', (tester) async {
      const reviewer = 'reviewer@example.com';
      final supabase = SupabaseStub()
        ..script(password: [sessionGranted(email: reviewer)]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        passwordAccounts: {reviewer},
      );
      await robot.launch();

      await robot.submitEmail(reviewer);
      await robot.enterPassword('a password');
      await robot.tapPasswordSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(languageKept(supabase), {'app_locale': 'de'});
    });

    testWidgets('failing to keep it costs the sign-in nothing', (tester) async {
      final supabase = SupabaseStub()
        ..script(otp: [codeSent()], verify: [sessionGranted()])
        ..rest(SupabaseStub.updateUserEndpoint, [authUnreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestCode();
      await robot.enterCode(code);
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(robot.state, isA<AuthSignedIn>());
      // The next mail comes in the language kept before; error tracking
      // hears why.
      expect(robot.analytics.exceptions, [
        captured(withheld(AuthRetryableFetchException), {
          'step': 'mail_language_save',
        }),
      ]);
    });
  });
}
