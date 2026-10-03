import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/navigator.dart';
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
    testWidgets('never sends the email, the password or a code of a new '
        'account (ADR 0005)', (tester) async {
      const needleEmail = 'needle.person@example.com';
      const needlePassword = 'needle-hunter2-needle';
      const needleCode = '918273';
      // GoTrue quotes the address in a 4xx message and, for a 5xx, gotrue
      // keeps the whole body; a wrong code comes back in the refusal too.
      // Every reported exception is among what leaves; the last try of
      // each step goes through.
      final supabase = SupabaseStub()
        ..script(
          signUp: [
            authRefused(
              statusCode: 400,
              errorCode: 'validation_failed',
              message: 'Unable to validate email address: $needleEmail',
            ),
            authRefused(
              statusCode: 500,
              errorCode: 'unexpected_failure',
              message: 'Error sending confirmation email to $needleEmail',
            ),
            accountCreated(email: needleEmail),
          ],
          verify: [
            authRefused(
              statusCode: 403,
              errorCode: 'otp_expired',
              message: 'Token $needleCode has expired or is invalid',
            ),
            sessionGranted(email: needleEmail),
          ],
        );
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(
        tester,
        supabase: supabase,
        agent: agent,
        mode: SignInMode.signUp,
      );
      await robot.launch();

      for (var attempt = 0; attempt < 3; attempt++) {
        await robot.submitCredentials(
          email: needleEmail,
          password: needlePassword,
        );
      }
      await robot.confirmWith(needleCode);
      await robot.tapConfirm();
      await robot.settle();

      expect(robot.home, findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'validation_failed',
            statusCode: 400,
          ),
          {'step': 'sign_up'},
        ),
        captured(withheld(AuthRetryableApiException, statusCode: 500), {
          'step': 'sign_up',
        }),
        captured(
          withheld(AuthApiException, code: 'otp_expired', statusCode: 403),
          {'step': 'auth_code_verify'},
        ),
      ]);
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, isNotEmpty);
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains(needleEmail)));
        expect(leaving, isNot(contains('needle')));
        expect(leaving, isNot(contains('hunter2')));
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

    testWidgets('never sends a password, old or new (ADR 0005)', (
      tester,
    ) async {
      const address = 'app-store-review@getemotely.com';
      const needlePassword = 'needle-hunter2-needle';
      const needleNew = 'needle-new-password';
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
          ],
          recover: [codeSent()],
          verify: [sessionGranted(email: address)],
        )
        ..rest('PUT /auth/v1/user', [
          authRefused(
            statusCode: 400,
            errorCode: 'unexpected_failure',
            message: 'Could not save $needleNew',
          ),
        ]);
      final agent = AgentStub()..script([unreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      for (var attempt = 0; attempt < 2; attempt++) {
        await robot.submitCredentials(email: address, password: needlePassword);
      }
      await robot.tapForgotPassword();
      await robot.settle();
      await robot.resetWith(password: needleNew);
      await robot.enterNewPassword(needleNew);
      await robot.tapSavePassword();
      await robot.settle();

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
        captured(
          withheld(
            AuthApiException,
            code: 'unexpected_failure',
            statusCode: 400,
          ),
          {'step': 'password_save'},
        ),
      ]);
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, isNotEmpty);
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains('needle')));
        expect(leaving, isNot(contains('hunter2')));
        // The address is not journal content, but it is the reviewer's
        // identity; only the user id travels.
        expect(leaving, isNot(contains(address)));
      }
    });

    test('prints no event or state with what the user typed (ADR 0005)', () {
      const address = 'needle@example.com';
      const secret = 'needle-hunter2-needle';
      final user = User.fromJson(
        SupabaseStub.session(email: address)['user']! as Map<String, dynamic>,
      )!;
      const reset = CodePurpose.resetPassword;
      const confirm = CodePurpose.confirmAccount;
      const identity = SignInIdentity(email: address, method: SignInVia.email);
      for (final printed in <Object>[
        const AuthEvent.signInSubmitted(address, secret),
        const AuthEvent.signUpSubmitted(address, secret),
        const AuthEvent.resetRequested(address),
        const AuthEvent.confirmationSubmitted(secret),
        const AuthEvent.resetSubmitted(secret, secret),
        const AuthEvent.newPasswordSubmitted(secret),
        const AuthState.signedOut(email: address),
        const AuthState.checking(email: address),
        const AuthState.codeSent(email: address, purpose: reset),
        const AuthState.checkingCode(email: address, purpose: confirm),
        AuthState.newPasswordRequired(email: address, user: user),
        AuthState.savingPassword(email: address, user: user),
        const AuthState.signedIn(userId: 'needle', identity: identity),
      ]) {
        expect('$printed', isNot(contains('@')));
        expect('$printed', isNot(contains('needle')));
      }
    });
  });
}
