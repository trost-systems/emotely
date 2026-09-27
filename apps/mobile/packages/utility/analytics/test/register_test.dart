import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:testing/testing.dart';

void main() {
  group('registerAnalytics', () {
    void register(GetIt getIt, AnalyticsSpy spy) => registerAnalytics(
      getIt,
      posthog: spy.posthog,
      config: PostHogConfig('phc_test'),
      consentVersion: 'v1',
      onboardingFlowVersion: 7,
    );

    test('puts every builder behind one gate, shut until restored', () async {
      final getIt = GetIt.asNewInstance();
      final spy = AnalyticsSpy();
      register(getIt, spy);

      await getIt<SessionAnalytics>().sessionStarted();

      expect(spy.events, isEmpty);
      expect(spy.lifecycle, isEmpty);

      await getIt<PostHogGate>().restore();
      await getIt<SessionAnalytics>().sessionStarted();
      await getIt<AuthAnalytics>().signedIn(SignInMethod.code);
      await getIt<JournalAnalytics>().entryOpened();
      await getIt<ConsentAnalytics>().consentDeclined();
      await getIt<OnboardingAnalytics>().started(stepCount: 4);
      await getIt<ErrorReporter>().consentLoadFailed(
        Exception('x'),
        StackTrace.empty,
      );

      expect(spy.events, [
        event('session_started'),
        event('signed_in', {'method': 'code'}),
        event('entry_opened'),
        event('consent_declined', {'version': 'v1'}),
        event('onboarding_started', {
          'flow_version': 7,
          'variant': 'control',
          'step_count': 4,
        }),
      ]);
      expect(spy.exceptions, hasLength(1));
    });

    test('registers the gate and each builder once, as singletons', () {
      final getIt = GetIt.asNewInstance();
      register(getIt, AnalyticsSpy());

      expect(getIt<PostHogGate>(), same(getIt<PostHogGate>()));
      expect(getIt<SessionAnalytics>(), same(getIt<SessionAnalytics>()));
      expect(getIt<ErrorReporter>(), same(getIt<ErrorReporter>()));
    });
  });
}
