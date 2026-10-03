import 'dart:async';

import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The grants a deleted account leaves with Apple and Google (#193):
/// emotely stays listed in the user's Apple Account under Sign in with
/// Apple, or among the Google Account's connected apps, until it is
/// revoked. Supabase revokes neither, so this does, before the account is
/// deleted — afterwards there is no session left to prove whose grant it
/// is.
///
/// - **Apple**: the sheet issues a fresh authorization code, and the agent
///   trades it for a token and revokes that, checking that the code is for
///   the Apple ID this account is linked to. Only iOS has the native sheet.
/// - **Google**: the device's own Google account is restored without a
///   sheet where it can be, and disconnected.
class ProviderGrants({
  required final SupabaseClient _supabase,
  required final ProviderSignIn _providers,
  required final AgentClient _agent,
  required final ErrorReporter _errors,
}) {
  /// Revokes every grant the signed-in account holds, and answers the
  /// providers whose grant is still in place: the user dismissed a sheet,
  /// the device had no way to ask, or the provider or the agent refused.
  /// Never throws; a refusal is reported, a dismissal is not.
  Future<Set<IdentityProvider>> revoke() async {
    final left = <IdentityProvider>{};
    for (final provider in _linked()) {
      if (!await _revoke(provider)) {
        left.add(provider);
      }
    }
    return left;
  }

  /// The providers linked to the account, as Supabase records them in
  /// `app_metadata` (which only the server writes).
  Iterable<IdentityProvider> _linked() {
    final providers = _supabase.auth.currentUser?.appMetadata['providers'];
    return IdentityProvider.values.where(
      (provider) =>
          providers is List && providers.contains(provider.oauth.name),
    );
  }

  Future<bool> _revoke(IdentityProvider provider) async {
    try {
      return await switch (provider) {
        IdentityProvider.google => _providers.disconnectGoogle(),
        IdentityProvider.apple => _revokeApple(),
      };
    } on Exception catch (error, stackTrace) {
      unawaited(
        _errors.signInRevocationFailed(
          error,
          stackTrace,
          provider: provider.method,
        ),
      );
      return false;
    }
  }

  Future<bool> _revokeApple() async {
    final code = await _providers.appleAuthorizationCode();
    if (code == null) {
      return false;
    }
    await _agent.revokeApple(authorizationCode: code);
    return true;
  }
}
