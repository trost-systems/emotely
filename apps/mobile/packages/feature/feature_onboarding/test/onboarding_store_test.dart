import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group(OnboardingStore, () {
    late SharedPreferencesAsync preferences;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      preferences = SharedPreferencesAsync();
    });

    OnboardingStore store() => OnboardingStore(preferences: preferences);

    const named = OnboardingProgress(
      completed: {
        OnboardingStepId.welcome,
        OnboardingStepId.value,
        OnboardingStepId.name,
      },
      draft: 'Peter',
      started: true,
    );

    test('starts a device that kept nothing at Welcome', () async {
      final fresh = store();
      await fresh.restore();

      expect(fresh.progress, const OnboardingProgress());
      expect(fresh.readyForAccount, isFalse);
    });

    test('resumes, after a restart, where the last launch left off', () async {
      await store().save(named.copyWith(placeholder: 'Wren'));

      final restarted = store();
      await restarted.restore();

      expect(restarted.progress, named.copyWith(placeholder: 'Wren'));
    });

    test('keeps the progress as one entry naming its flow version', () async {
      await store().save(named);

      expect(jsonDecode((await preferences.getString(OnboardingStore.key))!), {
        'flow_version': 1,
        'completed': ['welcome', 'value', 'name'],
        'draft': 'Peter',
        'placeholder': null,
        'started': true,
      });
    });

    test('starts over what another flow version, or a shape this build '
        'cannot read, left behind', () async {
      for (final stored in [
        jsonEncode({
          'flow_version': 2,
          'completed': ['welcome'],
          'draft': '',
          'placeholder': null,
          'started': true,
        }),
        '{not json',
        jsonEncode({'flow_version': 1}),
      ]) {
        await preferences.setString(OnboardingStore.key, stored);
        final restarted = store();
        await restarted.restore();

        expect(restarted.progress, const OnboardingProgress(), reason: stored);
      }
    });

    test('ignores a step id this build does not know', () async {
      await preferences.setString(
        OnboardingStore.key,
        jsonEncode({
          'flow_version': 1,
          'completed': ['welcome', 'goals'],
          'draft': '',
          'placeholder': null,
          'started': false,
        }),
      );
      final restarted = store();
      await restarted.restore();

      expect(restarted.progress.completed, {OnboardingStepId.welcome});
    });

    test('is ready for the account once hello is done, and reopens hello on '
        'the way back from sign-up', () async {
      final kept = store();
      await kept.save(
        named.copyWith(completed: {...named.completed, OnboardingStepId.hello}),
      );

      expect(kept.readyForAccount, isTrue);

      await kept.reopen();

      expect(kept.readyForAccount, isFalse);
      expect(kept.progress, named);
    });

    test('forgets everything on clear, on the device too', () async {
      final kept = store();
      await kept.save(named);
      await kept.clear();

      expect(kept.progress, const OnboardingProgress());
      expect(await preferences.getString(OnboardingStore.key), isNull);
    });

    test('tells every change as it happens', () async {
      final kept = store();
      final changes = <OnboardingProgress>[];
      final subscription = kept.changes.listen(changes.add);
      addTearDown(subscription.cancel);

      await kept.save(named);
      await kept.clear();

      expect(changes, [named, const OnboardingProgress()]);
    });

    test(
      'has nothing to reopen in a flow with no steps before sign-up',
      () async {
        final empty = OnboardingStore(
          preferences: preferences,
          flow: const OnboardingFlow(version: 1, steps: []),
        );
        await empty.reopen();

        expect(empty.progress, const OnboardingProgress());
      },
    );
  });
}
