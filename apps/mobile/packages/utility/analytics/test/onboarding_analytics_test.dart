import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

void main() {
  group(OnboardingAnalytics, () {
    const welcome = OnboardingStepView(
      id: OnboardingStepId.welcome,
      index: 0,
      phase: OnboardingPhase.beforeSignUp,
    );
    const accountName = OnboardingStepView(
      id: OnboardingStepId.accountName,
      index: 0,
      phase: OnboardingPhase.afterSignIn,
    );

    test(
      'reports the flow and each step with the version and variant',
      () async {
        final spy = AnalyticsSpy();
        final analytics = OnboardingAnalytics(gate: spy.gate, flowVersion: 3);

        await analytics.started(stepCount: 4);
        await analytics.stepViewed(welcome);
        await analytics.stepCompleted(
          welcome,
          action: OnboardingStepAction.continued,
          duration: const Duration(milliseconds: 1250),
        );
        await analytics.stepCompleted(
          accountName,
          action: OnboardingStepAction.skipped,
          duration: Duration.zero,
        );
        await analytics.stepCompleted(
          welcome,
          action: OnboardingStepAction.back,
          duration: const Duration(seconds: 2),
        );

        const flow = {'flow_version': 3, 'variant': 'control'};
        expect(spy.events, [
          event('onboarding_started', {...flow, 'step_count': 4}),
          event('onboarding_step_viewed', {
            ...flow,
            'step_id': 'welcome',
            'step_index': 0,
            'phase': 'before_sign_up',
          }),
          event('onboarding_step_completed', {
            ...flow,
            'step_id': 'welcome',
            'step_index': 0,
            'phase': 'before_sign_up',
            'action': 'continue',
            'duration_ms': 1250,
          }),
          event('onboarding_step_completed', {
            ...flow,
            'step_id': 'account_name',
            'step_index': 0,
            'phase': 'after_sign_in',
            'action': 'skip',
            'duration_ms': 0,
          }),
          event('onboarding_step_completed', {
            ...flow,
            'step_id': 'welcome',
            'step_index': 0,
            'phase': 'before_sign_up',
            'action': 'back',
            'duration_ms': 2000,
          }),
        ]);
      },
    );

    test('says where onboarding led and where the name came from, never '
        'the name', () async {
      final spy = AnalyticsSpy();
      final analytics = OnboardingAnalytics(gate: spy.gate, flowVersion: 1);

      await analytics.completed(
        next: OnboardingNext.session,
        nameSource: NameSource.typed,
      );
      await analytics.completed(
        next: OnboardingNext.journal,
        nameSource: NameSource.placeholder,
      );
      await analytics.completed(
        next: OnboardingNext.session,
        nameSource: NameSource.existing,
      );
      await analytics.displayNameChanged(NameChangeSource.onboarding);
      await analytics.displayNameChanged(NameChangeSource.profile);

      const flow = {'flow_version': 1, 'variant': 'control'};
      expect(spy.events, [
        event('onboarding_completed', {
          ...flow,
          'next': 'session',
          'name_source': 'typed',
        }),
        event('onboarding_completed', {
          ...flow,
          'next': 'journal',
          'name_source': 'placeholder',
        }),
        event('onboarding_completed', {
          ...flow,
          'next': 'session',
          'name_source': 'existing',
        }),
        event('display_name_changed', {...flow, 'source': 'onboarding'}),
        event('display_name_changed', {...flow, 'source': 'profile'}),
      ]);
    });

    test('holds a step view until the usage-analytics question is answered, '
        'so the first screen under the sheet is counted', () async {
      final spy = AnalyticsSpy(stored: null);
      final analytics = OnboardingAnalytics(gate: spy.gate, flowVersion: 1);

      final viewed = analytics.stepViewed(welcome);
      await spy.gate.settled;

      expect(spy.events, isEmpty);

      await spy.gate.allow();
      await viewed;

      // After the allow itself, never before it: the funnel starts there.
      expect(spy.events.map((captured) => captured['event']), [
        'usage_analytics_allowed',
        'onboarding_step_viewed',
      ]);
    });

    test('sends nothing held back once the answer is no', () async {
      final spy = AnalyticsSpy(stored: null);
      final analytics = OnboardingAnalytics(gate: spy.gate, flowVersion: 1);

      final started = analytics.started(stepCount: 4);
      await spy.gate.settled;
      await spy.gate.deny();
      await started;

      expect(spy.events, isEmpty);
    });
  });
}
