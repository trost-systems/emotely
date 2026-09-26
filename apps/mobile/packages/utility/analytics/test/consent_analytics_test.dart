import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

void main() {
  group(ConsentAnalytics, () {
    test('reports each decision with the wording it answered', () async {
      final spy = AnalyticsSpy();
      final analytics = ConsentAnalytics(gate: spy.gate, version: '2026-01-01');

      await analytics.consentGranted();
      await analytics.consentWithdrawn();
      await analytics.consentDeclined();

      expect(spy.events, [
        event('consent_granted', {'version': '2026-01-01'}),
        event('consent_withdrawn', {'version': '2026-01-01'}),
        event('consent_declined', {'version': '2026-01-01'}),
      ]);
    });
  });
}
