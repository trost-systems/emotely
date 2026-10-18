import 'package:feature_auth/src/internal_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(isInternalAccount, () {
    test('takes every address on the founder-owned domain', () {
      expect(isInternalAccount('test@getemotely.com'), isTrue);
      expect(isInternalAccount('  Test@GetEmotely.com '), isTrue);
    });

    test('covers the store review accounts', () {
      expect(isInternalAccount('google-play-review@getemotely.com'), isTrue);
      expect(isInternalAccount('app-store-review@getemotely.com'), isTrue);
    });

    test('takes nobody outside the domain', () {
      expect(isInternalAccount('someone@gmail.com'), isFalse);
      expect(isInternalAccount('x@getemotely.com.evil.org'), isFalse);
      expect(isInternalAccount(''), isFalse);
    });
  });
}
