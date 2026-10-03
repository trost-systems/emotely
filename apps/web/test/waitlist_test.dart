import 'dart:convert';

import 'package:emotely_web/waitlist.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final supabase = Uri.parse('https://example.supabase.co');
  const key = 'sb_publishable_test';

  group('joinWaitlist', () {
    test(
      'posts the address with the publishable key, asking for nothing back',
      () async {
        http.Request? seen;
        final client = MockClient((request) async {
          seen = request;
          return http.Response('', 201);
        });

        final outcome = await joinWaitlist(
          client,
          email: 'alice@example.com',
          supabaseUrl: supabase,
          publishableKey: key,
        );

        expect(outcome, JoinOutcome.joined);
        expect(seen?.method, 'POST');
        expect(
          seen?.url,
          Uri.parse('https://example.supabase.co/rest/v1/waitlist'),
        );
        expect(seen?.headers['apikey'], key);
        expect(seen?.headers['authorization'], 'Bearer $key');
        expect(seen?.headers['content-type'], startsWith('application/json'));
        expect(seen?.headers['prefer'], 'return=minimal');
        expect(jsonDecode(seen!.body), {
          'email': 'alice@example.com',
          'source': 'landing',
          'locale': 'en',
        });
      },
    );

    test('sends the language of the page, so the mail is in it', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('', 201);
      });

      final outcome = await joinWaitlist(
        client,
        email: 'anna@example.com',
        locale: .de,
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, JoinOutcome.joined);
      expect(jsonDecode(seen!.body), containsPair('locale', 'de'));
    });

    // Deploy order: the site can go live before the migration that adds
    // the column. PostgREST then answers 400 PGRST204 for the unknown key,
    // and the sign-up must still go through, in English, rather than tell
    // the reader their address was refused.
    test(
      'before the database knows the language, signs up without it',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((request) async {
          seen.add(request);
          final body = jsonDecode(request.body) as Map<String, Object?>;
          return body.containsKey('locale')
              ? http.Response(
                  '{"code":"PGRST204","details":null,"hint":null,'
                  '"message":"Could not find the \'locale\' column of '
                  '\'waitlist\' in the schema cache"}',
                  400,
                )
              : http.Response('', 201);
        });

        final outcome = await joinWaitlist(
          client,
          email: 'anna@example.com',
          locale: .de,
          supabaseUrl: supabase,
          publishableKey: key,
        );

        expect(outcome, JoinOutcome.joined);
        expect(seen, hasLength(2));
        expect(jsonDecode(seen.last.body), {
          'email': 'anna@example.com',
          'source': 'landing',
        });
      },
    );

    test('a 400 that is not JSON is a refusal, sent once', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response('Bad Request', 400);
      });

      final outcome = await joinWaitlist(
        client,
        email: 'anna@example.com',
        locale: .de,
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, JoinOutcome.rejected);
      expect(seen, hasLength(1));
    });

    test('any other 400 is a refusal, sent once', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        return http.Response(
          '{"code":"PGRST204","message":"Could not find the \'source\' '
          'column of \'waitlist\' in the schema cache"}',
          400,
        );
      });

      final outcome = await joinWaitlist(
        client,
        email: 'anna@example.com',
        locale: .de,
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, JoinOutcome.rejected);
      expect(seen, hasLength(1));
    });

    test('a 429 means the caller should wait', () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"PT429"}', 429),
      );
      final outcome = await joinWaitlist(
        client,
        email: 'a@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, JoinOutcome.tooMany);
    });

    test('a 400 means the address was refused', () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"23514"}', 400),
      );
      final outcome = await joinWaitlist(
        client,
        email: 'nope',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, JoinOutcome.rejected);
    });

    test('any other status is a failure the caller can retry', () async {
      final client = MockClient((_) async => http.Response('', 503));
      final outcome = await joinWaitlist(
        client,
        email: 'a@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, JoinOutcome.failed);
    });

    test('a network error is a failure, not an exception', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      final outcome = await joinWaitlist(
        client,
        email: 'a@example.com',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, JoinOutcome.failed);
    });
  });

  group('confirmWaitlist', () {
    // Shaped like a token, obviously not one (a secret scanner reads this).
    const token = '00000000-0000-4000-8000-000000000042';

    test('calls the confirm RPC with the token from the link', () async {
      http.Request? seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('true', 200);
      });

      final outcome = await confirmWaitlist(
        client,
        token: token,
        supabaseUrl: supabase,
        publishableKey: key,
      );

      expect(outcome, ConfirmOutcome.confirmed);
      expect(seen?.method, 'POST');
      expect(
        seen?.url,
        Uri.parse('https://example.supabase.co/rest/v1/rpc/confirm_waitlist'),
      );
      expect(seen?.headers['apikey'], key);
      expect(seen?.headers['authorization'], 'Bearer $key');
      expect(seen?.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(seen!.body), {'token': token});
    });

    test(
      'false means the link matched nothing (used, expired or made up)',
      () async {
        final client = MockClient((_) async => http.Response('false', 200));
        final outcome = await confirmWaitlist(
          client,
          token: token,
          supabaseUrl: supabase,
          publishableKey: key,
        );
        expect(outcome, ConfirmOutcome.unknown);
      },
    );

    test('a 400 (not even a token) is treated the same as unknown', () async {
      final client = MockClient(
        (_) async => http.Response('{"code":"22P02"}', 400),
      );
      final outcome = await confirmWaitlist(
        client,
        token: 'not-a-uuid',
        supabaseUrl: supabase,
        publishableKey: key,
      );
      expect(outcome, ConfirmOutcome.unknown);
    });

    test(
      'any other status or a network error is a retryable failure',
      () async {
        final down = MockClient((_) async => http.Response('', 503));
        final offline = MockClient(
          (_) async => throw http.ClientException('offline'),
        );
        for (final client in [down, offline]) {
          final outcome = await confirmWaitlist(
            client,
            token: token,
            supabaseUrl: supabase,
            publishableKey: key,
          );
          expect(outcome, ConfirmOutcome.failed);
        }
      },
    );
  });

  group('looksLikeEmail', () {
    test('accepts an ordinary address', () {
      expect(looksLikeEmail('peter@getemotely.com'), isTrue);
    });
    test('rejects text without an @ or a dot after it', () {
      expect(looksLikeEmail('peter'), isFalse);
      expect(looksLikeEmail('peter@localhost'), isFalse);
      expect(looksLikeEmail('@getemotely.com'), isFalse);
    });
    test('rejects surrounding spaces and empty input', () {
      expect(looksLikeEmail(''), isFalse);
      expect(looksLikeEmail('a b@example.com'), isFalse);
    });
  });
}
