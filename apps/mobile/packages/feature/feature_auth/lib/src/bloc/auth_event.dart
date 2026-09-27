part of 'auth_bloc.dart';

/// What the sign-in screen, and Supabase itself, can tell [AuthBloc].
///
/// No generated `toString`: the variants carry the email, the code and a
/// password, and a `BlocObserver` or an error log printing an event must
/// never print those (ADR 0005). `Instance of 'AuthPasswordSubmitted'` is
/// all a transition ever shows.
@Freezed(toStringOverride: false)
sealed class AuthEvent with _$AuthEvent {
  /// Continue with [email]: a sign-in code is sent to it, unless it is a
  /// review account, which is asked for its password instead. Without
  /// [createAccount] ("I have an account") the code only signs into an
  /// account that exists, and an unknown address is told so.
  const factory emailSubmitted(
    String email, {
    @Default(true) bool createAccount,
  }) = AuthEmailSubmitted;

  /// Verify the [code] the user received.
  const factory codeSubmitted(String code) = AuthCodeSubmitted;

  /// Check the [password] of the review account at the password step.
  const factory passwordSubmitted(String password) = AuthPasswordSubmitted;

  /// Sign in with [provider]'s own sheet instead of an email code.
  const factory providerSelected(IdentityProvider provider) =
      AuthProviderSelected;

  /// Back to the email step.
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
