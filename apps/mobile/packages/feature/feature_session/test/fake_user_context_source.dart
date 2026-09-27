import 'package:contract/contract.dart';
import 'package:feature_session/feature_session.dart';

/// The app's side of the session's user context, as a test wants it: what
/// [context] holds when a round asks, and how often a round asked.
class FakeUserContextSource() extends UserContextSource {
  /// What every round is told; none until a test says otherwise.
  UserContext? context;

  /// How many rounds asked.
  var asked = 0;

  @override
  Future<UserContext?> current() async {
    asked++;
    return context;
  }
}
