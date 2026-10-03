// The performance survey's guard against a step that never finishes
// (integration_test/survey/screen_deadline.dart): on Test Lab a hung step
// otherwise waits out the whole test timeout and leaves nothing but
// "timed out" behind.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/survey/screen_deadline.dart';

void main() {
  group('withinDeadline', () {
    test('passes on what the walk returns when it finishes in time', () async {
      final result = await withinDeadline(
        'journal',
        const Duration(seconds: 1),
        () => Future.value(42),
        waitingOn: () => 'nothing',
      );
      expect(result, 42);
    });

    test(
      'fails a walk that never finishes, naming the screen and its step',
      () async {
        final never = Completer<void>();
        await expectLater(
          withinDeadline(
            'more',
            const Duration(milliseconds: 10),
            () => never.future,
            waitingOn: () => 'tap app_shell.more; the screen shows More',
          ),
          throwsA(
            isA<ScreenDeadlineExceeded>()
                .having((error) => error.screen, 'screen', 'more')
                .having(
                  (error) => error.toString(),
                  'message',
                  allOf(
                    contains('more'),
                    contains('tap app_shell.more; the screen shows More'),
                  ),
                ),
          ),
        );
      },
    );

    test('lets a walk fail with its own error', () async {
      await expectLater(
        withinDeadline(
          'entry',
          const Duration(seconds: 1),
          () => Future<void>.error(StateError('no entry')),
          waitingOn: () => 'nothing',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Breadcrumbs', () {
    test('remembers the last step of the screen it is on', () {
      final logged = <String>[];
      final crumbs = Breadcrumbs(logged.add)
        ..screen('consent')
        ..step('tap privacy_settings.journal')
        ..step('tap privacy_settings.confirm');
      expect(crumbs.last, 'consent: tap privacy_settings.confirm');
      expect(logged, [
        'survey: consent',
        'survey: consent: tap privacy_settings.journal',
        'survey: consent: tap privacy_settings.confirm',
      ]);
    });
  });
}
