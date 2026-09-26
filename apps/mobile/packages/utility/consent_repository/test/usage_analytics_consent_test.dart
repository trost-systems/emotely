import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

void main() {
  group(UsageAnalyticsConsent, () {
    const version = '2026-09-26';
    const recorded = {'version': version, 'purpose': 'usage_analytics'};

    /// The consent over [spy]'s gate and [supabase], as the app registers
    /// it, closed when the test ends.
    Future<UsageAnalyticsConsent> consentOver(
      AnalyticsSpy spy,
      SupabaseStub supabase,
    ) async {
      final consent = UsageAnalyticsConsent(
        gate: spy.gate,
        supabase: supabase.supabase,
        version: version,
        errors: spy.errorReporter,
      );
      addTearDown(consent.close);
      await consent.settled;
      return consent;
    }

    /// Lets the auth stream and the writes it sets off run out.
    Future<void> settle(UsageAnalyticsConsent consent) async {
      await pumpEventQueue();
      await consent.recorded;
    }

    group('on the device', () {
      test('allowing sets PostHog up and keeps the answer', () async {
        final spy = AnalyticsSpy(stored: null);
        final consent = await consentOver(spy, SupabaseStub());

        expect(consent.choice, isNull);

        final changes = expectLater(
          consent.changes,
          emits(AnalyticsChoice.allowed),
        );
        await consent.allow();
        await changes;

        expect(consent.choice, AnalyticsChoice.allowed);
        expect(spy.lifecycle, ['setup', 'reset']);
      });

      test('refusing switches PostHog off', () async {
        final spy = AnalyticsSpy();
        final consent = await consentOver(spy, SupabaseStub());

        await consent.deny();

        expect(consent.choice, AnalyticsChoice.denied);
        expect(spy.lifecycle, ['setup', 'disable', 'close']);
      });
    });

    group('on the server', () {
      test('records nothing while nobody is signed in', () async {
        final supabase = SupabaseStub();
        final consent = await consentOver(AnalyticsSpy(stored: null), supabase);

        await consent.allow();
        await settle(consent);

        expect(supabase.requests, isEmpty);
      });

      test('records an allow once someone signs in', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(false)])
          ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
        final consent = await consentOver(AnalyticsSpy(stored: null), supabase);
        await consent.allow();

        await supabase.signedIn();
        await settle(consent);

        expect(supabase.bodies('/rest/v1/rpc/consent_stands'), [recorded]);
        expect(supabase.bodies('/rest/v1/rpc/record_consent'), [recorded]);
      });

      test('records a choice made while signed in at once', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [
            rpcReturned(true),
            rpcReturned(true),
            rpcReturned(false),
          ])
          ..rest(usageAnalyticsWithdraw, [rpcReturned(null)])
          ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
        await supabase.signedIn();
        final consent = await consentOver(AnalyticsSpy(), supabase);
        await settle(consent);

        // Signed in and allowed, and the server agrees: nothing to write.
        expect(supabase.to(usageAnalyticsRead), hasLength(1));
        expect(supabase.to(usageAnalyticsGrant), isEmpty);

        await consent.deny();
        await consent.allow();
        await settle(consent);

        expect(supabase.to(usageAnalyticsRead), hasLength(3));
        expect(supabase.to(usageAnalyticsWithdraw), hasLength(1));
        expect(supabase.to(usageAnalyticsGrant), hasLength(1));
      });

      test('records a withdrawal', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(true), rpcReturned(true)])
          ..rest(usageAnalyticsWithdraw, [rpcReturned(null)]);
        await supabase.signedIn();
        final consent = await consentOver(AnalyticsSpy(), supabase);
        await settle(consent);

        await consent.deny();
        await settle(consent);

        expect(supabase.bodies('/rest/v1/rpc/withdraw_consent'), [recorded]);
      });

      test('records no refusal that was never a consent', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(false)]);
        await supabase.signedIn();
        final consent = await consentOver(
          AnalyticsSpy(stored: AnalyticsChoice.denied),
          supabase,
        );
        await settle(consent);

        // A refusal is the absence of a consent (ADR 0014), not a record.
        expect(supabase.to(usageAnalyticsRead), hasLength(1));
        expect(supabase.to(usageAnalyticsWithdraw), isEmpty);
      });

      test('asks nothing of a device where nobody has answered', () async {
        final supabase = SupabaseStub();
        await supabase.signedIn();
        final consent = await consentOver(AnalyticsSpy(stored: null), supabase);

        await settle(consent);

        expect(supabase.requests, isEmpty);
      });

      test(
        'asks once per sign-in, however often the session says so',
        () async {
          final supabase = SupabaseStub()
            ..rest(usageAnalyticsRead, [rpcReturned(true)]);
          await supabase.signedIn();
          final consent = await consentOver(AnalyticsSpy(), supabase);
          await settle(consent);

          await supabase.signedIn();
          await settle(consent);

          expect(supabase.to(usageAnalyticsRead), hasLength(1));
        },
      );

      test('asks again for whoever signs in next', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(true), rpcReturned(true)])
          ..rest(logout, [signedOut()]);
        await supabase.signedIn();
        final consent = await consentOver(AnalyticsSpy(), supabase);
        await settle(consent);

        await supabase.supabase.auth.signOut();
        await settle(consent);
        await supabase.signedIn();
        await settle(consent);

        expect(supabase.to(usageAnalyticsRead), hasLength(2));
      });

      test('shrugs off an error on the session stream', () async {
        final supabase = SupabaseStub();
        final consent = await consentOver(AnalyticsSpy(), supabase);
        await settle(consent);

        // A stored session that expired with no way to refresh it: the SDK
        // reports the failure on the stream, as it does a failed refresh.
        await expectLater(
          supabase.supabase.auth.recoverSession(
            jsonEncode({
              ...SupabaseStub.session(),
              'access_token': _expiredToken,
            }),
          ),
          throwsA(isA<AuthException>()),
        );
        await settle(consent);

        expect(supabase.requests, isEmpty);
      });

      test('reports a write that did not land, and never throws', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(false)])
          ..rest(usageAnalyticsGrant, [restRefused(statusCode: 400)]);
        await supabase.signedIn();
        final spy = AnalyticsSpy(stored: null);
        final consent = await consentOver(spy, supabase);
        await settle(consent);

        await consent.allow();
        await settle(consent);

        // The device obeys the choice all the same; the evidence lags.
        expect(consent.choice, AnalyticsChoice.allowed);
        expect(spy.exceptions, [
          captured(
            withheld(PostgrestApiException, code: 'XX000', statusCode: 400),
            {'step': 'usage_analytics_record'},
          ),
        ]);
      });
    });
  });
}

/// Where the SDK ends a session on the server.
const logout = 'POST /auth/v1/logout';

/// An access token whose `exp` is long past, shaped like the stub's own.
final _expiredToken = [
  {'alg': 'ES256', 'typ': 'JWT'},
  {'sub': SupabaseStub.userId, 'exp': 1},
].map(_segment).followedBy(['signature']).join('.');

String _segment(Map<String, Object> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
