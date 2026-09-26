import 'package:analytics/analytics.dart';
import 'package:consent_repository/src/consent_repository.dart';
import 'package:consent_repository/src/usage_analytics_consent.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the repository as a singleton over [supabase], recording
/// agreement to [version] — the wording the app currently asks journal
/// consent for — and the usage-analytics consent, recording
/// [usageAnalyticsVersion] of that wording, over the `PostHogGate` and the
/// error reporter that `registerAnalytics` registered before it.
void registerConsentRepository(
  GetIt getIt, {
  required SupabaseClient supabase,
  required String version,
  required String usageAnalyticsVersion,
}) => getIt
  ..registerSingleton<ConsentRepository>(
    ConsentRepository(supabase: supabase, version: version),
  )
  ..registerSingleton<UsageAnalyticsConsent>(
    UsageAnalyticsConsent(
      gate: getIt<PostHogGate>(),
      supabase: supabase,
      version: usageAnalyticsVersion,
      errors: getIt<ErrorReporter>(),
    ),
  );
