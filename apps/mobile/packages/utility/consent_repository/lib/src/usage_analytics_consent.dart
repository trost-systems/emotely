import 'package:analytics/analytics.dart';

/// Consent to usage analytics (#204): the answer to "May I count how you use
/// the app?", which the device holds and PostHog obeys ([PostHogGate]).
///
/// The one place the app changes that answer, so the first-launch sheet and
/// the Privacy settings screen cannot drift apart.
class const UsageAnalyticsConsent({required final PostHogGate _gate}) {
  /// The answer as it stands; `null` while nobody on this device has been
  /// asked yet.
  AnalyticsChoice? get choice => _gate.choice;

  /// Every change of [choice] from here on, from wherever it was made.
  Stream<AnalyticsChoice?> get changes => _gate.changes;

  /// Completes once every change asked for so far has been applied.
  Future<void> get settled => _gate.settled;

  /// The user allowed: PostHog is set up.
  Future<void> allow() => _gate.allow();

  /// The user said no, or withdrew: PostHog is switched off.
  Future<void> deny() => _gate.deny();
}
