import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:contract/contract.dart';
import 'package:feature_session/feature_session.dart';
import 'package:profile_repository/profile_repository.dart';

/// The app's answer to the session's question of who the user is (#204),
/// for the agent to address them by name: the profile's name, and whether
/// emotely picked it on Skip.
///
/// One per session (#264): registered as a factory, so every session's
/// bloc gets its own. It reads the profile on the session's first round
/// and answers the rounds after from that, so a session of 16 answers
/// reads it once, not 17 times. A rename saved in the app still reaches
/// the next round: the repository tells it of every save, and the saved
/// profile replaces the one read. A rename made on another device reaches
/// the next session, which reads again.
///
/// What it remembers is the user's, so it lives no longer than the session
/// screen (ADR 0015: nothing per-user outlives a screen). The session
/// closes it as it closes, and it stops listening and forgets; sign-out
/// takes the session screen away with everything else.
///
/// A user without a profile has nothing to say, and every round goes out
/// as it always has. Neither does one whose profile cannot be read right
/// now: a name is a nicety, never a reason for a round to fail, so the
/// failure is reported, the round goes on without it, and the next round
/// reads again.
class AppUserContextSource({
  required final ProfileRepository profiles,
  required final ErrorReporter errors,
}) implements UserContextSource {
  /// The profile as this session knows it: the first round's read, or the
  /// last save made in the app since.
  Future<Profile?>? _known;

  StreamSubscription<Profile>? _saves;

  @override
  Future<UserContext?> current() async {
    _saves ??= profiles.saved.listen(
      (profile) => _known = Future.value(profile),
    );
    final known = _known ??= profiles.profile();
    try {
      return switch (await known) {
        null => null,
        final profile => UserContext(
          displayName: profile.displayName,
          nameIsPlaceholder: profile.nameIsPlaceholder,
        ),
      };
    } on Exception catch (error, stackTrace) {
      // A failed read is not remembered, so the next round asks again;
      // a rename saved in the meantime is newer anyway and stays.
      if (identical(_known, known)) {
        _known = null;
      }
      unawaited(errors.profileLoadFailed(error, stackTrace));
      return null;
    }
  }

  @override
  Future<void> close() async {
    _known = null;
    await _saves?.cancel();
    _saves = null;
  }
}
