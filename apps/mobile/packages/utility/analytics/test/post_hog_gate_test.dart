import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:testing/testing.dart';

void main() {
  group(PostHogGate, () {
    /// A gate over [spy] as `registerAnalytics` builds one, not yet
    /// restored: what `main` holds before it asks the store.
    PostHogGate gateOver(AnalyticsSpy spy) => PostHogGate(
      posthog: spy.posthog,
      config: PostHogConfig('phc_test'),
      store: AnalyticsChoiceStore(preferences: spy.preferences),
    );

    Future<void> sendEverything(PostHogGate gate) async {
      await gate.identify(userId: 'user-1');
      await gate.capture(eventName: 'journal_viewed');
      await gate.captureException(
        error: Exception('x'),
        stackTrace: StackTrace.empty,
      );
    }

    test('never sets PostHog up before anyone was asked', () async {
      final spy = AnalyticsSpy(stored: null);
      final gate = gateOver(spy);

      await gate.restore();
      await sendEverything(gate);

      expect(gate.choice, isNull);
      expect(spy.lifecycle, isEmpty);
      expect(spy.outgoingStrings, isEmpty);
    });

    test('never sets PostHog up after a refusal', () async {
      final spy = AnalyticsSpy(stored: AnalyticsChoice.denied);
      final gate = gateOver(spy);

      await gate.restore();
      await sendEverything(gate);

      expect(gate.choice, AnalyticsChoice.denied);
      expect(spy.lifecycle, isEmpty);
      expect(spy.outgoingStrings, isEmpty);
    });

    test(
      'sets PostHog up on launch once allowed, as the same person',
      () async {
        final spy = AnalyticsSpy();
        final gate = gateOver(spy);

        await gate.restore();
        await sendEverything(gate);

        expect(gate.choice, AnalyticsChoice.allowed);
        // No reset: the anonymous id carries over from the last launch.
        expect(spy.lifecycle, ['setup']);
        expect(spy.identified, ['user-1']);
        expect(spy.events, [event('journal_viewed')]);
        expect(spy.exceptions, hasLength(1));
      },
    );

    test(
      'holds calls made while it is being restored until it knows',
      () async {
        final spy = AnalyticsSpy();
        final gate = gateOver(spy);

        // What `main` avoids by awaiting, and a test harness relies on.
        unawaited(gate.restore());
        final sending = sendEverything(gate);

        expect(gate.choice, isNull, reason: 'not read yet');

        await gate.settled;

        expect(gate.choice, AnalyticsChoice.allowed);

        await sending;

        expect(spy.lifecycle, ['setup']);
        expect(spy.identified, ['user-1']);
        expect(spy.events, [event('journal_viewed')]);
      },
    );

    test('allowing sets PostHog up afresh and keeps the answer', () async {
      final spy = AnalyticsSpy(stored: null);
      final gate = gateOver(spy);
      await gate.restore();
      // Who is signed in is known before anyone allowed anything; it is
      // held on the device and told PostHog only once allowed.
      await gate.identify(
        userId: 'user-1',
        userProperties: {r'$internal_or_test_user': false},
      );

      final changes = expectLater(gate.changes, emits(AnalyticsChoice.allowed));
      await gate.allow();
      await changes;
      await gate.capture(eventName: 'journal_viewed');

      expect(gate.choice, AnalyticsChoice.allowed);
      // A reset first: whoever used the SDK on this device before starts
      // no thread into this consent.
      expect(spy.lifecycle, ['setup', 'reset']);
      expect(spy.identities, [
        identity('user-1', {r'$internal_or_test_user': false}),
      ]);
      // The allow itself is the first thing PostHog hears: the top of the
      // onboarding funnel, sent only ever by the allow that opened the gate.
      expect(spy.events, [
        event('usage_analytics_allowed'),
        event('journal_viewed'),
      ]);
      expect(
        await AnalyticsChoiceStore(preferences: spy.preferences).read(),
        AnalyticsChoice.allowed,
      );
    });

    test('opts back in when the SDK remembers an earlier refusal', () async {
      final spy = AnalyticsSpy(stored: null)..optedOut = true;
      final gate = gateOver(spy);
      await gate.restore();

      await gate.allow();

      expect(spy.lifecycle, ['setup', 'enable', 'reset']);
    });

    test('a refusal switches PostHog off and drops everything after', () async {
      final spy = AnalyticsSpy();
      final gate = gateOver(spy);
      await gate.restore();

      await gate.deny();
      await sendEverything(gate);

      expect(gate.choice, AnalyticsChoice.denied);
      // No reset on the way out: a reset reloads flags over the network
      // under a fresh id, which is sending something after a refusal.
      expect(spy.lifecycle, ['setup', 'disable', 'close']);
      expect(spy.outgoingStrings, isEmpty);
      expect(
        await AnalyticsChoiceStore(preferences: spy.preferences).read(),
        AnalyticsChoice.denied,
      );
    });

    test('a refusal before PostHog ever ran touches nothing', () async {
      final spy = AnalyticsSpy(stored: null);
      final gate = gateOver(spy);
      await gate.restore();

      await gate.deny();

      expect(spy.lifecycle, isEmpty);
    });

    test('allowing again after a refusal starts PostHog over', () async {
      final spy = AnalyticsSpy();
      final gate = gateOver(spy);
      await gate.restore();
      await gate.identify(userId: 'user-1');
      await gate.deny();

      await gate.allow();
      await gate.capture(eventName: 'journal_viewed');

      expect(spy.lifecycle, [
        'setup',
        'disable',
        'close',
        'setup',
        'enable',
        'reset',
      ]);
      expect(spy.identified, ['user-1', 'user-1']);
      expect(spy.events, [
        event('usage_analytics_allowed'),
        event('journal_viewed'),
      ]);
    });

    test('forgetting resets PostHog, switches it off and asks again', () async {
      final spy = AnalyticsSpy();
      final gate = gateOver(spy);
      await gate.restore();
      await gate.identify(userId: 'user-1');

      final changes = expectLater(gate.changes, emits(isNull));
      await gate.forget();
      await changes;
      await gate.capture(eventName: 'after_sign_out');

      expect(gate.choice, isNull);
      expect(spy.lifecycle, ['setup', 'reset', 'disable', 'close']);
      expect(spy.events, isEmpty);
      expect(
        await AnalyticsChoiceStore(preferences: spy.preferences).read(),
        isNull,
      );

      // The next person to allow starts without the last one's identity.
      await gate.allow();
      await gate.capture(eventName: 'journal_viewed');

      expect(spy.identified, ['user-1']);
      expect(spy.events, [
        event('usage_analytics_allowed'),
        event('journal_viewed'),
      ]);
    });

    test('forgetting while nothing runs only forgets the answer', () async {
      final spy = AnalyticsSpy(stored: AnalyticsChoice.denied);
      final gate = gateOver(spy);
      await gate.restore();

      await gate.forget();

      expect(gate.choice, isNull);
      expect(spy.lifecycle, isEmpty);
    });

    test('never throws when PostHog does', () async {
      final spy = AnalyticsSpy();
      final refusal = PlatformException(code: 'posthog');
      when(
        spy.posthog.capture(
          eventName: anyNamed('eventName'),
          properties: anyNamed('properties'),
        ),
      ).thenThrow(refusal);
      when(spy.posthog.disable()).thenThrow(refusal);
      final gate = gateOver(spy);

      await gate.restore();
      await gate.capture(eventName: 'journal_viewed');
      await gate.deny();

      // A refusal is kept even when the SDK would not switch off.
      expect(gate.choice, AnalyticsChoice.denied);
    });

    testWidgets('counts screens only while allowed', (tester) async {
      // The observer reaches the native SDK itself, past the injected
      // instance, so what it sends is read off the platform channel.
      final screens = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('posthog_flutter'),
        (call) async {
          if (call.method == 'screen') {
            screens.add(
              (call.arguments as Map<Object?, Object?>)['screenName'],
            );
          }
          return null;
        },
      );
      final spy = AnalyticsSpy(stored: null);
      final gate = gateOver(spy);
      await gate.restore();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          navigatorKey: navigator,
          navigatorObservers: [gate.screenObserver()],
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
      );

      navigator.currentState!.pushNamed<void>('/before');
      await tester.pumpAndSettle();
      await gate.allow();
      navigator.currentState!.pushNamed<void>('/after');
      await tester.pumpAndSettle();

      expect(screens, ['/after']);
    });
  });
}
