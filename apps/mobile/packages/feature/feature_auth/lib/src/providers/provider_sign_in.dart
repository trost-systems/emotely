import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:crypto/crypto.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

/// A provider the app signs in with natively: the platform's own sheet
/// issues an ID token, and Supabase trades it for a session (#51). [option]
/// is its button, as the "Last used" tag remembers it.
enum IdentityProvider(
  final SignInMethod method,
  final OAuthProvider oauth,
  final SignInOption option,
) {
  google(SignInMethod.google, OAuthProvider.google, SignInOption.google),

  /// iOS only: Android has no native Apple sheet, only a browser redirect.
  apple(SignInMethod.apple, OAuthProvider.apple, SignInOption.apple),
}

/// This app's OAuth clients in the Google Cloud project `emotely-sign-in`.
/// Public identifiers, not credentials. [server] is the web client: the
/// audience Android's tokens carry, and the one Supabase lists first. [ios]
/// is the client the iOS SDK needs to show its sheet at all.
class const GoogleClientIds({
  required final String server,
  required final String ios,
});

/// An ID token a provider issued, and the raw [nonce] whose SHA-256 it
/// carries: Supabase accepts the token only together with that nonce, so a
/// token lifted off the device on its own signs nobody in.
///
/// No generated `toString`: the token names the user.
class const ProviderToken({
  required final String idToken,
  required final String nonce,
});

/// [provider] answered with a credential that carries no ID token.
class const MissingIdToken(final IdentityProvider provider)
    implements Exception;

/// Asks a provider's sheet for an ID token. The platform plugins stay behind
/// this one class, so the bloc sees a token, a dismissal (null) or an
/// exception, and nothing about how each platform gets there.
class ProviderSignIn({required final GoogleClientIds google}) {
  /// The raw nonce Google was set up with. google_sign_in takes exactly one
  /// `initialize` per process, and the nonce is part of it, so every Google
  /// sign-in in a process shares this one; it never leaves the process.
  Future<String>? _googleNonce;

  static final _random = Random.secure();

  /// A token from [provider]'s sheet, or null if the user dismissed it.
  Future<ProviderToken?> signIn(IdentityProvider provider) =>
      switch (provider) {
        IdentityProvider.google => _google(),
        IdentityProvider.apple => _apple(),
      };

  /// Signs out of Google, if this process ever signed in with it: otherwise
  /// Android's sheet offers the last account straight back. Apple keeps no
  /// session in the app to end.
  Future<void> signOut() async {
    if (_googleNonce == null) {
      return;
    }
    await GoogleSignIn.instance.signOut();
  }

  /// A fresh authorization code from Apple's sheet, for the agent to revoke
  /// the account's grant with (#193); null if the user dismissed the sheet
  /// or the platform has no native one (Android). It asks for nothing about
  /// the user: the code is all revocation needs. Single-use, and valid for
  /// five minutes.
  Future<String?> appleAuthorizationCode() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );
      return credential.authorizationCode;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled) {
        rethrow;
      }
      return null;
    }
  }

  /// Revokes emotely's grant on the Google account this device signs in
  /// with (#193), restoring that account first without a sheet where the
  /// platform can (Android may offer its account picker instead). False
  /// when no account came back, so there was nothing here to disconnect.
  Future<bool> disconnectGoogle() async {
    await (_googleNonce ??= _initializeGoogle());
    // No future at all means the platform cannot restore one: none either.
    final account = await GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (account == null) {
      return false;
    }
    await GoogleSignIn.instance.disconnect();
    return true;
  }

  Future<ProviderToken?> _google() async {
    final nonce = await (_googleNonce ??= _initializeGoogle());
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return _token(
        IdentityProvider.google,
        account.authentication.idToken,
        nonce,
      );
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        rethrow;
      }
      return null;
    }
  }

  Future<String> _initializeGoogle() async {
    final nonce = _rawNonce();
    await GoogleSignIn.instance.initialize(
      // Ignored on Android, which knows the app by package and signing key.
      clientId: google.ios,
      serverClientId: google.server,
      nonce: _hashed(nonce),
    );
    return nonce;
  }

  /// A fresh nonce per attempt, and no name: the app has no use for one, so
  /// it asks for the address alone (data minimization).
  Future<ProviderToken?> _apple() async {
    final nonce = _rawNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: _hashed(nonce),
      );
      return _token(IdentityProvider.apple, credential.identityToken, nonce);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled) {
        rethrow;
      }
      return null;
    }
  }

  static ProviderToken _token(
    IdentityProvider provider,
    String? idToken,
    String nonce,
  ) => ProviderToken(
    idToken: idToken ?? (throw MissingIdToken(provider)),
    nonce: nonce,
  );

  /// 32 random bytes, URL-safe: what Supabase's own helper produces.
  static String _rawNonce() =>
      base64Url.encode([for (var i = 0; i < 32; i++) _random.nextInt(256)]);

  /// What the provider is given: the hex SHA-256 Supabase compares the
  /// token's `nonce` claim with.
  static String _hashed(String nonce) =>
      sha256.convert(utf8.encode(nonce)).toString();
}
