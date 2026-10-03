part of 'auth_bloc.dart';

/// Where sign-in stands; the screen renders exactly one step per state.
///
/// No generated `toString`: the variants carry the email and the user id,
/// and a `BlocObserver` or an error log printing a transition must never
/// print those (ADR 0005). `Instance of 'AuthCodeSent'` is all it shows.
@Freezed(toStringOverride: false)
sealed class AuthState with _$AuthState {
  /// Nobody is signed in; the email and password, with the last [problem]
  /// if any, and the [email] typed before if the user came back to it.
  const factory signedOut({SignInProblem? problem, String? email}) =
      AuthSignedOut;

  /// The email and password are with Supabase: a sign-in, a new account,
  /// or a reset code on its way to [email].
  const factory checking({required String email}) = AuthChecking;

  /// [provider]'s sheet is up, or its token is being traded for a session.
  const factory signingInWith(IdentityProvider provider) = AuthSigningInWith;

  /// A code is in the mail to [email], for [purpose], with the last
  /// [problem] if any; [resent] once the user asked for a new one and it
  /// went out.
  const factory codeSent({
    required String email,
    required CodePurpose purpose,
    SignInProblem? problem,
    @Default(false) bool resent,
  }) = AuthCodeSent;

  /// The code for [email] is being checked, or sent again, for [purpose].
  const factory checkingCode({
    required String email,
    required CodePurpose purpose,
  }) = AuthCheckingCode;

  /// A reset code signed [user] in, but the new password could not be
  /// saved ([problem] says why): the account is asked for it once more
  /// before the user is let past the screen.
  const factory newPasswordRequired({
    required String email,
    required User user,
    SignInProblem? problem,
  }) = AuthNewPasswordRequired;

  /// The new password for [user] is being saved.
  const factory savingPassword({required String email, required User user}) =
      AuthSavingPassword;

  /// [userId] is signed in, as [identity]: the sign-in address and the
  /// method, for the screens to show on this device. Neither goes to
  /// analytics (ADR 0005); PostHog gets the id and one boolean.
  const factory signedIn({
    required String userId,
    required SignInIdentity identity,
  }) = AuthSignedIn;
}

/// What a mailed code is for.
enum CodePurpose() {
  /// Confirms a new account's address, which opens the account.
  confirmAccount,

  /// Signs the account in to choose a new password.
  resetPassword,
}

/// Why the last try at a sign-in step failed, as far as the user can act on
/// it. The screen words each in the user's language (ADR 0020); what exactly
/// went wrong goes to error tracking, never onto the screen.
enum SignInProblem() {
  /// GoTrue will mail no more codes to this address for now.
  tooManyCodes,

  /// GoTrue is rate-limiting this device's sign-in requests. What the user
  /// typed may well be right, so this is never worded as a wrong answer.
  tooManyAttempts,

  /// GoTrue refused to mail the address, most likely not a real one.
  couldNotSend,

  /// The code did not sign anyone in: wrong, expired, or answered without a
  /// session.
  wrongCode,

  /// The email and password did not sign anyone in. Never says which of the
  /// two was wrong: GoTrue does not tell, and the screen must not guess.
  wrongPassword,

  /// GoTrue refused the new password as too weak (shorter than the
  /// project's minimum).
  weakPassword,

  /// A new account was asked for an address that has one, and the password
  /// typed is not its password.
  accountExists,

  /// A reset code signed the account in, but the new password could not be
  /// saved.
  passwordNotSaved,

  /// No answer from the sign-in service at all.
  unreachable,

  /// A provider's sheet or its token failed; not a dismissal.
  providerFailed,

  /// The human check (Cloudflare Turnstile) gave no token, or GoTrue
  /// refused the one it gave (#94). Nothing the user typed was judged, so
  /// this never says an address or a password is wrong.
  humanCheckFailed,
}
