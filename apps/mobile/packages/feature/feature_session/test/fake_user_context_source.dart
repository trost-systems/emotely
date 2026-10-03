import 'package:contract/contract.dart';
import 'package:feature_session/feature_session.dart';

/// The app's side of the session's user context, as a test wants it: what
/// [context] holds when a round asks, how often a round asked, and whether
/// the session let go of it.
class FakeUserContextSource() extends UserContextSource {
  /// What every round is told; none until a test says otherwise.
  UserContext? context;

  /// How many rounds asked.
  var asked = 0;

  /// Whether the session closed it.
  var closed = false;

  @override
  Future<UserContext?> current() async {
    asked++;
    return context;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
