import 'package:contract/contract.dart';

/// Where the session learns who the user is, to tell the agent (#204).
///
/// The name belongs to the user's profile, which is not this feature's and
/// may be another feature's, and a feature never knows another feature
/// (ADR 0015). So, like a navigator, the session says what it needs and the
/// app answers: it implements this in its composition root and registers it
/// as a singleton; a test fakes it.
abstract class UserContextSource() {
  /// What the agent may know about the user right now, or null when the
  /// app knows nothing to say. Asked before every round, since the agent
  /// keeps nothing between rounds and a rename should reach the next one.
  ///
  /// Must not throw: a name is a nicety, never a reason for a round to
  /// fail, so an implementation that cannot tell answers null.
  Future<UserContext?> current();
}
