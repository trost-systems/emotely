import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group(AnalyticsChoiceStore, () {
    const account = '00000000-0000-0000-0000-00000000000a';

    AnalyticsChoiceStore storeWith([Map<String, Object> data = const {}]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(data);
      return AnalyticsChoiceStore(preferences: SharedPreferencesAsync());
    }

    test('knows no choice on a fresh install', () async {
      expect(await storeWith().read(), isNull);
    });

    test('keeps a choice and whose it is across instances, as across '
        'launches', () async {
      await storeWith().write(AnalyticsChoice.allowed, account: account);
      final relaunched = AnalyticsChoiceStore(
        preferences: SharedPreferencesAsync(),
      );

      expect(await relaunched.read(), (
        choice: AnalyticsChoice.allowed,
        account: account,
      ));

      await relaunched.write(AnalyticsChoice.denied, account: account);

      expect(await relaunched.read(), (
        choice: AnalyticsChoice.denied,
        account: account,
      ));
    });

    test(
      'keeps a choice made before anyone signed in as nobody’s yet',
      () async {
        final store = storeWith();

        await store.write(AnalyticsChoice.allowed, account: null);

        expect(await store.read(), (
          choice: AnalyticsChoice.allowed,
          account: null,
        ));
      },
    );

    test('forgets the choice when cleared', () async {
      final store = storeWith();
      await store.write(AnalyticsChoice.allowed, account: account);

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('reads a value it does not recognise as no choice', () async {
      // Something another build wrote, or a corrupted value: asking again
      // is the only answer that cannot count someone who never agreed.
      for (final value in [
        'maybe',
        '{"choice":"maybe","account":null}',
        '{"choice":"allowed"}',
        '{"choice":"allowed","account":7}',
        '["allowed"]',
      ]) {
        final store = storeWith({AnalyticsChoiceStore.key: value});

        expect(await store.read(), isNull, reason: value);
      }
    });

    test('reads a choice from before choices knew whose they were as no '
        'choice', () async {
      // What the #204 builds wrote: the choice alone. It may be the last
      // person's, left behind by a session that ended while the app was
      // closed, so nothing can say whose it is — it is asked again.
      for (final legacy in AnalyticsChoice.values) {
        final store = storeWith({AnalyticsChoiceStore.key: legacy.name});

        expect(await store.read(), isNull, reason: legacy.name);
      }
    });

    test('writes the value it reads back', () async {
      final store = storeWith({
        AnalyticsChoiceStore.key: AnalyticsChoiceStore.valueOf(
          AnalyticsChoice.denied,
          account: account,
        ),
      });

      expect(await store.read(), (
        choice: AnalyticsChoice.denied,
        account: account,
      ));
    });
  });
}
