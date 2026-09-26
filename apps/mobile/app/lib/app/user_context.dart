import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:contract/contract.dart';
import 'package:feature_session/feature_session.dart';
import 'package:profile_repository/profile_repository.dart';

/// The app's answer to the session's question of who the user is (#204),
/// for the agent to address them by name: the profile's name, and whether
/// emotely picked it on Skip. Read again before every round, so a rename
/// on the Profile screen reaches the next one.
///
/// A user without a profile has nothing to say, and every round goes out
/// as it always has. Neither does one whose profile cannot be read right
/// now: a name is a nicety, never a reason for a round to fail, so the
/// failure is reported and the round goes on without it.
class const AppUserContextSource({
  required final ProfileRepository profiles,
  required final ErrorReporter errors,
}) implements UserContextSource {
  @override
  Future<UserContext?> current() async {
    try {
      return switch (await profiles.profile()) {
        null => null,
        final profile => UserContext(
          displayName: profile.displayName,
          nameIsPlaceholder: profile.nameIsPlaceholder,
        ),
      };
    } on Exception catch (error, stackTrace) {
      unawaited(errors.profileLoadFailed(error, stackTrace));
      return null;
    }
  }
}
