import 'package:agent_client/agent_client.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:testing/testing.dart';

void main() {
  group(ConfigClient, () {
    test('reads the minimum and the store link the server serves', () async {
      final stub = ConfigStub()
        ..serves(minAppVersion: '2.1.0', storeUrl: 'https://store.test/x');

      final config = await stub.configClient.fetch();

      expect(config.minAppVersion, '2.1.0');
      expect(config.storeUrl, 'https://store.test/x');
    });

    test('asks for the store link of its own platform', () async {
      final stub = ConfigStub()
        ..platform = 'android'
        ..serves();

      await stub.configClient.fetch();

      expect(stub.requested.single.queryParameters['platform'], 'android');
    });

    testWidgets('names the platform the framework is running as', (
      tester,
    ) async {
      // The point of `defaultTargetPlatform` over `dart:io`: a variant drives
      // it, so this covers the real default rather than an injected string.
      final stub = ConfigStub()..serves();
      final client = ConfigClient(
        httpClient: stub.client,
        endpoint: ConfigStub.endpoint,
      );

      await client.fetch();

      expect(
        stub.requested.single.queryParameters['platform'],
        switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => 'unknown',
        },
      );
    }, variant: TargetPlatformVariant.all());

    test('keeps any query the endpoint already carried', () async {
      final stub = ConfigStub()..serves();
      final client = ConfigClient(
        httpClient: stub.client,
        endpoint: Uri.parse('https://agent.test/api/config?trace=1'),
        platform: 'ios',
      );

      await client.fetch();

      expect(stub.requested.single.queryParameters, {
        'trace': '1',
        'platform': 'ios',
      });
    });

    test('says when the server could not be reached at all', () async {
      // The app tells "check your connection" apart from "the server is
      // wrong" by this, never by the message, which is for error tracking.
      final stub = ConfigStub()..script([configUnreachable()]);

      await expectLater(
        stub.configClient.fetch(),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.unreachable,
            'unreachable',
            isTrue,
          ),
        ),
      );
    });

    test('an answer it cannot use is not unreachable', () async {
      final stub = ConfigStub()..script([configRefused(503)]);

      await expectLater(
        stub.configClient.fetch(),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.unreachable,
            'unreachable',
            isFalse,
          ),
        ),
      );
    });

    test('keeps the original stack trace when the transport fails', () async {
      // The trace names the socket layer that gave up; it is the only clue a
      // report of this carries, and it is content-free (ADR 0005).
      final stub = ConfigStub()..script([configUnreachable()]);

      final trace = await stub.configClient.fetch().then<StackTrace?>(
        (_) => null,
        onError: (Object _, StackTrace s) => s,
      );

      expect(trace.toString(), contains('configUnreachable'));
    });

    test('a body it cannot read is a config it cannot act on', () async {
      final stub = ConfigStub()..script([configMalformed()]);

      await expectLater(
        stub.configClient.fetch(),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            'emotely sent a config it could not read.',
          ),
        ),
      );
    });

    test('names the status code when the server refuses', () async {
      final stub = ConfigStub()..script([configRefused(503)]);

      await expectLater(
        stub.configClient.fetch(),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('reports itself with its message', () {
      // PostHog records an exception's toString(); this one is written here
      // and carries no journal content, so it goes out as it is.
      expect(const ConfigException('nope').toString(), 'ConfigException: nope');
    });
  });
}
