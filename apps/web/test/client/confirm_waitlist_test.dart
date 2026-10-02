@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:emotely_web/components/confirm_waitlist.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

/// Shaped like a token, obviously not one (a secret scanner reads this).
const token = '00000000-0000-4000-8000-000000000042';

/// Runs [body] with every `http.Client()` the island creates answering
/// [status] and [reply]; what it sent is collected in [seen].
Future<void> withApi(
  Future<void> Function() body, {
  required List<http.Request> seen,
  int status = 200,
  String reply = 'true',
}) => http.runWithClient(
  body,
  () => MockClient((request) async {
    seen.add(request);
    return http.Response(reply, status);
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
  group('ConfirmWaitlist', () {
    testClient('the token in the link is redeemed and the reader is told', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      visit('/confirm?t=$token');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const ConfirmWaitlist());
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(seen.single.body, contains(token));
        expect(find.textContaining('Confirmed'), findsOneComponent);
        expect(captured.single.$1, 'waitlist_confirmed');
      });
    });

    testClient('a link that matches nothing says so, without a request loop', (
      tester,
    ) async {
      final seen = <http.Request>[];
      visit('/confirm?t=$token');
      await withApi(seen: seen, reply: 'false', () async {
        tester.pumpComponent(const ConfirmWaitlist());
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(find.textContaining('no longer valid'), findsOneComponent);
      });
    });

    testClient('no token in the link means no request at all', (tester) async {
      final seen = <http.Request>[];
      visit('/confirm');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const ConfirmWaitlist());
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(find.textContaining('no longer valid'), findsOneComponent);
      });
    });

    testClient('a failure invites a retry', (tester) async {
      final seen = <http.Request>[];
      visit('/confirm?t=$token');
      await withApi(seen: seen, status: 503, reply: '', () async {
        tester.pumpComponent(const ConfirmWaitlist());
        await pumpEventQueue();

        expect(find.textContaining('Something went wrong'), findsOneComponent);
      });
    });
  });

  group('ConfirmWaitlist in German', () {
    testClient('confirms in German', (tester) async {
      final seen = <http.Request>[];
      visit('/de/confirm?t=$token');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const ConfirmWaitlist(lang: 'de'));
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(find.textContaining('Bestätigt'), findsOneComponent);
      });
    });

    testClient('sends an invalid link back to the German sign-up', (
      tester,
    ) async {
      final seen = <http.Request>[];
      visit('/de/confirm');
      await withApi(seen: seen, () async {
        tester.pumpComponent(const ConfirmWaitlist(lang: 'de'));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(find.textContaining('nicht mehr gültig'), findsOneComponent);
        expect(
          find.byComponentPredicate(
            (component) =>
                component is DomComponent &&
                component.attributes?['href'] == '/de',
          ),
          findsOneComponent,
        );
      });
    });

    testClient('asks for a reload in German', (tester) async {
      final seen = <http.Request>[];
      visit('/de/confirm?t=$token');
      await withApi(seen: seen, status: 503, reply: '', () async {
        tester.pumpComponent(const ConfirmWaitlist(lang: 'de'));
        await pumpEventQueue();

        expect(find.textContaining('Lade diese Seite neu'), findsOneComponent);
      });
    });
  });
}
