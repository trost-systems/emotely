import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group(AnalyticsChoiceStore, () {
    AnalyticsChoiceStore storeWith([Map<String, Object> data = const {}]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(data);
      return AnalyticsChoiceStore(preferences: SharedPreferencesAsync());
    }

    test('knows no choice on a fresh install', () async {
      expect(await storeWith().read(), isNull);
    });

    test('keeps a choice across instances, as across launches', () async {
      await storeWith().write(AnalyticsChoice.allowed);
      final relaunched = AnalyticsChoiceStore(
        preferences: SharedPreferencesAsync(),
      );

      expect(await relaunched.read(), AnalyticsChoice.allowed);

      await relaunched.write(AnalyticsChoice.denied);

      expect(await relaunched.read(), AnalyticsChoice.denied);
    });

    test('forgets the choice when cleared', () async {
      final store = storeWith();
      await store.write(AnalyticsChoice.allowed);

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('reads a value it does not recognise as no choice', () async {
      // Something another build wrote, or a corrupted value: asking again
      // is the only answer that cannot count someone who never agreed.
      final store = storeWith({AnalyticsChoiceStore.key: 'maybe'});

      expect(await store.read(), isNull);
    });
  });
}
