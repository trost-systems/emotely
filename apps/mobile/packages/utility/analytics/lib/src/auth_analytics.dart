import 'package:analytics/src/post_hog_gate.dart';

/// How a user got in: an email and its password (a new account's first
/// sign-in, once its confirmation code is typed, and a reset's too), or a
/// provider's ID token. Its name is the only thing a sign-in event says
/// beyond the event itself, so a funnel can compare the ways in without
/// learning who took them (ADR 0005).
enum SignInMethod() {
  password,
  google,
  apple,
}

/// Sign-in analytics, content-free by construction (ADR 0005): PostHog
/// learns the user's id (a UUID), which step failed, and one boolean saying
/// whether the account is ours — never the email, the password or a code.
/// The methods take no strings but the id, so a leak would be a type error
/// before it was a bug.
class const AuthAnalytics({required final PostHogGate gate}) {
  /// The user asked for an account with an email and a password.
  Future<void> signUpRequested() =>
      gate.capture(eventName: 'sign_up_requested');

  /// Supabase did not create the account (an address it refused, a
  /// password too short, a rate limit, an outage).
  Future<void> signUpFailed() => gate.capture(eventName: 'sign_up_failed');

  /// The confirmation code the user typed was wrong or expired.
  Future<void> confirmationCodeRejected() =>
      gate.capture(eventName: 'sign_up_code_rejected');

  /// The user asked for a code to reset a forgotten password.
  Future<void> passwordResetRequested() =>
      gate.capture(eventName: 'password_reset_requested');

  /// The reset did not go through: no code could be sent, or the new
  /// password could not be saved.
  Future<void> passwordResetFailed() =>
      gate.capture(eventName: 'password_reset_failed');

  /// The reset code the user typed was wrong or expired.
  Future<void> resetCodeRejected() =>
      gate.capture(eventName: 'password_reset_code_rejected');

  /// A password sign-in did not go through (wrong password, outage).
  Future<void> passwordFailed() =>
      gate.capture(eventName: 'sign_in_password_failed');

  /// [userId] is the person behind this device's events, whether they just
  /// signed in or the session was restored.
  ///
  /// [internal] says whether this is one of our own accounts, and is the one
  /// thing PostHog learns about the address: the caller derives the boolean
  /// from the email's domain, and the email itself never reaches this class
  /// (ADR 0005). It rides along as the person property
  /// `$internal_or_test_user`, which the project's default "filter out
  /// internal and test users" cohort matches on, so the founder's test
  /// account, the store reviewers and Google's pre-launch crawler drop out of
  /// every dashboard by themselves.
  ///
  /// Sent on every identify, true or false, so a person's flag is explicit
  /// rather than absent — an unset property is not a `false` to a cohort.
  Future<void> identify({required String userId, required bool internal}) =>
      gate.identify(
        userId: userId,
        userProperties: {r'$internal_or_test_user': internal},
      );

  /// The user dismissed [provider]'s sign-in sheet. Not a failure: they may
  /// have meant to use another way in.
  Future<void> providerCanceled(SignInMethod provider) => gate.capture(
    eventName: 'sign_in_provider_canceled',
    properties: {'provider': provider.name},
  );

  /// Signing in with [provider] did not go through: the platform refused,
  /// or Supabase did not accept its token.
  Future<void> providerFailed(SignInMethod provider) => gate.capture(
    eventName: 'sign_in_provider_failed',
    properties: {'provider': provider.name},
  );

  /// The user completed a sign-in (not a restored session) by [method].
  Future<void> signedIn(SignInMethod method) =>
      gate.capture(eventName: 'signed_in', properties: {'method': method.name});

  /// The user signed out: PostHog forgets who this device belongs to, and
  /// the usage-analytics choice goes with them — it was theirs, not the
  /// phone's, so whoever comes next is asked again (#204).
  Future<void> signedOut() async {
    await gate.capture(eventName: 'signed_out');
    await gate.forget();
  }

  /// The user deleted their account: PostHog forgets who this device
  /// belonged to, and the choice goes with them as on sign-out.
  Future<void> accountDeleted() async {
    await gate.capture(eventName: 'account_deleted');
    await gate.forget();
  }
}
