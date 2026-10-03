/// A company the account signs in through, whose grant to emotely outlives
/// the account unless it is revoked (#193): emotely stays listed in the
/// user's Apple Account under Sign in with Apple, or among their Google
/// Account's connections.
enum SignInGrant() {
  apple,
  google,
}

/// Revokes those grants before the account is deleted; afterwards there is
/// no session left to prove whose grant it is.
///
/// Signing in belongs to the auth feature, and a feature never knows
/// another feature (ADR 0015). So, like `AccountDeviceData`, this feature
/// says when and the app says how: it implements this in its composition
/// root and registers it as a singleton; a test fakes it.
abstract class SignInGrants() {
  /// Revokes every grant the signed-in account holds, and answers those
  /// still in place — the user dismissed a provider's sheet, the device had
  /// no way to ask (Apple on Android), or the provider refused. Never
  /// throws: none of this may keep the account from being deleted.
  Future<Set<SignInGrant>> revoke();
}
