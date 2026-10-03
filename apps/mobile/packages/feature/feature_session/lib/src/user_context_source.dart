import 'package:contract/contract.dart';

/// Where the session learns who the user is, to tell the agent (#204).
///
/// The name belongs to the user's profile, which is not this feature's and
/// may be another feature's, and a feature never knows another feature
/// (ADR 0015). So, like a navigator, the session says what it needs and the
/// app answers: it implements this in its composition root and registers it
/// as a factory, one per session, since what one remembers about the user
/// must end with that session's screen; a test fakes it.
abstract class UserContextSource() {
  /// What the agent may know about the user right now, or null when the
  /// app knows nothing to say.
  ///
  /// Asked before every round, since the agent keeps nothing between rounds
  /// and a rename made in the app should reach the next one. That is no
  /// reason to go to the network every time: an implementation answers from
  /// what it already knows for this session, and learns of a rename made
  /// in the app as it is saved (#264).
  ///
  /// Must not throw: a name is a nicety, never a reason for a round to
  /// fail, so an implementation that cannot tell answers null.
  Future<UserContext?> current();

  /// The session is over: forget what was learned about the user for it.
  /// The session calls this as it closes, so nothing it remembered outlives
  /// its screen (ADR 0015).
  Future<void> close();
}
