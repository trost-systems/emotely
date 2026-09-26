import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

void main() {
  group('registerConsentRepository', () {
    test('registers one repository for the version it is given, and the '
        'usage-analytics consent over the gate', () async {
      final getIt = GetIt.asNewInstance();
      final supabase = SupabaseStub();

      // The utilities as the app registers them, this one among them, after
      // the analytics it builds on.
      registerUtilitiesUnderTest(
        getIt,
        agent: AgentStub(),
        supabase: supabase,
        analytics: AnalyticsSpy(stored: null),
      );

      final repository = getIt<ConsentRepository>();
      expect(repository.supabase, same(supabase.supabase));
      expect(repository.version, testConsentVersion);
      expect(repository, same(getIt<ConsentRepository>()));
      final usage = getIt<UsageAnalyticsConsent>();
      expect(usage, same(getIt<UsageAnalyticsConsent>()));

      await usage.allow();

      expect(getIt<PostHogGate>().choice, AnalyticsChoice.allowed);
    });
  });
}
