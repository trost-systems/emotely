import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleIDAuthorizationScopes, AuthorizationErrorCode;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// The hex SHA-256 of [nonce]: what the provider must be given, so the
/// token it issues can only be traded by whoever holds the raw nonce.
String _hashed(String nonce) => sha256.convert(utf8.encode(nonce)).toString();

/// Apple's button is offered on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('Sign in with Google', () {
    const idToken = 'google-id-token';
    const tokenGrant = 'POST /auth/v1/token';

    testWidgets('trades Google’s token for a session and opens the journal', (
      tester,
    ) async {
      final google = GoogleSignInFake.setup()..script([googleToken(idToken)]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      final grant = supabase.to(tokenGrant).single;
      expect(grant.query['grant_type'], 'id_token');
      final body = grant.body! as Map<String, dynamic>;
      expect(body['provider'], 'google');
      expect(body['id_token'], idToken);
      // The web client is the audience Android's tokens carry; iOS needs
      // its own client to show the sheet at all.
      final init = google.inits.single;
      expect(init.serverClientId, SignInRobot.googleClients.server);
      expect(init.clientId, SignInRobot.googleClients.ios);
      // Google saw only the hash; Supabase checks the raw nonce against it.
      final nonce = body['nonce'] as String;
      expect(nonce, isNotEmpty);
      expect(init.nonce, _hashed(nonce));
      expect(robot.home, findsOneWidget);
      expect(robot.analytics.events, [
        event('signed_in', {'method': 'google'}),
      ]);
      expect(robot.analytics.identified, [SupabaseStub.userId]);
    });

    testWidgets('sets Google up once, however often it is tapped', (
      tester,
    ) async {
      final google = GoogleSignInFake.setup()
        ..script([
          googleFailed(GoogleSignInExceptionCode.canceled),
          googleToken(idToken),
        ]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();
      await robot.tapGoogle();
      await robot.settle();

      // The plugin takes exactly one `initialize` per process.
      expect(google.inits, hasLength(1));
      expect(robot.home, findsOneWidget);
    });

    testWidgets('opens one sheet, however fast the taps come', (tester) async {
      GoogleSignInFake.setup().script([
        () => Future.delayed(const Duration(seconds: 1), googleToken(idToken)),
      ]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      // Two selections before the screen can disable the button; the fake
      // throws on a second sheet, since only one is scripted.
      tester.element(robot.signIn).read<AuthBloc>()
        ..add(const AuthEvent.providerSelected(IdentityProvider.google))
        ..add(const AuthEvent.providerSelected(IdentityProvider.google));
      await robot.settle();

      expect(supabase.to(tokenGrant), hasLength(1));
      expect(robot.home, findsOneWidget);
    });

    testWidgets('shows progress while the sheet is up', (tester) async {
      GoogleSignInFake.setup().script([
        () => Future.delayed(const Duration(seconds: 1), googleToken(idToken)),
      ]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();

      expect(robot.busy, findsOneWidget);
      expect(robot.canTapGoogle, isFalse);
      expect(robot.sendCode, findsNothing);

      await robot.settle();

      expect(robot.home, findsOneWidget);
    });

    testWidgets('stays put, quietly, when the user dismisses the sheet', (
      tester,
    ) async {
      GoogleSignInFake.setup().script([
        googleFailed(GoogleSignInExceptionCode.canceled),
      ]);
      final supabase = SupabaseStub();
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.emailField, findsOneWidget);
      expect(robot.error, findsNothing);
      expect(robot.canTapGoogle, isTrue);
      expect(supabase.to(tokenGrant), isEmpty);
      expect(robot.analytics.exceptions, isEmpty);
      expect(robot.analytics.events, [
        event('sign_in_provider_canceled', {'provider': 'google'}),
      ]);
    });

    testWidgets('explains when Google fails, and reports only the kind', (
      tester,
    ) async {
      GoogleSignInFake.setup().script([
        googleFailed(
          GoogleSignInExceptionCode.clientConfigurationError,
          description: 'Developer console is not set up correctly.',
        ),
      ]);
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
      );
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.emailField, findsOneWidget);
      expect(robot.errorText, SignInPage.providerFailedMessage);
      expect(robot.analytics.exceptions, [
        captured(withheld(GoogleSignInException), {
          'step': 'sign_in_provider',
          'provider': 'google',
        }),
      ]);
      expect(robot.analytics.events, [
        event('sign_in_provider_failed', {'provider': 'google'}),
      ]);
    });

    testWidgets('explains when Supabase refuses Google’s token', (
      tester,
    ) async {
      GoogleSignInFake.setup().script([googleToken(idToken)]);
      final supabase = SupabaseStub()
        ..script(
          idToken: [
            authRefused(
              statusCode: 400,
              errorCode: 'bad_oauth_callback',
              message: 'Bad ID token',
            ),
          ],
        );
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.signIn, findsOneWidget);
      expect(robot.errorText, SignInPage.providerFailedMessage);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(
            AuthApiException,
            code: 'bad_oauth_callback',
            statusCode: 400,
          ),
          {'step': 'sign_in_provider', 'provider': 'google'},
        ),
      ]);
    });

    testWidgets('says so when the sign-in service is unreachable', (
      tester,
    ) async {
      GoogleSignInFake.setup().script([googleToken(idToken)]);
      final supabase = SupabaseStub()..script(idToken: [authUnreachable()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect(robot.errorText, SignInPage.unreachableMessage);
    });

    testWidgets('signing out signs out of Google too', (tester) async {
      final google = GoogleSignInFake.setup()..script([googleToken(idToken)]);
      final supabase = SupabaseStub()
        ..script(idToken: [sessionGranted()], logout: [signedOut()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.tapGoogle();
      await robot.settle();

      tester
          .element(robot.home)
          .read<AuthBloc>()
          .add(const AuthEvent.signOutRequested());
      await robot.settle();

      // Otherwise Android's sheet would offer the same account straight
      // back to whoever picks the phone up next.
      expect(google.signOuts, 1);
      expect(robot.signIn, findsOneWidget);
    });

    testWidgets('signs out even when Google cannot be', (tester) async {
      final google = GoogleSignInFake.setup()
        ..script([googleToken(idToken)])
        ..signOutFails = true;
      final supabase = SupabaseStub()
        ..script(idToken: [sessionGranted()], logout: [signedOut()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();
      await robot.tapGoogle();
      await robot.settle();

      tester
          .element(robot.home)
          .read<AuthBloc>()
          .add(const AuthEvent.signOutRequested());
      await robot.settle();

      expect(google.signOuts, 0);
      expect(robot.signIn, findsOneWidget);
      expect(robot.analytics.events.last, event('signed_out'));
    });

    testWidgets('signing out leaves Google alone if it was never used', (
      tester,
    ) async {
      final google = GoogleSignInFake.setup();
      final supabase = SupabaseStub()..script(logout: [signedOut()]);
      await supabase.signedIn();
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      tester
          .element(robot.home)
          .read<AuthBloc>()
          .add(const AuthEvent.signOutRequested());
      await robot.settle();

      expect(google.inits, isEmpty);
      expect(google.signOuts, 0);
      expect(robot.signIn, findsOneWidget);
    });
  });

  group('Sign in with Apple', () {
    const idToken = 'apple-id-token';

    testWidgets('trades Apple’s token for a session, asking only for email', (
      tester,
    ) async {
      final apple = AppleSignInFake.setup()..script([appleToken(idToken)]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapApple();
      await robot.settle();

      final body =
          supabase.to('POST /auth/v1/token').single.body!
              as Map<String, dynamic>;
      expect(body['provider'], 'apple');
      expect(body['id_token'], idToken);
      final request = apple.requests.single;
      // No name: the app has no use for one (data minimisation).
      expect(request.scopes, [AppleIDAuthorizationScopes.email]);
      expect(request.nonce, _hashed(body['nonce'] as String));
      expect(robot.home, findsOneWidget);
      expect(robot.analytics.events, [
        event('signed_in', {'method': 'apple'}),
      ]);
    }, variant: iOS);

    testWidgets('binds every attempt to a fresh nonce', (tester) async {
      final apple = AppleSignInFake.setup()
        ..script([
          appleFailed(AuthorizationErrorCode.canceled),
          appleToken(idToken),
        ]);
      final supabase = SupabaseStub()..script(idToken: [sessionGranted()]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapApple();
      await robot.settle();
      await robot.tapApple();
      await robot.settle();

      final [first, second] = apple.requests;
      expect(first.nonce, isNot(second.nonce));
      expect(robot.analytics.events, [
        event('sign_in_provider_canceled', {'provider': 'apple'}),
        event('signed_in', {'method': 'apple'}),
      ]);
    }, variant: iOS);

    testWidgets('explains a credential that carries no token', (tester) async {
      AppleSignInFake.setup().script([appleToken(null)]);
      final supabase = SupabaseStub();
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapApple();
      await robot.settle();

      expect(robot.errorText, SignInPage.providerFailedMessage);
      expect(supabase.to('POST /auth/v1/token'), isEmpty);
      expect(robot.analytics.events, [
        event('sign_in_provider_failed', {'provider': 'apple'}),
      ]);
    }, variant: iOS);

    testWidgets('explains when Apple fails', (tester) async {
      AppleSignInFake.setup().script([
        appleFailed(AuthorizationErrorCode.failed, message: 'needle'),
      ]);
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
      );
      await robot.launch();

      await robot.tapApple();
      await robot.settle();

      expect(robot.errorText, SignInPage.providerFailedMessage);
      expect(
        robot.analytics.outgoingStrings,
        everyElement(isNot(contains('needle'))),
      );
    }, variant: iOS);

    testWidgets('is offered on iOS, above Google', (tester) async {
      final robot = SignInRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
      );
      await robot.launch();

      expect(robot.appleButton, findsOneWidget);
      expect(robot.googleButton, findsOneWidget);
      // Apple's guidelines: no less prominent than the other providers.
      expect(
        tester.getTopLeft(robot.appleButton).dy,
        lessThan(tester.getTopLeft(robot.googleButton).dy),
      );
      expect(
        tester.getSize(robot.appleButton).height,
        greaterThanOrEqualTo(tester.getSize(robot.googleButton).height),
      );
    }, variant: iOS);
  });

  testWidgets('offers Apple only on iOS', (tester) async {
    // Android has no native Apple sheet (only a browser redirect), and the
    // store rule that asks for Apple next to Google is Apple's own.
    final robot = SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
    );
    await robot.launch();

    expect(robot.appleButton, findsNothing);
    expect(robot.googleButton, findsOneWidget);
  });

  testWidgets('names both provider buttons for assistive technology', (
    tester,
  ) async {
    final robot = SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
    );
    await robot.launch();

    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Continue with Apple'), findsOneWidget);
  }, variant: iOS);

  testWidgets('a screen reader can press the Google button', (tester) async {
    final semantics = tester.ensureSemantics();
    GoogleSignInFake.setup().script([
      googleFailed(GoogleSignInExceptionCode.canceled),
    ]);
    final robot = SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
    );
    await robot.launch();

    // The node a screen reader activates: the label and the tap together.
    tester.semantics.tap(
      find.semantics.byPredicate((node) {
        final data = node.getSemanticsData();
        return data.label == 'Sign in with Google' &&
            data.hasAction(SemanticsAction.tap);
      }),
    );
    await robot.settle();

    expect(robot.analytics.events, [
      event('sign_in_provider_canceled', {'provider': 'google'}),
    ]);
    semantics.dispose();
  });

  testWidgets('meets accessibility guidelines with both providers', (
    tester,
  ) async {
    final robot = SignInRobot(
      tester,
      supabase: SupabaseStub(),
      agent: AgentStub(),
    );

    await tester.expectMeetsAccessibilityGuidelines(robot.app);
  }, variant: iOS);
}
