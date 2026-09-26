import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'sign_in_identity.freezed.dart';

/// How an account signs in, as the profile says it: "Via Google".
enum SignInVia() {
  apple,
  google,

  /// A code sent to the address. The stores' review accounts, which sign
  /// in with a password, are the email provider too and read the same.
  emailCode,
}

/// Who is signed in, as the user may see it on their own device: the
/// sign-in [email] and the [method] the account signs in with. Neither
/// ever goes to analytics (ADR 0005); the auth feature turns the address
/// into one boolean for PostHog and nothing more.
///
/// No generated `toString`: [email] is personal data, and a state holding
/// it must print nothing of it.
@Freezed(toStringOverride: false)
abstract class SignInIdentity with _$SignInIdentity {
  /// An identity with [email] (none for an account without one) and
  /// [method] (none for a provider this app does not offer).
  const factory({String? email, SignInVia? method}) = _SignInIdentity;

  /// What the Supabase session says of [user].
  ///
  /// The method is the provider Supabase records for the account
  /// (`app_metadata.provider`), or else its first linked identity's. That is
  /// the provider the account was created with: an account that later
  /// linked a second provider by the same address reads as the first. The
  /// session does not say which provider signed it in — its `amr` claim
  /// says `oauth` for Apple and Google alike — and the identities' sign-in
  /// times are only kept for providers, never for an email code.
  factory ofUser(User user) => SignInIdentity(
    email: switch (user.email) {
      null || '' => null,
      final email => email,
    },
    method: _via(
      user.appMetadata['provider'] ?? user.identities?.firstOrNull?.provider,
    ),
  );

  static SignInVia? _via(Object? provider) => switch (provider) {
    'apple' => SignInVia.apple,
    'google' => SignInVia.google,
    'email' => SignInVia.emailCode,
    _ => null,
  };
}

/// What the screens need to know of an identity beyond its fields.
extension SignInIdentityX on SignInIdentity {
  /// Whether [SignInIdentity.email] is an address Apple made up for this
  /// app ("Hide My Email"): it forwards to the user, but they never chose
  /// it and would not recognise it, so the screens say "Hidden by Apple"
  /// instead of showing it.
  bool get hiddenByApple =>
      email?.toLowerCase().endsWith('@privaterelay.appleid.com') ?? false;
}
