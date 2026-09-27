import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';

/// The app's answer to what a deleted account leaves behind on this device
/// (#204): the way in the sign-in screen tags "Last used", which sign-out
/// keeps and deletion must not. Onboarding's progress and the analytics
/// choice need nothing here: a deletion already clears both on its way out
/// (the router on the sign-out that follows it, PostHog's gate on the
/// deletion's own event).
class const AppAccountDeviceData(final LastSignInStore _lastSignIn)
    implements AccountDeviceData {
  @override
  Future<void> forget() => _lastSignIn.clear();
}
