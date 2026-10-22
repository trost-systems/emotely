// MockPlatformInterfaceMixin is marked visible-for-testing so that shipped
// code cannot bypass the platform-interface token. This package *is* test
// support — nothing in it ships — so the one thing the marker guards against
// does not apply, and the analyzer only knows "lib/" versus "test/".
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sign_in_with_apple_platform_interface/sign_in_with_apple_platform_interface.dart';

/// What a provider's sign-in sheet answers once: an ID token, or an error
/// such as the user dismissing it.
typedef ProviderRound<T> = Future<T> Function();

/// Stands in for the google_sign_in platform channel: records how the app
/// set the plugin up, answers each interactive sign-in with the next
/// scripted round, and counts sign-outs. The plugin's own Dart layer above
/// it — the singleton, the exception mapping — is the real one.
///
/// A hand-written [Fake] for the reason `UrlLauncherSpy` is one. Constructing
/// it installs it for the current test and restores the previous
/// implementation when the test ends.
class GoogleSignInFake.setup()
    extends Fake
    with MockPlatformInterfaceMixin
    implements GoogleSignInPlatform {
  this {
    final original = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = this;
    addTearDown(() => GoogleSignInPlatform.instance = original);
  }

  static const email = 'alice@gmail.example';

  /// Every `initialize`, in order.
  final inits = <InitParameters>[];
  final _rounds = <ProviderRound<AuthenticationResults>>[];
  var signOuts = 0;

  /// When true, signing out throws as the plugin does when the platform
  /// SDK refuses; nothing is counted in [signOuts].
  var signOutFails = false;

  /// Queues the answers to the next interactive sign-ins.
  void script(List<ProviderRound<AuthenticationResults>> rounds) =>
      _rounds.addAll(rounds);

  @override
  Future<void> init(InitParameters params) async => inits.add(params);

  // Null: the plugin derives its event stream from the calls themselves.
  @override
  Stream<AuthenticationEvent>? get authenticationEvents => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) {
    if (_rounds.isEmpty) {
      throw StateError('google sign-in fake: nothing scripted');
    }
    return _rounds.removeAt(0)();
  }

  /// What a lightweight sign-in finds: the Google account this device
  /// remembers, or null when it remembers none (or the user dismissed the
  /// account picker Android may show instead).
  AuthenticationResults? remembered;

  /// How often the app disconnected, i.e. revoked emotely's grant (#193).
  var disconnects = 0;

  /// When true, disconnecting throws as the plugin does when Google
  /// refuses; nothing is counted in [disconnects].
  var disconnectFails = false;

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => remembered;

  @override
  Future<void> disconnect(DisconnectParams params) async {
    if (disconnectFails) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
      );
    }
    disconnects++;
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    if (signOutFails) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
      );
    }
    signOuts++;
  }
}

/// Google's sheet returned [idToken] for [GoogleSignInFake.email].
ProviderRound<AuthenticationResults> googleToken(String idToken) =>
    () async => AuthenticationResults(
      user: const GoogleSignInUserData(email: GoogleSignInFake.email, id: 'g1'),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );

/// The Google account a device remembers from an earlier sign-in, as a
/// lightweight sign-in restores it ([GoogleSignInFake.remembered]).
const googleRemembered = AuthenticationResults(
  user: GoogleSignInUserData(email: GoogleSignInFake.email, id: 'g1'),
  authenticationTokens: AuthenticationTokenData(idToken: 'google-id-token'),
);

/// Google's sheet failed with [code] — `canceled` when the user dismisses it.
ProviderRound<AuthenticationResults> googleFailed(
  GoogleSignInExceptionCode code, {
  String? description,
}) =>
    () async =>
        throw GoogleSignInException(code: code, description: description);

/// Stands in for the sign_in_with_apple platform channel: answers each
/// request for an Apple ID credential with the next scripted round and
/// records the scopes and the nonce the app asked with. Installed and
/// restored like [GoogleSignInFake].
class AppleSignInFake.setup()
    extends Fake
    with MockPlatformInterfaceMixin
    implements SignInWithApplePlatform {
  this {
    final original = SignInWithApplePlatform.instance;
    SignInWithApplePlatform.instance = this;
    addTearDown(() => SignInWithApplePlatform.instance = original);
  }

  /// Every request, in order: the scopes and the nonce it carried.
  final requests =
      <({List<AppleIDAuthorizationScopes> scopes, String? nonce})>[];
  final _rounds = <ProviderRound<AuthorizationCredentialAppleID>>[];

  /// Queues the answers to the next requests.
  void script(List<ProviderRound<AuthorizationCredentialAppleID>> rounds) =>
      _rounds.addAll(rounds);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    WebAuthenticationOptions? webAuthenticationOptions,
    String? nonce,
    String? state,
  }) {
    requests.add((scopes: scopes, nonce: nonce));
    if (_rounds.isEmpty) {
      throw StateError('apple sign-in fake: nothing scripted');
    }
    return _rounds.removeAt(0)();
  }
}

/// Apple's sheet returned [idToken] (null: a credential without one).
ProviderRound<AuthorizationCredentialAppleID> appleToken(String? idToken) =>
    () async => AuthorizationCredentialAppleID(
      userIdentifier: 'apple-user',
      givenName: null,
      familyName: null,
      authorizationCode: 'apple-code',
      email: null,
      identityToken: idToken,
      state: null,
    );

/// Apple's sheet failed with [code] — `canceled` when the user dismisses it.
ProviderRound<AuthorizationCredentialAppleID> appleFailed(
  AuthorizationErrorCode code, {
  String message = '',
}) =>
    () async => throw SignInWithAppleAuthorizationException(
      code: code,
      message: message,
    );
