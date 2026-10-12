import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthRetryableFetchException;
import 'package:testing/testing.dart';

import 'sign_in_robot.dart';

/// Apple's button is offered on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  // The account's mails (supabase/templates/) are written in the language
  // it keeps as `user_metadata.app_locale`, English when it keeps none. The
  // app shows the screen in one language; the account learns it with the
  // sign-up (its confirmation mail is the first) and after every sign-in.
  group('The language of the account’s mails', () {
    Map<String, dynamic>? languageKept(SupabaseStub supabase) =>
        [
              for (final body in supabase.bodies('/auth/v1/user'))
                if (body.containsKey('data')) body['data'],
            ].singleOrNull
            as Map<String, dynamic>?;

    testWidgets('goes with a new account, in the screen’s language', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(signUp: [accountCreated()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        mode: SignInMode.signUp,
      );
      await robot.launch();

      await robot.submitCredentials();

      expect(robot.posted('signup').single['data'], {'app_locale': 'de'});
    });

    testWidgets('follows the language the screen is shown in', (tester) async {
      final supabase = SupabaseStub()..script(signUp: [accountCreated()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        mode: SignInMode.signUp,
        locale: const Locale('en'),
      );
      await robot.launch();

      await robot.submitCredentials();

      expect(robot.posted('signup').single['data'], {'app_locale': 'en'});
    });

    testWidgets('is kept on an account that signs in without it', (
      tester,
    ) async {
      final supabase = SupabaseStub()..script(password: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.submitCredentials();

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
          password: [
            sessionGranted(userMetadata: {'app_locale': 'en'}),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.submitCredentials();

      expect(languageKept(supabase), {'app_locale': 'de'});
    });

    testWidgets('is not written again when the account has it', (tester) async {
      final supabase = SupabaseStub()
        ..script(
          password: [
            sessionGranted(userMetadata: {'app_locale': 'de'}),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.submitCredentials();

      expect(robot.home, findsOneWidget);
      expect(supabase.to(SupabaseStub.updateUserEndpoint), isEmpty);
    });

    testWidgets('is kept after a reset', (tester) async {
      final supabase = SupabaseStub()
        ..script(recover: [codeSent()], verify: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.requestReset();
      await robot.resetWith();

      expect(robot.home, findsOneWidget);
      expect(languageKept(supabase), {'app_locale': 'de'});
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

    testWidgets('failing to keep it costs the sign-in nothing', (tester) async {
      final supabase = SupabaseStub()
        ..script(password: [sessionGranted()])
        ..rest(SupabaseStub.updateUserEndpoint, [authUnreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.submitCredentials();

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
