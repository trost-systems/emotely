@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:emotely_web/components/waitlist_form.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

/// Runs [body] with every `http.Client()` the form creates answering
/// [status]; what the form sent is collected in [seen].
Future<void> withApi(
  Future<void> Function() body, {
  required List<http.Request> seen,
  int status = 201,
}) => http.runWithClient(
  body,
  () => MockClient((request) async {
    seen.add(request);
    return http.Response('', status);
  }),
);

/// A `window.posthog` that only remembers what it was asked to capture.
List<(String, Map<String, Object?>)> installPosthogStub() {
  final captured = <(String, Map<String, Object?>)>[];
  final stub = JSObject();
  stub['capture'] = ((JSString event, JSAny? properties) {
    final props = properties.dartify() as Map? ?? {};
    captured.add((event.toDart, props.cast<String, Object?>()));
  }).toJS;
  globalContext['posthog'] = stub;
  return captured;
}

void visit(String path) => web.window.history.replaceState(null, '', path);

void main() {
  group('WaitlistForm', () {
    setUp(() => visit('/'));

    testClient('a valid address is sent once and the reader is thanked', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(seen.single.body, contains('alice@example.com'));
        expect(find.textContaining('Check your inbox'), findsOneComponent);
        expect(find.byKey(const Key('join')), findsNothing);
      });
    });

    testClient('the link the reader came from is stored with the address', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      visit('/?utm_source=LinkedIn&utm_medium=post&utm_campaign=launch');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'dana@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(seen.single.body, contains('"source":"linkedin/post/launch"'));
        expect(captured.single.$1, 'waitlist_joined');
        expect(captured.single.$2, {'source': 'linkedin/post/launch'});
      });
    });

    testClient('an address that is not one never leaves the page', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      visit('/?utm_source=blog');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'not an address',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(
          find.textContaining("doesn't look like an email"),
          findsOneComponent,
        );
        expect(find.byKey(const Key('join')), findsOneComponent);
        expect(captured.single.$1, 'waitlist_refused');
        expect(captured.single.$2, {'source': 'blog', 'reason': 'invalid'});
      });
    });

    testClient('a rate-limited reader is told to come back later', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      await withApi(seen: seen, status: 429, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'bob@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(find.textContaining('Too many sign-ups'), findsOneComponent);
        expect(find.byKey(const Key('join')), findsOneComponent);
        expect(captured.single.$1, 'waitlist_refused');
        expect(captured.single.$2['reason'], 'tooMany');
      });
    });

    testClient('a failure invites a retry and keeps the form', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, status: 503, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'carol@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(find.textContaining('Something went wrong'), findsOneComponent);
        expect(find.byKey(const Key('join')), findsOneComponent);
      });
    });

    testClient('without PostHog on the page nothing breaks', (tester) async {
      globalContext.delete('posthog'.toJS);
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const WaitlistForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'erin@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(find.textContaining('Check your inbox'), findsOneComponent);
      });
    });

    testClient(
      'a bot that fills the hidden field gets a thank-you and nothing is sent',
      (tester) async {
        final seen = <http.Request>[];
        await withApi(seen: seen, () async {
          tester.pumpComponent(const WaitlistForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'bot@example.com',
          );
          await tester.input(
            find.byKey(const Key('website')),
            value: 'https://spam.example',
          );
          await tester.click(find.byKey(const Key('join')));
          await pumpEventQueue();

          expect(seen, isEmpty);
          expect(find.textContaining('Check your inbox'), findsOneComponent);
        });
      },
    );
  });

  group('WaitlistForm in German', () {
    setUp(() => visit('/de'));

    testClient('asks, refuses and thanks in German', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const WaitlistForm(lang: 'de'));

        expect(find.text('Frühen Zugang sichern'), findsOneComponent);
        expect(find.textContaining('schreib an'), findsOneComponent);

        await tester.input(
          find.byKey(const Key('email')),
          value: 'keine Adresse',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(
          find.textContaining('nicht nach einer E-Mail-Adresse'),
          findsOneComponent,
        );

        await tester.input(
          find.byKey(const Key('email')),
          value: 'frieda@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(
          find.textContaining('Schau in dein Postfach'),
          findsOneComponent,
        );
      });
    });

    testClient('says a refusal in German', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, status: 429, () async {
        tester.pumpComponent(const WaitlistForm(lang: 'de'));
        await tester.input(
          find.byKey(const Key('email')),
          value: 'gerd@example.com',
        );
        await tester.click(find.byKey(const Key('join')));
        await pumpEventQueue();

        expect(find.textContaining('zu viele Anmeldungen'), findsOneComponent);
      });
    });
  });
}
