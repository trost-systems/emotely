import 'package:contract/contract.dart';
import 'package:feature_session/feature_session.dart';

/// The app's answer to the session's question of who the user is (#204),
/// for the agent to address them by name.
///
/// The name lives in the user's profile, which the app does not have yet
/// (the profile step of #204), so it has nothing to say and every round
/// goes out as it always has. The profile answers here when it lands; the
/// session side, the wire and the agent are in place and tested with a
/// name.
class const AppUserContextSource() implements UserContextSource {
  @override
  Future<UserContext?> current() => Future.value();
}
