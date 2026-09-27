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
      SupabaseStub supabase, {
      PostHogGate? gate,
    }) async {
      final consent = UsageAnalyticsConsent(
        gate: gate ?? spy.gate,
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
        // The next person answers the question for themselves first.
        await consent.allow();
        await supabase.signedIn();
        await settle(consent);

        expect(supabase.to(usageAnalyticsRead), hasLength(2));
      });

      test('forgets the choice when a session ends, however it ends', () async {
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(true)])
          ..rest(logout, [signedOut()]);
        await supabase.signedIn();
        final spy = AnalyticsSpy();
        final consent = await consentOver(spy, supabase);
        await settle(consent);

        // Nobody asked for this sign-out: an expiry, a revoked refresh
        // token or an account deleted elsewhere end the session the same
        // way, through the SDK.
        await supabase.supabase.auth.signOut();
        await settle(consent);
        await consent.settled;

        expect(consent.choice, isNull);
        expect(spy.lifecycle, ['setup', 'reset', 'disable', 'close']);
      });

      test('never records the last person’s choice for the next', () async {
        const next = '00000000-0000-0000-0000-00000000000b';
        final supabase = SupabaseStub()
          ..rest(usageAnalyticsRead, [rpcReturned(true), rpcReturned(false)])
          ..rest(usageAnalyticsGrant, [rpcReturned(null)])
          ..rest(logout, [signedOut()]);
        await supabase.signedIn();
        final consent = await consentOver(AnalyticsSpy(), supabase);
        await settle(consent);

        // The session ends, and someone else signs in straight away,
        // before anything else happens on the device.
        await supabase.supabase.auth.signOut();
        await supabase.supabase.auth.recoverSession(
          jsonEncode(SupabaseStub.session(sub: next)),
        );
        await settle(consent);

        expect(supabase.to(usageAnalyticsRead), hasLength(1));
        expect(supabase.to(usageAnalyticsGrant), isEmpty);
      });

      test(
        'forgets the choice when another account replaces the session',
        () async {
          const next = '00000000-0000-0000-0000-00000000000b';
          final supabase = SupabaseStub()
            ..rest(usageAnalyticsRead, [rpcReturned(true), rpcReturned(false)])
            ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
          await supabase.signedIn();
          final consent = await consentOver(AnalyticsSpy(), supabase);
          await settle(consent);

          await supabase.supabase.auth.recoverSession(
            jsonEncode(SupabaseStub.session(sub: next)),
          );
          await settle(consent);

          expect(consent.choice, isNull);
          expect(supabase.to(usageAnalyticsGrant), isEmpty);
        },
      );

      group('whose the choice is (#216)', () {
        const alice = '00000000-0000-0000-0000-00000000000c';

        /// A gate over [spy] restored the way `main` restores it: over the
        /// session Supabase kept, whoever that is.
        PostHogGate launchedOver(AnalyticsSpy spy, SupabaseStub supabase) =>
            spy.launchedAs(supabase.supabase.auth.currentUser?.id);

        test('a choice made before sign-up becomes the account’s that '
            'signs in, and is recorded for it', () async {
          final supabase = SupabaseStub()
            ..rest(usageAnalyticsRead, [rpcReturned(false)])
            ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
          final spy = AnalyticsSpy(stored: null);
          final consent = await consentOver(spy, supabase);
          await consent.allow();

          await supabase.signedIn();
          await settle(consent);

          expect(supabase.bodies('/rest/v1/rpc/record_consent'), [recorded]);
          expect(
            await AnalyticsChoiceStore(preferences: spy.preferences).read(),
            (choice: AnalyticsChoice.allowed, account: SupabaseStub.userId),
          );
        });

        test('never records the choice of someone whose session ended while '
            'the app was closed', () async {
          final supabase = SupabaseStub();
          // Launched signed out, with the last person's allow on the device.
          final spy = AnalyticsSpy(owner: alice);
          final consent = await consentOver(
            spy,
            supabase,
            gate: launchedOver(spy, supabase),
          );

          expect(consent.choice, isNull);

          await supabase.signedIn();
          await settle(consent);

          expect(consent.choice, isNull);
          expect(supabase.requests, isEmpty);
          expect(spy.lifecycle, isEmpty);
        });

        test('never records the choice of another account the app launches '
            'signed in as', () async {
          final supabase = SupabaseStub();
          await supabase.signedIn();
          final spy = AnalyticsSpy(owner: alice);
          final consent = await consentOver(
            spy,
            supabase,
            gate: launchedOver(spy, supabase),
          );
          await settle(consent);

          expect(consent.choice, isNull);
          expect(supabase.requests, isEmpty);
          expect(spy.lifecycle, isEmpty);
        });

        test('records the choice of the account the app launches signed in '
            'as', () async {
          final supabase = SupabaseStub()
            ..rest(usageAnalyticsRead, [rpcReturned(false)])
            ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
          await supabase.signedIn();
          final spy = AnalyticsSpy(owner: SupabaseStub.userId);
          final consent = await consentOver(
            spy,
            supabase,
            gate: launchedOver(spy, supabase),
          );
          await settle(consent);

          expect(consent.choice, AnalyticsChoice.allowed);
          expect(supabase.bodies('/rest/v1/rpc/record_consent'), [recorded]);
        });
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
