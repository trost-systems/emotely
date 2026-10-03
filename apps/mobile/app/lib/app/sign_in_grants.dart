import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';

/// The app's answer to the account feature's question of which sign-in
/// grants a deleted account leaves behind (#193): the auth feature revokes
/// them, and the account feature only hears which are still in place, in
/// its own terms. Neither feature knows the other (ADR 0015).
class const AppSignInGrants(final ProviderGrants _grants)
    implements SignInGrants {
  @override
  bool get asksApple => _grants.asksApple;

  @override
  Future<Set<SignInGrant>> revoke() async => {
    for (final provider in await _grants.revoke())
      switch (provider) {
        IdentityProvider.apple => SignInGrant.apple,
        IdentityProvider.google => SignInGrant.google,
      },
  };
}
