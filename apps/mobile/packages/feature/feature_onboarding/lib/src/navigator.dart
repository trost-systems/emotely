import 'package:analytics/analytics.dart';
import 'package:flutter/widgets.dart';

/// What onboarding asks of the app and cannot do itself, because a feature
/// never knows another feature (ADR 0015): sign-in and the journal are other
/// features' routes. Its own steps it shows itself. The app implements this
/// with those features' routes; a test fakes it and records what was asked.
abstract class OnboardingNavigator() {
  /// "I have an account": the sign-in screen as a sign-in, not a sign-up —
  /// headed "Welcome back", and an email code from there creates no
  /// account. [from] is where the user was going, if anywhere.
  void signIn(BuildContext context, {String? from});

  /// Onboarding is over for the signed-in user: on to [next], or to [from]
  /// when they were going somewhere in particular.
  void finish(
    BuildContext context, {
    required OnboardingNext next,
    String? from,
  });
}
