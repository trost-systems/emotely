import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

/// A user as Supabase Auth returns it, signed up through [provider].
User _user({
  String? email = SupabaseStub.email,
  String? provider,
  List<String> identities = const [],
}) => User.fromJson({
  ...SupabaseStub.session(email: email ?? '', provider: provider)['user']!
      as Map<String, Object?>,
  'email': ?email,
  'identities': [
    for (final (index, identity) in identities.indexed)
      {
        'id': '$index',
        'identity_id': 'identity-$index',
        'user_id': SupabaseStub.userId,
        'identity_data': <String, Object?>{},
        'provider': identity,
        'created_at': '2026-09-01T00:00:00Z',
        'last_sign_in_at': '2026-09-01T00:00:00Z',
        'updated_at': '2026-09-01T00:00:00Z',
      },
  ],
})!;

void main() {
  group(SignInIdentity, () {
    test('names the method the account signs in with', () {
      expect(
        SignInIdentity.ofUser(_user(provider: 'google')).method,
        SignInVia.google,
      );
      expect(
        SignInIdentity.ofUser(_user(provider: 'apple')).method,
        SignInVia.apple,
      );
      // An email and its password, or an account made with a sign-in code
      // before #187: both are the email provider to Supabase.
      expect(
        SignInIdentity.ofUser(_user(provider: 'email')).method,
        SignInVia.email,
      );
    });

    test('falls back to the first identity when the metadata is silent', () {
      expect(
        SignInIdentity.ofUser(_user(identities: ['apple', 'email'])).method,
        SignInVia.apple,
      );
    });

    test('names no method it does not know', () {
      expect(SignInIdentity.ofUser(_user(provider: 'phone')).method, isNull);
      expect(SignInIdentity.ofUser(_user()).method, isNull);
    });

    test('carries the sign-in address, or none', () {
      expect(
        SignInIdentity.ofUser(_user(provider: 'email')).email,
        SupabaseStub.email,
      );
      expect(SignInIdentity.ofUser(_user(email: '')).email, isNull);
      expect(SignInIdentity.ofUser(_user(email: null)).email, isNull);
    });

    test('knows an address Apple hides behind its private relay', () {
      const relay = SignInIdentity(
        email: 'x7k2@PrivateRelay.AppleID.com',
        method: SignInVia.apple,
      );
      const plain = SignInIdentity(
        email: 'peter@icloud.com',
        method: SignInVia.apple,
      );
      const none = SignInIdentity();

      expect(relay.hiddenByApple, isTrue);
      expect(plain.hiddenByApple, isFalse);
      expect(none.hiddenByApple, isFalse);
    });

    test('says nothing of the address when printed', () {
      const identity = SignInIdentity(email: 'needle@example.com');

      expect('$identity', isNot(contains('needle')));
    });
  });
}
