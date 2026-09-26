import 'package:analytics/analytics.dart';
import 'package:consent_repository/src/consent_repository.dart';
import 'package:consent_repository/src/usage_analytics_consent.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the repository as a singleton over [supabase], recording
/// agreement to [version] — the wording the app currently asks consent for —
/// and the usage-analytics consent over the `PostHogGate` that
/// `registerAnalytics` registered before it.
void registerConsentRepository(
  GetIt getIt, {
  required SupabaseClient supabase,
  required String version,
}) => getIt
  ..registerSingleton<ConsentRepository>(
    ConsentRepository(supabase: supabase, version: version),
  )
  ..registerSingleton<UsageAnalyticsConsent>(
    UsageAnalyticsConsent(gate: getIt<PostHogGate>()),
  );
