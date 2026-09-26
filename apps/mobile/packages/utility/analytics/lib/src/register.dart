import 'package:analytics/src/analytics_choice_store.dart';
import 'package:analytics/src/auth_analytics.dart';
import 'package:analytics/src/consent_analytics.dart';
import 'package:analytics/src/error_reporter.dart';
import 'package:analytics/src/journal_analytics.dart';
import 'package:analytics/src/post_hog_gate.dart';
import 'package:analytics/src/session_analytics.dart';
import 'package:get_it/get_it.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers the [PostHogGate] over the one [posthog] instance — the seam a
/// test replaces with its spy — and every event builder and the error
/// reporter over the gate. The instance and its [config] go to the gate and
/// nowhere else, so nothing registered here can reach PostHog before the
/// user allowed it (#204).
///
/// The gate is registered shut: `main` awaits `PostHogGate.restore` before
/// the first frame, which reads the choice kept in the platform's
/// preferences (faked at its platform interface under test) and opens the
/// gate if it allows. [consentVersion] names the wording the app
/// currently asks journal consent for.
void registerAnalytics(
  GetIt getIt, {
  required Posthog posthog,
  required PostHogConfig config,
  required String consentVersion,
}) {
  final gate = PostHogGate(
    posthog: posthog,
    config: config,
    store: AnalyticsChoiceStore(preferences: SharedPreferencesAsync()),
  );
  getIt
    ..registerSingleton(gate)
    ..registerSingleton(SessionAnalytics(gate: gate))
    ..registerSingleton(AuthAnalytics(gate: gate))
    ..registerSingleton(JournalAnalytics(gate: gate))
    ..registerSingleton(ConsentAnalytics(gate: gate, version: consentVersion))
    ..registerSingleton(ErrorReporter(gate: gate));
}
