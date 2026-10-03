import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_check/human_check.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'web_view_fake.dart';

const _channel = 'EmotelyHumanCheck';
const _siteKey = '0x4AAAAAAA-site-key';
final _origin = Uri.parse('https://getemotely.com/');

/// What the challenge page posts for [kind].
String _report(String kind, [String value = '']) =>
    jsonEncode({'kind': kind, 'value': value});

Finder get _webView => find.byKey(const Key('fake_web_view'));

bool _takesTaps(WidgetTester tester) => !tester
    .widget<IgnorePointer>(
      find.ancestor(of: _webView, matching: find.byType(IgnorePointer)).first,
    )
    .ignoring;

/// Mounts a host for [challenges] over an empty screen.
Future<void> _host(WidgetTester tester, TurnstileChallenges challenges) =>
    // No Directionality above it, as in `main` and the live smoke.
    tester.pumpWidget(
      TurnstileHost(challenges: challenges, child: const SizedBox.expand()),
    );

void main() {
  group(TurnstileChallenges, () {
    testWidgets('loads the widget under the origin and answers its token', (
      tester,
    ) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);

      final token = challenges.token();

      await tester.pump();
      final view = web.last;

      expect(view.baseUrl, 'https://getemotely.com/');
      expect(view.javaScriptMode, JavaScriptMode.unrestricted);
      expect(view.background, const Color(0x00000000));
      expect(view.html, contains('sitekey: "$_siteKey"'));
      expect(
        view.html,
        contains('challenges.cloudflare.com/turnstile/v0/api.js'),
      );
      expect(view.html, contains("appearance: 'interaction-only'"));
      expect(_webView, findsOneWidget);
      // Invisible and out of the way unless Cloudflare asks for more.
      expect(_takesTaps(tester), isFalse);

      view.post(_channel, _report('token', 'turnstile-token'));
      await tester.pump();

      expect(await token, 'turnstile-token');
      await tester.pump();
      expect(_webView, findsNothing);
    });

    testWidgets('a check that asks for an interaction takes taps', (
      tester,
    ) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final token = challenges.token();
      await tester.pump();

      web.last.post(_channel, _report('interactive'));
      await tester.pump();

      expect(_takesTaps(tester), isTrue);
      // The quiet deadline no longer applies once the user is asked.
      await tester.pump(const Duration(minutes: 1));
      web.last.post(_channel, _report('token', 'after-a-tap'));
      expect(await token, 'after-a-tap');
    });

    testWidgets('an error the widget reports fails the check', (tester) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final token = challenges.token();
      await tester.pump();

      web.last.post(_channel, _report('error', '300010'));

      await expectLater(token, throwsA(isA<HumanCheckFailed>()));
      await tester.pump();
      expect(_webView, findsNothing);
    });

    testWidgets('an empty token or a garbled report fails the check', (
      tester,
    ) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);

      for (final report in [_report('token'), 'not json', '{"kind": 1}']) {
        final token = challenges.token();
        await tester.pump();
        web.last.post(_channel, report);
        await expectLater(token, throwsA(isA<HumanCheckFailed>()));
      }
    });

    testWidgets('a check that never answers fails after its patience', (
      tester,
    ) async {
      WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final token = challenges.token();
      await tester.pump();
      final failed = expectLater(token, throwsA(isA<HumanCheckFailed>()));

      await tester.pump(const Duration(seconds: 31));

      await failed;
    });

    testWidgets('an interaction left undone fails after its own patience', (
      tester,
    ) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final token = challenges.token();
      await tester.pump();
      final failed = expectLater(token, throwsA(isA<HumanCheckFailed>()));

      web.last.post(_channel, _report('interactive'));
      await tester.pump(const Duration(minutes: 3, seconds: 1));

      await failed;
    });

    testWidgets('a newer check supersedes one still running', (tester) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final first = challenges.token();
      await tester.pump();
      final superseded = expectLater(first, throwsA(isA<HumanCheckFailed>()));

      final second = challenges.token();

      await tester.pump();
      web.last.post(_channel, _report('token', 'second'));

      await superseded;
      expect(await second, 'second');
      expect(web.views, hasLength(2));
    });

    testWidgets('without a host there is no check to run', (tester) async {
      WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );

      await expectLater(challenges.token(), throwsA(isA<HumanCheckFailed>()));
    });

    testWidgets('a host that goes away fails the check it showed', (
      tester,
    ) async {
      WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final token = challenges.token();
      await tester.pump();
      final failed = expectLater(token, throwsA(isA<HumanCheckFailed>()));

      await tester.pumpWidget(const SizedBox());

      await failed;
      await expectLater(challenges.token(), throwsA(isA<HumanCheckFailed>()));
    });

    testWidgets('guards a call as the human check token source', (
      tester,
    ) async {
      final web = WebViewFake.install();
      final challenges = TurnstileChallenges(
        siteKey: _siteKey,
        origin: _origin,
      );
      await _host(tester, challenges);
      final check = HumanCheck(challenges.token);

      final call = check.guard((token) async => 'called with $token');
      await tester.pump();
      web.last.post(_channel, _report('token', 'fresh'));

      expect(await call, 'called with fresh');
    });
  });
}
