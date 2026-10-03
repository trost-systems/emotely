import 'dart:convert';

import 'package:emotely_web/delete_account.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final supabase = Uri.parse('https://example.supabase.co');
  const key = 'sb_publishable_test';
  // Shaped like an access token, obviously not one (a secret scanner reads
  // this): three dot-separated segments, no signature over anything.
  const accessToken = 'header.payload.not-a-signature';
  // What Turnstile hands the page once the visitor passed its check;
  // GoTrue verifies it with Cloudflare before it sends a mail.
  const captcha = 'turnstile-token';

  group('requestDeletionCode', () {
    test('asks for a code without ever creating an account', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      });

      final outcome = await requestDeletionCode(
        client,
        email: 'alice@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
        captchaToken: captcha,
      );

      expect(outcome, CodeRequestOutcome.sent);
      expect(seen?.method, 'POST');
      expect(seen?.url, Uri.parse('https://example.supabase.co/auth/v1/otp'));
      expect(seen?.headers['apikey'], key);
      expect(seen?.headers['authorization'], 'Bearer $key');
      expect(seen?.headers['content-type'], startsWith('application/json'));
      // The whole point: a deletion request must never make an account.
      expect(jsonDecode(seen!.body), {
        'email': 'alice@example.com',
        'create_user': false,
        // Where GoTrue reads the human check from (#94).
        'gotrue_meta_security': {'captcha_token': captcha},
      });
    });

    test(
      'an address with no account is reported exactly like a sent code',
      () async {
        // GoTrue answers 422 otp_disabled when create_user is false and the
        // address is unknown; surfacing that would be an enumeration oracle.
        final client = MockClient(
          (_) async => http.Response(
            '{"error_code":"otp_disabled",'
            '"msg":"Signups not allowed for otp"}',
            422,
          ),
        );

        final outcome = await requestDeletionCode(
          client,
          email: 'nobody@example.com',
          supabaseUrl: supabase,
          publishableKey: key,
          captchaToken: captcha,
        );

        expect(outcome, CodeRequestOutcome.sent);
      },
    );

    test('a 429 asks the caller to wait rather than hammer', () async {
      final client = MockClient(
        (_) async =>
            http.Response('{"error_code":"over_email_send_rate_limit"}', 429),
      );
      final outcome = await requestDeletionCode(
        client,
        email: 'alice@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
        captchaToken: captcha,
      );
      expect(outcome, CodeRequestOutcome.tooMany);
    });

    test('a refused human check is retryable, with a fresh token', () async {
      // GoTrue's answer to a missing, spent or forged Turnstile token.
      final client = MockClient(
        (_) async => http.Response(
          '{"error_code":"captcha_failed",'
          '"msg":"captcha protection: request disallowed"}',
          400,
        ),
      );
      final outcome = await requestDeletionCode(
        client,
        email: 'alice@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
        captchaToken: captcha,
      );
      expect(outcome, CodeRequestOutcome.failed);
    });

    test('any other status or a network error is retryable', () async {
      final down = MockClient((_) async => http.Response('', 503));
      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      for (final client in [down, offline]) {
        final outcome = await requestDeletionCode(
          client,
          email: 'alice@example.com',
          supabaseUrl: supabase,
          publishableKey: key,
          captchaToken: captcha,
        );
        expect(outcome, CodeRequestOutcome.failed);
      }
    });
  });

  group('deleteAccountWithCode', () {
    test('verifies the code, then deletes with the returned token', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/auth/v1/verify') {
          return http.Response(jsonEncode({'access_token': accessToken}), 200);
        }
        // `delete_account()` reports whether a row really went.
        return http.Response('true', 200);
      });

      final outcome = await deleteAccountWithCode(
        client,
        email: 'alice@example.com',
        code: '123456',
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, DeletionOutcome.deleted);
      // Verify and delete, and no logout: the cascade took the session.
      expect(seen, hasLength(2));

      final verify = seen.first;
      expect(verify.method, 'POST');
      expect(
        verify.url,
        Uri.parse('https://example.supabase.co/auth/v1/verify'),
      );
      expect(jsonDecode(verify.body), {
        'email': 'alice@example.com',
        'token': '123456',
        'type': 'email',
      });

      // The deletion runs as the user, under RLS: their own bearer token,
      // never the publishable key and never a privileged one.
      final delete = seen.last;
      expect(
        delete.url,
        Uri.parse('https://example.supabase.co/rest/v1/rpc/delete_account'),
      );
      expect(delete.headers['authorization'], 'Bearer $accessToken');
      expect(delete.headers['apikey'], key);
    });

    test(
      'a wrong or expired code is reported, and nothing is deleted',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((request) async {
          seen.add(request);
          return http.Response(
            '{"error_code":"otp_expired",'
            '"msg":"Token has expired or is invalid"}',
            403,
          );
        });

        final outcome = await deleteAccountWithCode(
          client,
          email: 'alice@example.com',
          code: '000000',
          supabaseUrl: supabase,
          publishableKey: key,
        );

        expect(outcome, DeletionOutcome.badCode);
        expect(seen, hasLength(1));
      },
    );

    test('a verify that returns no token deletes nothing', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response('{}', 200);
      });

      final outcome = await deleteAccountWithCode(
        client,
        email: 'alice@example.com',
        code: '123456',
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, DeletionOutcome.failed);
      expect(seen, hasLength(1));
    });

    test('a refused deletion is a failure, not a false confirmation', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/auth/v1/verify') {
          return http.Response(jsonEncode({'access_token': accessToken}), 200);
        }
        return http.Response('{"code":"42501"}', 401);
      });

      final outcome = await deleteAccountWithCode(
        client,
        email: 'alice@example.com',
        code: '123456',
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, DeletionOutcome.failed);
      // Verify minted a session that nothing deleted, so it is given back
      // rather than left to live out its refresh window.
      final logout = seen.last;
      expect(logout.url.path, '/auth/v1/logout');
      expect(logout.headers['authorization'], 'Bearer $accessToken');
    });

    test('a deletion that deleted nothing is not a confirmation', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/auth/v1/verify') {
          return http.Response(jsonEncode({'access_token': accessToken}), 200);
        }
        // 200, but the function says it found no row to delete.
        return http.Response('false', 200);
      });

      final outcome = await deleteAccountWithCode(
        client,
        email: 'alice@example.com',
        code: '123456',
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, DeletionOutcome.failed);
      expect(seen.last.url.path, '/auth/v1/logout');
    });

    test('a network error is a failure, not an exception', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      final outcome = await deleteAccountWithCode(
        client,
        email: 'alice@example.com',
        code: '123456',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, DeletionOutcome.failed);
    });
  });

  group('normalizeCode', () {
    test('drops the spaces a paste from a mail app brings along', () {
      expect(normalizeCode('12 34 56'), '123456');
      expect(normalizeCode('  123456 '), '123456');
      expect(normalizeCode('123 456'), '123456');
    });
    test('leaves anything else to the shape check', () {
      expect(normalizeCode('12345a'), '12345a');
    });
  });

  group('looksLikeCode', () {
    test('accepts exactly six digits', () {
      expect(looksLikeCode('123456'), isTrue);
    });
    test('rejects anything else', () {
      expect(looksLikeCode('12345'), isFalse);
      expect(looksLikeCode('1234567'), isFalse);
      expect(looksLikeCode('12345a'), isFalse);
      expect(looksLikeCode(''), isFalse);
      // Spaces are stripped by normalizeCode before this check sees them.
      expect(looksLikeCode('12 34 56'), isFalse);
    });
  });
}
