import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

void main() {
  group(UsageAnalyticsConsent, () {
    test('allowing sets PostHog up and keeps the answer', () async {
      final spy = AnalyticsSpy(stored: null);
      final consent = UsageAnalyticsConsent(gate: spy.gate);
      await consent.settled;

      expect(consent.choice, isNull);

      final changes = expectLater(
        consent.changes,
        emits(AnalyticsChoice.allowed),
      );
      await consent.allow();
      await changes;

      expect(consent.choice, AnalyticsChoice.allowed);
      expect(spy.lifecycle, ['setup', 'reset']);
    });

    test('withdrawing switches PostHog off', () async {
      final spy = AnalyticsSpy();
      final consent = UsageAnalyticsConsent(gate: spy.gate);
      await consent.settled;

      await consent.deny();

      expect(consent.choice, AnalyticsChoice.denied);
      expect(spy.lifecycle, ['setup', 'disable', 'close']);
    });
  });
}
