import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInExceptionCode;
import 'package:profile_repository/profile_repository.dart';
// gotrue has its own AuthState (the stream event); ours is the bloc state.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:testing/testing.dart';

import 'sign_in_robot.dart';

void main() {
  group(AuthBloc, () {
    testWidgets('never sends the email or the code (ADR 0005)', (tester) async {
      const needleEmail = 'needle.person@example.com';
      const needleCode = '918273';
      // GoTrue quotes the address in a 4xx message and, for a 5xx, gotrue
      // keeps the whole body; a wrong code comes back in the refusal too.
      // Every reported exception is among what leaves; the last try of
      // each step goes through.
      final supabase = SupabaseStub()
        ..script(
          otp: [
            authRefused(
              statusCode: 400,
              errorCode: 'validation_failed',
              message: 'Unable to validate email address: $needleEmail',
            ),
            authRefused(
              statusCode: 500,
              errorCode: 'unexpected_failure',
              message: 'Error sending magic link email to $needleEmail',
            ),
            codeSent(),
          ],
          verify: [
            authRefused(
              statusCode: 403,
              errorCode: 'otp_expired',
              message: 'Token $needleCode has expired or is invalid',
            ),
            sessionGranted(),
          ],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.requestCode(needleEmail);
      await robot.requestCode(needleEmail);
      await robot.requestCode(needleEmail);
      await robot.enterCode(needleCode);
      await robot.tapSignIn();
      await robot.settle();
      await robot.tapSignIn();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'validation_failed',
            statusCode: 400,
          ),
          {'step': 'sign_in_code_request'},
        ),
        captured(withheld(AuthRetryableApiException, statusCode: 500), {
          'step': 'sign_in_code_request',
        }),
        captured(
          withheld(AuthApiException, code: 'otp_expired', statusCode: 403),
          {'step': 'sign_in_code_verify'},
        ),
      ]);
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, isNotEmpty);
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains(needleEmail)));
        expect(leaving, isNot(contains('needle')));
        expect(leaving, isNot(contains(needleCode)));
      }
      expect(robot.analytics.identified, [SupabaseStub.userId]);
    });

    testWidgets("never sends a provider's token or its errors (ADR 0005)", (
      tester,
    ) async {
      // An ID token names the user; a refusal may quote it, and the
      // platform's own error text may name the account. The last try
      // goes through.
      const needleToken = 'needle.id-token.needle';
      GoogleSignInFake.setup().script([
        googleFailed(
          GoogleSignInExceptionCode.unknownError,
          description: 'Account needle.person@gmail.example unavailable',
        ),
        googleToken(needleToken),
        googleToken(needleToken),
      ]);
      final supabase = SupabaseStub()
        ..script(
          idToken: [
            authRefused(
              statusCode: 400,
              errorCode: 'bad_jwt',
              message: 'Bad ID token ',
            ),
            sessionGranted(),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      for (var attempt = 0; attempt < 3; attempt++) {
        await robot.tapGoogle();
        await robot.settle();
      }

      expect(robot.home, findsOneWidget);
      expect(robot.analytics.exceptions, hasLength(2));
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, isNotEmpty);
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains('needle')));
      }
    });

    testWidgets("never sends a review account's password (ADR 0005)", (
      tester,
    ) async {
      const address = 'app-store-review@getemotely.com';
      const needlePassword = 'needle-hunter2-needle';
      // A refusal may quote what it refused, and for a 5xx gotrue keeps the
      // whole body; the last try goes through.
      final supabase = SupabaseStub()
        ..script(
          password: [
            authRefused(
              statusCode: 400,
              errorCode: 'invalid_credentials',
              message: 'Invalid login credentials: $needlePassword',
            ),
            authRefused(
              statusCode: 500,
              errorCode: 'unexpected_failure',
              message: 'Database error checking $needlePassword',
            ),
            sessionGranted(),
          ],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.submitEmail(address);
      for (var attempt = 0; attempt < 3; attempt++) {
        await robot.enterPassword(needlePassword);
        await robot.tapPasswordSignIn();
        await robot.settle();
      }

      expect(robot.home, findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'invalid_credentials',
            statusCode: 400,
          ),
          {'step': 'sign_in_password'},
        ),
        captured(withheld(AuthRetryableApiException, statusCode: 500), {
          'step': 'sign_in_password',
        }),
      ]);
      expect(robot.analytics.events, [
        event('sign_in_password_failed'),
        event('sign_in_password_failed'),
        event('signed_in', {'method': 'password'}),
      ]);
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, isNotEmpty);
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains(needlePassword)));
        expect(leaving, isNot(contains('needle')));
        expect(leaving, isNot(contains('hunter2')));
        // The address is not journal content, but it is the reviewer's
        // identity; only the user id travels.
        expect(leaving, isNot(contains(address)));
      }
      // Nor do the events and states, should a bloc observer or an error
      // log ever print a transition.
      expect(
        '${const AuthEvent.passwordSubmitted(needlePassword)}',
        isNot(contains('needle')),
      );
      expect(
        '${const AuthEvent.emailSubmitted(address)}',
        isNot(contains('@')),
      );
      for (final state in [
        const AuthState.passwordRequired(
          email: address,
          problem: SignInProblem.wrongPassword,
        ),
        const AuthState.checkingPassword(email: address),
        const AuthState.codeSent(
          email: address,
          problem: SignInProblem.wrongCode,
        ),
        const AuthState.signedIn(
          userId: 'needle',
          identity: SignInIdentity(email: address, method: SignInVia.emailCode),
        ),
      ]) {
        expect('$state', isNot(contains('@')));
        expect('$state', isNot(contains('needle')));
      }
    });
  });
}
