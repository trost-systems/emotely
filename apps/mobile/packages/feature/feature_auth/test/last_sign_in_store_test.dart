import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group(LastSignInStore, () {
    LastSignInStore storeWith([Map<String, Object> data = const {}]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData(data);
      return LastSignInStore(preferences: SharedPreferencesAsync());
    }

    test('knows no method on a fresh install', () async {
      expect(await storeWith().read(), isNull);
    });

    test('keeps the method across instances, as across launches', () async {
      await storeWith().remember(SignInOption.google);
      final relaunched = LastSignInStore(preferences: SharedPreferencesAsync());

      expect(await relaunched.read(), SignInOption.google);

      await relaunched.remember(SignInOption.email);

      expect(await relaunched.read(), SignInOption.email);
    });

    test('reads the email kept before #187 as the email', () async {
      // From when the email field mailed a sign-in code.
      final store = storeWith({LastSignInStore.key: 'email_code'});

      expect(await store.read(), SignInOption.email);
    });

    test('forgets the method when cleared', () async {
      final store = storeWith();
      await store.remember(SignInOption.apple);

      await store.clear();

      expect(await store.read(), isNull);
    });

    test('reads a value it does not recognize as no method', () async {
      // A method a later build offered, since removed: no tag beats a tag
      // on the wrong button.
      final store = storeWith({LastSignInStore.key: 'passkey'});

      expect(await store.read(), isNull);
    });
  });
}
