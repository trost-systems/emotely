part of 'auth_bloc.dart';

/// Where sign-in stands; the screen renders exactly one step per state.
///
/// No generated `toString`: the variants carry the email and the user id,
/// and a `BlocObserver` or an error log printing a transition must never
/// print those (ADR 0005). `Instance of 'AuthCodeSent'` is all it shows.
@Freezed(toStringOverride: false)
sealed class AuthState with _$AuthState {
  /// Nobody is signed in; the email step, with the last [error] if any.
  const factory signedOut({String? error}) = AuthSignedOut;

  /// A code is on its way to [email].
  const factory requestingCode({required String email}) = AuthRequestingCode;

  /// [email] has a code to type in, with the last [error] if any.
  const factory codeSent({required String email, String? error}) = AuthCodeSent;

  /// The code for [email] is being checked.
  const factory verifying({required String email}) = AuthVerifying;

  /// [provider]'s sheet is up, or its token is being traded for a session.
  const factory signingInWith(IdentityProvider provider) = AuthSigningInWith;

  /// [email] is a review account and needs its password, with the last
  /// [error] if any.
  const factory passwordRequired({required String email, String? error}) =
      AuthPasswordRequired;

  /// The password for [email] is being checked.
  const factory checkingPassword({required String email}) =
      AuthCheckingPassword;

  /// [userId] is signed in, as [identity]: the sign-in address and the
  /// method, for the screens to show on this device. Neither goes to
  /// analytics (ADR 0005); PostHog gets the id and one boolean.
  const factory signedIn({
    required String userId,
    required SignInIdentity identity,
  }) = AuthSignedIn;
}
