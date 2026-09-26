import 'package:shared_preferences/shared_preferences.dart';

/// What the user answered to "May I count how you use the app?" (#204).
/// No answer at all is `null`: the question has not been asked on this
/// device, or was asked of someone who has since signed out.
enum AnalyticsChoice() {
  /// PostHog may be set up: events, error tracking and surveys.
  allowed,

  /// PostHog stays off, or is switched off again.
  denied,
}

/// The usage-analytics choice as this device keeps it.
///
/// On the device because the question comes before there is an account to
/// record it against (§ 25 TDDDG asks before anything is stored for
/// analytics, and there is nobody to attribute a server record to yet).
/// Keeping the answer is itself technically necessary: without it the app
/// would have to ask on every launch. Once someone signs in, the consent
/// record on the server holds the evidence (ADR 0014); this store only
/// decides whether PostHog runs here.
class const AnalyticsChoiceStore({
  required final SharedPreferencesAsync preferences,
}) {
  /// The one key this store owns.
  static const key = 'usage_analytics_choice';

  /// The stored choice, or `null` when none is stored. A value this build
  /// does not recognise counts as none: asking again is the only answer
  /// that cannot count someone who never agreed.
  Future<AnalyticsChoice?> read() async {
    final stored = await preferences.getString(key);
    for (final choice in AnalyticsChoice.values) {
      if (choice.name == stored) {
        return choice;
      }
    }
    return null;
  }

  /// Keeps [choice] for the next launch.
  Future<void> write(AnalyticsChoice choice) =>
      preferences.setString(key, choice.name);

  /// Forgets the choice, so the question is asked again.
  Future<void> clear() => preferences.remove(key);
}
