import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:human_check/human_check.dart';

void main() {
  group(HumanCheck, () {
    test('hands each call a fresh token', () async {
      var issued = 0;
      final check = HumanCheck(() async => 'token-${++issued}');

      final first = await check.guard((token) async => token);
      final second = await check.guard((token) async => token);

      expect([first, second], ['token-1', 'token-2']);
    });

    test('a check without a token never makes the call', () async {
      var called = false;
      final check = HumanCheck(() async => null);

      await expectLater(
        check.guard((_) async => called = true),
        throwsA(isA<HumanCheckFailed>()),
      );
      expect(called, isFalse);
    });

    test('a check that throws fails the same way, keeping the cause', () async {
      final cause = Exception('challenge failed');
      var called = false;
      final check = HumanCheck(() async => throw cause);

      await expectLater(
        check.guard((_) async => called = true),
        throwsA(isA<HumanCheckFailed>().having((e) => e.cause, 'cause', cause)),
      );
      expect(called, isFalse);
    });

    test('a source that already says why is passed through as it is', () async {
      const failed = HumanCheckFailed('web view did not load');
      final check = HumanCheck(() async => throw failed);

      await expectLater(check.guard((_) async => true), throwsA(same(failed)));
    });

    test('what the call throws reaches the caller untouched', () async {
      final refused = Exception('captcha_failed');
      final check = HumanCheck(() async => 'token');

      await expectLater(
        check.guard<void>((_) async => throw refused),
        throwsA(same(refused)),
      );
    });
  });

  group(registerHumanCheck, () {
    test('registers one check over the given token source', () async {
      final getIt = GetIt.asNewInstance();

      registerHumanCheck(getIt, token: () async => 'token');

      expect(await getIt<HumanCheck>().guard((token) async => token), 'token');
    });
  });
}
