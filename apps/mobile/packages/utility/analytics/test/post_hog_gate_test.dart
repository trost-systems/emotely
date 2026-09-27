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

      await gate.restore(account: null);
      await sendEverything(gate);

      expect(gate.choice, isNull);
      expect(spy.lifecycle, isEmpty);
      expect(spy.outgoingStrings, isEmpty);
    });

    test('never sets PostHog up after a refusal', () async {
      final spy = AnalyticsSpy(stored: AnalyticsChoice.denied);
      final gate = gateOver(spy);

      await gate.restore(account: null);
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

        await gate.restore(account: null);
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
        unawaited(gate.restore(account: null));
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
      await gate.restore(account: null);
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
      expect(await AnalyticsChoiceStore(preferences: spy.preferences).read(), (
        choice: AnalyticsChoice.allowed,
        account: null,
      ));
    });

    test('opts back in when the SDK remembers an earlier refusal', () async {
      final spy = AnalyticsSpy(stored: null)..optedOut = true;
      final gate = gateOver(spy);
      await gate.restore(account: null);

      await gate.allow();

      expect(spy.lifecycle, ['setup', 'enable', 'reset']);
    });

    test('a refusal switches PostHog off and drops everything after', () async {
      final spy = AnalyticsSpy();
      final gate = gateOver(spy);
      await gate.restore(account: null);

      await gate.deny();
      await sendEverything(gate);

      expect(gate.choice, AnalyticsChoice.denied);
      // No reset on the way out: a reset reloads flags over the network
      // under a fresh id, which is sending something after a refusal.
      expect(spy.lifecycle, ['setup', 'disable', 'close']);
      expect(spy.outgoingStrings, isEmpty);
      expect(await AnalyticsChoiceStore(preferences: spy.preferences).read(), (
        choice: AnalyticsChoice.denied,
        account: null,
      ));
    });

    test('a refusal before PostHog ever ran touches nothing', () async {
      final spy = AnalyticsSpy(stored: null);
      final gate = gateOver(spy);
      await gate.restore(account: null);

      await gate.deny();

      expect(spy.lifecycle, isEmpty);
    });

    test('allowing again after a refusal starts PostHog over', () async {
      final spy = AnalyticsSpy();
      final gate = gateOver(spy);
      await gate.restore(account: null);
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
      await gate.restore(account: null);
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
      await gate.restore(account: null);

      await gate.forget();

      expect(gate.choice, isNull);
      expect(spy.lifecycle, isEmpty);
    });

    group('whose the choice is', () {
      const alice = '00000000-0000-0000-0000-00000000000a';
      const bob = '00000000-0000-0000-0000-00000000000b';

      Future<StoredChoice?> stored(AnalyticsSpy spy) =>
          AnalyticsChoiceStore(preferences: spy.preferences).read();

      group('on launch', () {
        test('forgets the choice of someone whose session ended while the '
            'app was closed', () async {
          final spy = AnalyticsSpy(owner: alice);
          final gate = gateOver(spy);

          await gate.restore(account: null);
          await sendEverything(gate);

          expect(gate.choice, isNull);
          expect(spy.lifecycle, isEmpty);
          expect(spy.outgoingStrings, isEmpty);
          expect(await stored(spy), isNull);
        });

        test('forgets the choice of someone other than who is signed in, '
            'before anything is sent', () async {
          final spy = AnalyticsSpy(owner: alice);
          final gate = gateOver(spy);

          // Everything the restored session says queues behind the check.
          unawaited(gate.restore(account: bob));
          await Future.wait([
            gate.identify(userId: bob),
            gate.capture(eventName: 'journal_viewed'),
          ]);

          expect(gate.choice, isNull);
          expect(spy.lifecycle, isEmpty);
          expect(spy.outgoingStrings, isEmpty);
          expect(await stored(spy), isNull);
        });

        test('keeps the choice of whoever is signed in', () async {
          final spy = AnalyticsSpy(owner: alice);
          final gate = gateOver(spy);

          await gate.restore(account: alice);
          await gate.identify(userId: alice);

          expect(gate.choice, AnalyticsChoice.allowed);
          expect(spy.lifecycle, ['setup']);
          expect(spy.identified, [alice]);
        });

        test(
          'keeps a choice made before sign-up while nobody is signed in',
          () async {
            final spy = AnalyticsSpy();
            final gate = gateOver(spy);

            await gate.restore(account: null);

            expect(gate.choice, AnalyticsChoice.allowed);
            expect(spy.lifecycle, ['setup']);
            expect(await stored(spy), (
              choice: AnalyticsChoice.allowed,
              account: null,
            ));
          },
        );

        test(
          'gives a choice made before sign-up to whoever signed in',
          () async {
            final spy = AnalyticsSpy();
            final gate = gateOver(spy);

            await gate.restore(account: alice);

            expect(gate.choice, AnalyticsChoice.allowed);
            expect(spy.lifecycle, ['setup']);
            expect(await stored(spy), (
              choice: AnalyticsChoice.allowed,
              account: alice,
            ));
          },
        );

        test('asks again where an earlier build kept the choice without '
            'whose it was', () async {
          for (final account in [null, alice]) {
            final spy = AnalyticsSpy(stored: null);
            await spy.preferences.setString(
              AnalyticsChoiceStore.key,
              AnalyticsChoice.allowed.name,
            );
            final gate = gateOver(spy);

            await gate.restore(account: account);
            await sendEverything(gate);

            expect(gate.choice, isNull, reason: account);
            expect(spy.lifecycle, isEmpty, reason: account);
            expect(spy.outgoingStrings, isEmpty, reason: account);
            expect(
              await spy.preferences.getString(AnalyticsChoiceStore.key),
              isNull,
              reason: account,
            );
          }
        });
      });

      group('on a sign-in', () {
        test(
          'forgets the choice of someone else, and PostHog with it',
          () async {
            final spy = AnalyticsSpy(owner: alice);
            final gate = gateOver(spy);
            await gate.restore(account: alice);
            await gate.identify(userId: alice);

            final changes = expectLater(gate.changes, emits(isNull));
            await gate.signedInAs(bob);
            await changes;
            await gate.identify(userId: bob);
            await gate.capture(eventName: 'journal_viewed');

            expect(gate.choice, isNull);
            expect(spy.lifecycle, ['setup', 'reset', 'disable', 'close']);
            expect(spy.identified, [alice]);
            expect(spy.events, isEmpty);
            expect(await stored(spy), isNull);
          },
        );

        test('forgets the choice when nobody is signed in any more', () async {
          final spy = AnalyticsSpy(
            owner: alice,
            stored: AnalyticsChoice.denied,
          );
          final gate = gateOver(spy);
          await gate.restore(account: alice);

          await gate.signedInAs(null);

          expect(gate.choice, isNull);
          expect(await stored(spy), isNull);
        });

        test(
          'gives a choice made before sign-up to whoever signs in',
          () async {
            final spy = AnalyticsSpy();
            final gate = gateOver(spy);
            await gate.restore(account: null);

            await gate.signedInAs(alice);
            await gate.identify(userId: alice);

            expect(gate.choice, AnalyticsChoice.allowed);
            expect(spy.lifecycle, ['setup']);
            expect(spy.identified, [alice]);
            expect(await stored(spy), (
              choice: AnalyticsChoice.allowed,
              account: alice,
            ));
          },
        );

        test('leaves a choice made before sign-up alone while nobody signs '
            'in', () async {
          final spy = AnalyticsSpy();
          final gate = gateOver(spy);
          await gate.restore(account: null);

          await gate.signedInAs(null);

          expect(gate.choice, AnalyticsChoice.allowed);
          expect(await stored(spy), (
            choice: AnalyticsChoice.allowed,
            account: null,
          ));
        });

        test('keeps who signed out out of the next allow', () async {
          final spy = AnalyticsSpy(stored: null);
          final gate = gateOver(spy);
          await gate.restore(account: alice);
          await gate.identify(userId: alice);

          await gate.signedInAs(null);
          await gate.allow();

          expect(spy.identities, isEmpty);
        });
      });

      test(
        'an answer belongs to whoever is signed in when it is given',
        () async {
          final spy = AnalyticsSpy(stored: null);
          final gate = gateOver(spy);
          await gate.restore(account: null);

          await gate.allow();

          expect(await stored(spy), (
            choice: AnalyticsChoice.allowed,
            account: null,
          ));

          await gate.signedInAs(alice);
          await gate.deny();

          expect(await stored(spy), (
            choice: AnalyticsChoice.denied,
            account: alice,
          ));
        },
      );

      test('tells an account its choice, and no one else’s', () async {
        final spy = AnalyticsSpy(stored: null);
        final gate = gateOver(spy);
        await gate.restore(account: null);
        await gate.allow();

        // Nobody's yet: not an account's until one signs in and adopts it.
        expect(gate.choiceOf(alice), isNull);

        await gate.signedInAs(alice);

        expect(gate.choiceOf(alice), AnalyticsChoice.allowed);
        expect(gate.choiceOf(bob), isNull);
      });
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

      await gate.restore(account: null);
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
      await gate.restore(account: null);
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

    testWidgets('counts no screen before the allow itself', (tester) async {
      // What PostHog hears, in order: events through the injected
      // instance, screens off the platform channel the observer uses.
      final heard = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('posthog_flutter'),
        (call) async {
          if (call.method == 'screen') {
            final arguments = call.arguments as Map<Object?, Object?>;
            heard.add('screen ${arguments['screenName']}');
          }
          return null;
        },
      );
      final spy = AnalyticsSpy(stored: null);
      when(
        spy.posthog.capture(
          eventName: anyNamed('eventName'),
          properties: anyNamed('properties'),
        ),
      ).thenAnswer((invocation) async {
        heard.add(invocation.namedArguments[#eventName] as String);
      });
      final gate = gateOver(spy);
      await gate.restore(account: null);
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
      // Signed in already, so the allow tells PostHog who this is; a
      // screen comes up while it does.
      await gate.identify(userId: 'user-1');
      when(
        spy.posthog.identify(
          userId: anyNamed('userId'),
          userProperties: anyNamed('userProperties'),
          userPropertiesSetOnce: anyNamed('userPropertiesSetOnce'),
        ),
      ).thenAnswer((_) async {
        navigator.currentState!.pushNamed<void>('/during');
      });

      await gate.allow();
      await tester.pumpAndSettle();
      navigator.currentState!.pushNamed<void>('/after');
      await tester.pumpAndSettle();

      expect(heard, ['usage_analytics_allowed', 'screen /after']);
    });
  });
}
