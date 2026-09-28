part of 'auth_bloc.dart';

/// Where sign-in stands; the screen renders exactly one step per state.
///
/// No generated `toString`: the variants carry the email and the user id,
/// and a `BlocObserver` or an error log printing a transition must never
/// print those (ADR 0005). `Instance of 'AuthCodeSent'` is all it shows.
@Freezed(toStringOverride: false)
sealed class AuthState with _$AuthState {
  /// Nobody is signed in; the email step, with the last [problem] if any.
  const factory signedOut({SignInProblem? problem}) = AuthSignedOut;

  /// A code is on its way to [email].
  const factory requestingCode({required String email}) = AuthRequestingCode;

  /// [email] has a code to type in, with the last [problem] if any.
  const factory codeSent({required String email, SignInProblem? problem}) =
      AuthCodeSent;

  /// The code for [email] is being checked.
  const factory verifying({required String email}) = AuthVerifying;

  /// [provider]'s sheet is up, or its token is being traded for a session.
  const factory signingInWith(IdentityProvider provider) = AuthSigningInWith;

  /// [email] is a review account and needs its password, with the last
  /// [problem] if any.
  const factory passwordRequired({
    required String email,
    SignInProblem? problem,
  }) = AuthPasswordRequired;

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

/// Why the last try at a sign-in step failed, as far as the user can act on
/// it. The screen words each in the user's language (ADR 0020); what exactly
/// went wrong goes to error tracking, never onto the screen.
enum SignInProblem() {
  /// GoTrue will send no more codes to this address for now.
  tooManyCodes,

  /// GoTrue is rate-limiting this device's sign-in requests. What the user
  /// typed may well be right, so this is never worded as a wrong answer.
  tooManyAttempts,

  /// GoTrue refused to send a code to the address, most likely not a real
  /// one.
  couldNotSend,

  /// The code did not sign anyone in: wrong, expired, or answered without a
  /// session.
  wrongCode,

  /// A review account's password did not sign it in.
  wrongPassword,

  /// No answer from the sign-in service at all.
  unreachable,

  /// A code asked for from "I have an account" for an address with no
  /// account: the user belongs in onboarding.
  noAccount,

  /// A provider's sheet or its token failed; not a dismissal.
  providerFailed,
}
