part of 'auth_bloc.dart';

/// What the sign-in screen, and Supabase itself, can tell [AuthBloc].
///
/// No generated `toString`: the variants carry the email, a code and a
/// password, and a `BlocObserver` or an error log printing an event must
/// never print those (ADR 0005). `Instance of 'AuthSignInSubmitted'` is
/// all a transition ever shows.
@Freezed(toStringOverride: false)
sealed class AuthEvent with _$AuthEvent {
  /// Sign into the account [email] with its [password] ("I have an
  /// account"). An account whose address was never confirmed is sent a
  /// new confirmation code instead.
  const factory signInSubmitted(String email, String password) =
      AuthSignInSubmitted;

  /// Create an account for [email] with [password], the last step of
  /// onboarding. It opens once the code mailed to [email] is typed in; an
  /// address that already has an account is signed into with [password]
  /// instead, if it is that account's.
  const factory signUpSubmitted(String email, String password) =
      AuthSignUpSubmitted;

  /// "Forgot password?": mail a code to [email] that lets its account
  /// choose a new password. Also how an account that never had a password
  /// (made with a sign-in code before #187) gets one.
  const factory resetRequested(String email) = AuthResetRequested;

  /// The code from the confirmation mail, which opens the new account.
  const factory confirmationSubmitted(String code) = AuthConfirmationSubmitted;

  /// The code from the reset mail and the [newPassword] to set with it.
  const factory resetSubmitted(String code, String newPassword) =
      AuthResetSubmitted;

  /// The [newPassword] again, when a reset code signed the account in but
  /// the first one could not be saved.
  const factory newPasswordSubmitted(String newPassword) =
      AuthNewPasswordSubmitted;

  /// Mail the code of the step on screen again.
  const factory codeResendRequested() = AuthCodeResendRequested;

  /// Sign in with [provider]'s own sheet instead of an email and password.
  const factory providerSelected(IdentityProvider provider) =
      AuthProviderSelected;

  /// The sign-in screen is shown in [languageCode] (`en`, `de`): the
  /// language the account's mails are written in from now on. The screen
  /// says so when it first shows and whenever its language changes.
  const factory languageShown(String languageCode) = AuthLanguageShown;

  /// Back to the email and password.
  const factory emailChangeRequested() = AuthEmailChangeRequested;

  /// Sign out of this device.
  const factory signOutRequested() = AuthSignOutRequested;

  /// Supabase reports a session for [userId], signed in as [identity], or
  /// none. Mirrors the SDK's auth stream; the UI never sends it. PostHog's
  /// internal-account flag is derived from the identity's address, which
  /// itself goes no further than the state.
  const factory sessionChanged(String? userId, SignInIdentity? identity) =
      AuthSessionChanged;
}
