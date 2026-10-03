import 'package:feature_account/feature_account.dart';

/// Revokes the account's sign-in grants the way a test says: [left] are
/// the ones still in place afterwards. [onRevoke] runs at the moment the
/// feature asks, to observe what had happened by then.
class FakeSignInGrants({
  final Set<SignInGrant> left = const {},
  final void Function()? onRevoke,
  @override final bool asksApple = false,
}) extends SignInGrants {
  /// How often the feature asked for the grants to be revoked.
  var revocations = 0;

  @override
  Future<Set<SignInGrant>> revoke() {
    revocations++;
    onRevoke?.call();
    return Future.value(left);
  }
}
