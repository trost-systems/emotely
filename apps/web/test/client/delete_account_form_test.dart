@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:emotely_web/components/delete_account_form.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

/// Shaped like an access token, obviously not one (a secret scanner reads
/// this): three dot-separated segments, no signature over anything.
const accessToken = 'header.payload.not-a-signature';

/// Runs [body] with every `http.Client()` the island creates answered by
/// [handler]; what it sent is collected in [seen].
Future<void> withApi(
  Future<void> Function() body, {
  required List<http.Request> seen,
  Future<http.Response> Function(http.Request)? handler,
}) => http.runWithClient(
  body,
  () => MockClient((request) async {
    seen.add(request);
    if (handler != null) {
      return await handler(request);
    }
    return switch (request.url.path) {
      // A code was sent.
      '/auth/v1/otp' => http.Response('{}', 200),
      '/auth/v1/verify' => http.Response(
        jsonEncode({'access_token': accessToken}),
        200,
      ),
      // `delete_account()` reports that a row really went.
      _ => http.Response('true', 200),
    };
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

/// Stands in for Cloudflare's `window.turnstile`: hands out numbered
/// tokens on `execute`, or fails every check when [fails] is set, and
/// remembers how each widget was rendered and how many were removed.
class TurnstileStub() {
  final rendered = <JSObject>[];
  var removed = 0;
  var fails = false;

  /// Installs this stub as `window.turnstile`, as the script would.
  void install() {
    final api = JSObject();
    api['render'] = ((JSString container, JSObject params) {
      rendered.add(params);
      return 'widget-${rendered.length}'.toJS;
    }).toJS;
    api['execute'] = ((JSString widget) {
      final params = rendered.last;
      if (fails) {
        params
            .getProperty<JSFunction>('error-callback'.toJS)
            .callAsFunction(null, '300010'.toJS);
      } else {
        params
            .getProperty<JSFunction>('callback'.toJS)
            .callAsFunction(null, 'turnstile-token-${rendered.length}'.toJS);
      }
    }).toJS;
    api['remove'] = ((JSString widget) {
      removed++;
    }).toJS;
    globalContext['turnstile'] = api;
  }

  /// The option [name] the latest widget was rendered with.
  String? option(String name) =>
      rendered.last.getProperty<JSString?>(name.toJS)?.toDart;
}

/// The human check a request carried, as GoTrue reads it.
Object? captchaOf(http.Request request) =>
    (jsonDecode(request.body) as Map)['gotrue_meta_security'];

void main() {
  late TurnstileStub turnstile;

  setUp(() {
    turnstile = TurnstileStub()..install();
    addTearDown(() => globalContext.delete('turnstile'.toJS));
  });

  group('DeleteAccountForm', () {
    testClient('runs the human check only when a code is asked for', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );

        expect(turnstile.rendered, isEmpty);

        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(turnstile.rendered, hasLength(1));
        // Invisible unless Cloudflare wants an interaction, run on submit.
        expect(turnstile.option('execution'), 'execute');
        expect(turnstile.option('appearance'), 'interaction-only');
        expect(turnstile.option('language'), 'en');
        expect(turnstile.option('sitekey'), isNotEmpty);
        expect(captchaOf(seen.single), {'captcha_token': 'turnstile-token-1'});
        // Single use: the widget goes once its token is spent.
        expect(turnstile.removed, 1);
      });
    });

    testClient('a failed human check sends nothing and offers a retry', (
      tester,
    ) async {
      final seen = <http.Request>[];
      turnstile.fails = true;
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(find.textContaining('Something went wrong'), findsOneComponent);
        expect(find.byKey(const Key('send-code')), findsOneComponent);
        expect(turnstile.removed, 1);
      });
    });

    testClient('a retry after a refused check carries a fresh token', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(
        seen: seen,
        handler: (_) async => seen.length == 1
            ? http.Response('{"error_code":"captcha_failed"}', 400)
            : http.Response('{}', 200),
        () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();

          expect(
            find.textContaining('Something went wrong'),
            findsOneComponent,
          );

          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();

          expect(seen.map(captchaOf), [
            {'captcha_token': 'turnstile-token-1'},
            {'captcha_token': 'turnstile-token-2'},
          ]);
          expect(find.textContaining('has an account'), findsOneComponent);
        },
      );
    });

    testClient(
      "loads Cloudflare's script on the first request, and fails without it",
      (tester) async {
        final seen = <http.Request>[];
        globalContext.delete('turnstile'.toJS);
        // What the page appends to <head> is kept here instead, so no
        // request ever reaches Cloudflare from a test.
        final appended = <web.Element>[];
        final head = web.document.head!;
        head['append'] = appended.add.toJS;
        addTearDown(() => head.delete('append'.toJS));
        await withApi(seen: seen, () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );

          expect(appended, isEmpty);

          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();

          expect(
            appended.single.getAttribute('src'),
            'https://challenges.cloudflare.com/turnstile/v0/api.js'
            '?render=explicit',
          );
          expect(seen, isEmpty);

          // Blocked or offline: the check fails, and no code is asked for.
          appended.single.dispatchEvent(web.Event('error'));
          await pumpEventQueue();

          expect(seen, isEmpty);
          expect(
            find.textContaining('Something went wrong'),
            findsOneComponent,
          );
        });
      },
    );

    testClient('waits for a script already on its way, then checks', (
      tester,
    ) async {
      final seen = <http.Request>[];
      globalContext.delete('turnstile'.toJS);
      // The script an earlier click added, still loading. As text/plain it
      // fetches nothing, so the test decides when it has "loaded".
      final loading = web.document.createElement('script')
        ..setAttribute('type', 'text/plain')
        ..setAttribute(
          'src',
          'https://challenges.cloudflare.com/turnstile/v0/api.js'
              '?render=explicit',
        );
      web.document.head!.append(loading);
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(
          web.document.querySelectorAll('script[src*="challenges"]').length,
          1,
        );

        // What the script does once it ran: `window.turnstile` exists.
        turnstile.install();
        loading.dispatchEvent(web.Event('load'));
        await pumpEventQueue();

        expect(captchaOf(seen.single), {'captcha_token': 'turnstile-token-1'});
      });
      loading.remove();
    });

    testClient('asks for a code, then deletes with the code', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(seen, hasLength(1));
        expect(seen.single.url.path, '/auth/v1/otp');
        // Never sign anybody up on the way to deleting them.
        expect(
          jsonDecode(seen.single.body),
          containsPair('create_user', false),
        );
        expect(find.textContaining('has an account'), findsOneComponent);

        await tester.input(find.byKey(const Key('code')), value: '123456');
        await tester.input(find.byKey(const Key('understood')), checked: true);
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(seen, hasLength(3));
        expect(seen[1].url.path, '/auth/v1/verify');
        expect(seen[2].url.path, '/rest/v1/rpc/delete_account');
        expect(seen[2].headers['authorization'], 'Bearer $accessToken');
        expect(find.textContaining('account is gone'), findsOneComponent);
      });
    });

    testClient('an address with no account looks exactly like one that has', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      await withApi(
        seen: seen,
        handler: (_) async =>
            http.Response('{"error_code":"otp_disabled"}', 422),
        () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'nobody@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();

          // The same screen a real account gets: no enumeration oracle.
          expect(find.textContaining('has an account'), findsOneComponent);
          expect(find.byKey(const Key('code')), findsOneComponent);
          // ...and nothing in analytics gives it away either.
          expect(
            captured.map((event) => event.$1),
            everyElement(isNot(contains('unknown'))),
          );
        },
      );
    });

    testClient('a malformed address never reaches the network', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(find.byKey(const Key('email')), value: 'nope');
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(find.textContaining("doesn't look like"), findsOneComponent);
        // A screen reader is told without having to be moved there.
        final alert = tester.findNode<web.HTMLElement>(
          find.byKey(const Key('message')),
        );
        expect(alert?.getAttribute('role'), 'alert');
      });
    });

    testClient('the irreversible step is gated by an explicit consent', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();
        await tester.input(find.byKey(const Key('code')), value: '123456');
        // Straight to delete, without ticking the box.
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        // Only the code request went out; nothing was deleted.
        expect(seen, hasLength(1));
        expect(find.textContaining('cannot be undone'), findsComponents);
        expect(find.textContaining('account is gone'), findsNothing);

        await tester.input(find.byKey(const Key('understood')), checked: true);
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(seen, hasLength(3));
        expect(find.textContaining('account is gone'), findsOneComponent);
      });
    });

    testClient('a pasted code keeps its spaces off the shape check', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();
        // How a mail app hands it over.
        await tester.input(find.byKey(const Key('code')), value: '12 34 56');
        await tester.input(find.byKey(const Key('understood')), checked: true);
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(seen, hasLength(3));
        expect(jsonDecode(seen[1].body), containsPair('token', '123456'));
        expect(find.textContaining('account is gone'), findsOneComponent);
      });
    });

    testClient('start over returns to the address step', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'typo@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();
        expect(find.byKey(const Key('code')), findsOneComponent);

        await tester.click(find.byKey(const Key('start-over')));
        await pumpEventQueue();

        // Back to the address field, with nothing deleted on the way.
        expect(find.byKey(const Key('email')), findsOneComponent);
        expect(find.byKey(const Key('code')), findsNothing);
        expect(seen, hasLength(1));
      });
    });

    testClient('a bot that fills every field is thanked, not obeyed', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.input(
          find.byKey(const Key('website')),
          value: 'https://spam.example',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        // No request at all: the honeypot answers without touching GoTrue.
        expect(seen, isEmpty);
      });
    });

    testClient('a wrong code says so and keeps the account', (tester) async {
      final seen = <http.Request>[];
      await withApi(
        seen: seen,
        handler: (request) async => request.url.path == '/auth/v1/otp'
            ? http.Response('{}', 200)
            : http.Response('{"error_code":"otp_expired"}', 403),
        () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();
          await tester.input(find.byKey(const Key('code')), value: '000000');
          await tester.input(
            find.byKey(const Key('understood')),
            checked: true,
          );
          await tester.click(find.byKey(const Key('delete')));
          await pumpEventQueue();

          // The code request and the refused verify; no deletion followed.
          expect(seen, hasLength(2));
          expect(
            seen.map((request) => request.url.path),
            isNot(contains('/rest/v1/rpc/delete_account')),
          );
          expect(find.textContaining('did not match'), findsOneComponent);
          expect(find.textContaining('account is gone'), findsNothing);
          // Still on the code step, so the reader can try the right code.
          expect(find.byKey(const Key('code')), findsOneComponent);
        },
      );
    });

    testClient('a six-digit check keeps a typo off the network', (
      tester,
    ) async {
      final seen = <http.Request>[];
      await withApi(
        seen: seen,
        handler: (_) async => http.Response('{}', 200),
        () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();
          await tester.input(find.byKey(const Key('code')), value: '12345');
          await tester.input(
            find.byKey(const Key('understood')),
            checked: true,
          );
          await tester.click(find.byKey(const Key('delete')));
          await pumpEventQueue();

          // Only the code request went out; the short code never did.
          expect(seen, hasLength(1));
          expect(find.textContaining('six digits'), findsOneComponent);
        },
      );
    });

    testClient('a rate limit asks the reader to wait', (tester) async {
      final seen = <http.Request>[];
      await withApi(
        seen: seen,
        handler: (_) async => http.Response('', 429),
        () async {
          tester.pumpComponent(const DeleteAccountForm());
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();

          expect(find.textContaining('Too many'), findsOneComponent);
        },
      );
    });

    testClient('what it reports to analytics carries no address or code', (
      tester,
    ) async {
      final seen = <http.Request>[];
      final captured = installPosthogStub();
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm());
        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();
        await tester.input(find.byKey(const Key('code')), value: '123456');
        await tester.input(find.byKey(const Key('understood')), checked: true);
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(captured, isNotEmpty);
        final wire = captured
            .map((event) => '${event.$1} ${jsonEncode(event.$2)}')
            .join('\n');
        expect(wire, isNot(contains('alice')));
        expect(wire, isNot(contains('example.com')));
        expect(wire, isNot(contains('123456')));
        expect(wire, isNot(contains(accessToken)));
      });
    });
  });

  group('DeleteAccountForm in German', () {
    testClient('walks the same steps in German', (tester) async {
      final seen = <http.Request>[];
      await withApi(seen: seen, () async {
        tester.pumpComponent(const DeleteAccountForm(lang: 'de'));

        expect(find.text('Schick mir einen Code'), findsOneComponent);

        await tester.input(find.byKey(const Key('email')), value: 'nein');
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        expect(seen, isEmpty);
        expect(
          find.textContaining('nicht nach einer E-Mail-Adresse'),
          findsOneComponent,
        );

        await tester.input(
          find.byKey(const Key('email')),
          value: 'alice@example.com',
        );
        await tester.click(find.byKey(const Key('send-code')));
        await pumpEventQueue();

        // Cloudflare's check speaks the page's language, if it ever speaks.
        expect(turnstile.option('language'), 'de');
        // Conditional, as in English: no enumeration oracle in any language.
        expect(
          find.textContaining('Wenn zu dieser Adresse ein Konto gehört'),
          findsOneComponent,
        );

        await tester.input(find.byKey(const Key('code')), value: '123456');
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(
          find.textContaining('Setz zuerst das Häkchen'),
          findsOneComponent,
        );

        await tester.input(find.byKey(const Key('understood')), checked: true);
        await tester.click(find.byKey(const Key('delete')));
        await pumpEventQueue();

        expect(seen, hasLength(3));
        expect(find.text('Dein Konto ist gelöscht'), findsOneComponent);
      });
    });

    testClient('says a wrong code in German', (tester) async {
      final seen = <http.Request>[];
      await withApi(
        seen: seen,
        handler: (request) async => switch (request.url.path) {
          '/auth/v1/verify' => http.Response('{}', 403),
          _ => http.Response('{}', 200),
        },
        () async {
          tester.pumpComponent(const DeleteAccountForm(lang: 'de'));
          await tester.input(
            find.byKey(const Key('email')),
            value: 'alice@example.com',
          );
          await tester.click(find.byKey(const Key('send-code')));
          await pumpEventQueue();
          await tester.input(find.byKey(const Key('code')), value: '654321');
          await tester.input(
            find.byKey(const Key('understood')),
            checked: true,
          );
          await tester.click(find.byKey(const Key('delete')));
          await pumpEventQueue();

          expect(
            find.textContaining('Dieser Code passt nicht'),
            findsOneComponent,
          );
          expect(
            find.text('Mit einer anderen Adresse neu beginnen'),
            findsOneComponent,
          );
        },
      );
    });
  });
}
