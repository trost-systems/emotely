import 'dart:async';
import 'dart:ui';

import 'package:contract/contract.dart';
import 'package:emotely/app/user_context.dart';
import 'package:feature_session/feature_session.dart' show RatingInput;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestApiException;
import 'package:testing/testing.dart';

import '../consent/consent_robot.dart';

DisplayName _name(String raw) =>
    (DisplayName.check(raw) as DisplayNameAccepted).name;

void main() {
  group(AppUserContextSource, () {
    AppUserContextSource sourceOver(SupabaseStub supabase, AnalyticsSpy spy) =>
        AppUserContextSource(
          profiles: ProfileRepository(supabase: supabase.supabase),
          errors: spy.errorReporter,
        );

    test('tells the session the name the user asked to be called', () async {
      final supabase = SupabaseStub()
        ..rest(profileRead, [
          rows([profileRow(displayName: 'Peter')]),
        ]);

      expect(
        await sourceOver(supabase, AnalyticsSpy()).current(),
        const UserContext(displayName: 'Peter'),
      );
    });

    test('says when the name is one emotely picked', () async {
      final supabase = SupabaseStub()
        ..rest(profileRead, [
          rows([profileRow(displayName: 'Pebble', nameIsPlaceholder: true)]),
        ]);

      expect(
        await sourceOver(supabase, AnalyticsSpy()).current(),
        const UserContext(displayName: 'Pebble', nameIsPlaceholder: true),
      );
    });

    test('has nothing to say while there is no profile', () async {
      final supabase = SupabaseStub()..rest(profileRead, [rows(const [])]);

      expect(await sourceOver(supabase, AnalyticsSpy()).current(), isNull);
    });

    group('reads the profile once a session (#264)', () {
      test('and answers every later round from it', () async {
        final supabase = SupabaseStub()
          ..always(profileRead, rows([profileRow(displayName: 'Peter')]));
        final source = sourceOver(supabase, AnalyticsSpy());

        for (var round = 0; round < 17; round++) {
          expect(
            await source.current(),
            const UserContext(displayName: 'Peter'),
          );
        }

        expect(supabase.to(profileRead), hasLength(1));
      });

      test('and remembers that there is none', () async {
        final supabase = SupabaseStub()..always(profileRead, rows(const []));
        final source = sourceOver(supabase, AnalyticsSpy());

        expect(await source.current(), isNull);
        expect(await source.current(), isNull);

        expect(supabase.to(profileRead), hasLength(1));
      });

      test('yet a rename made in the app reaches the next round without '
          'another read', () async {
        final supabase = SupabaseStub()
          ..always(profileRead, rows([profileRow(displayName: 'Pebble')]))
          ..always(profileSave, rowsChanged());
        final profiles = ProfileRepository(supabase: supabase.supabase);
        final source = AppUserContextSource(
          profiles: profiles,
          errors: AnalyticsSpy().errorReporter,
        );
        expect(
          await source.current(),
          const UserContext(displayName: 'Pebble'),
        );

        await profiles.saveDisplayName(_name('Maya'));

        expect(await source.current(), const UserContext(displayName: 'Maya'));
        expect(supabase.to(profileRead), hasLength(1));
      });

      test('and a session that starts after a rename reads the new '
          'name', () async {
        // The rename on another device: only Supabase knows it.
        final supabase = SupabaseStub()
          ..rest(profileRead, [
            rows([profileRow(displayName: 'Pebble')]),
            rows([profileRow(displayName: 'Maya')]),
          ]);
        final profiles = ProfileRepository(supabase: supabase.supabase);
        final errors = AnalyticsSpy().errorReporter;
        final first = AppUserContextSource(profiles: profiles, errors: errors);
        expect(await first.current(), const UserContext(displayName: 'Pebble'));
        await first.close();

        final next = AppUserContextSource(profiles: profiles, errors: errors);

        expect(await next.current(), const UserContext(displayName: 'Maya'));
      });

      test('and tries again on the next round after a read that '
          'failed', () async {
        final supabase = SupabaseStub()
          ..rest(profileRead, [
            restRefused(),
            rows([profileRow(displayName: 'Peter')]),
          ]);
        final source = sourceOver(supabase, AnalyticsSpy());

        expect(await source.current(), isNull);
        expect(await source.current(), const UserContext(displayName: 'Peter'));
        expect(await source.current(), const UserContext(displayName: 'Peter'));

        expect(supabase.to(profileRead), hasLength(2));
      });

      test('and keeps a rename saved while a read was failing', () async {
        final readAnswers = Completer<void>();
        final supabase = SupabaseStub()
          ..rest(profileRead, [
            () async {
              await readAnswers.future;
              return await restRefused()();
            },
          ])
          ..always(profileSave, rowsChanged());
        final profiles = ProfileRepository(supabase: supabase.supabase);
        final source = AppUserContextSource(
          profiles: profiles,
          errors: AnalyticsSpy().errorReporter,
        );

        final firstRound = source.current();
        await pumpEventQueue();
        await profiles.saveDisplayName(_name('Maya'));
        await pumpEventQueue();
        readAnswers.complete();

        expect(await firstRound, isNull);
        expect(await source.current(), const UserContext(displayName: 'Maya'));
        expect(supabase.to(profileRead), hasLength(1));
      });

      test('and stops listening for renames once the session is '
          'over', () async {
        final supabase = SupabaseStub()
          ..always(profileRead, rows([profileRow(displayName: 'Pebble')]))
          ..always(profileSave, rowsChanged());
        final profiles = ProfileRepository(supabase: supabase.supabase);
        final source = AppUserContextSource(
          profiles: profiles,
          errors: AnalyticsSpy().errorReporter,
        );
        await source.current();

        await source.close();
        await profiles.saveDisplayName(_name('Maya'));
        await pumpEventQueue();

        // Asked again after it closed, it knows nothing of the session
        // that was, and reads afresh.
        expect(
          await source.current(),
          const UserContext(displayName: 'Pebble'),
        );
        expect(supabase.to(profileRead), hasLength(2));
      });

      test('closes without ever having been asked', () async {
        await expectLater(
          sourceOver(SupabaseStub(), AnalyticsSpy()).close(),
          completes,
        );
      });
    });

    testWidgets('a rename saved in the app reaches the next round of the '
        'open session, read once', (tester) async {
      final supabase = SupabaseStub()
        ..always(consentRead, consentStands())
        ..always(profileRead, rows([profileRow(displayName: 'Pebble')]))
        ..always(profileSave, rowsChanged());
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: rateQuestion),
          awaiting(toolCallId: 'c2', question: rateQuestion),
        ]);
      final robot = ConsentRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();
      final readsBefore = supabase.to(profileRead).length;
      await robot.startSession();
      expect(
        (robot.agent.lastRequest['user_context']!
            as Map<String, dynamic>)['display_name'],
        'Pebble',
      );

      // The app's one write path for the name, as the Profile screen and
      // onboarding's name step call it.
      await GetIt.I<ProfileRepository>().saveDisplayName(_name('Maya'));
      await tapSliderAt(tester, find.byKey(RatingInput.sliderKey), 7);
      await robot.settle();
      await robot.tap(find.byKey(RatingInput.submitKey));

      expect(
        (robot.agent.lastRequest['user_context']!
            as Map<String, dynamic>)['display_name'],
        'Maya',
      );
      expect(supabase.to(profileRead).length - readsBefore, 1);
    });

    testWidgets('names the user in every round of a session', (tester) async {
      final supabase = SupabaseStub()
        ..always(consentRead, consentStands())
        ..always(profileRead, rows([profileRow(displayName: 'Peter')]));
      final agent = AgentStub()
        ..script([awaiting(toolCallId: 'c1', question: rateQuestion)]);
      final robot = ConsentRobot(tester, supabase: supabase, agent: agent);
      await robot.launch();

      await robot.startSession();

      expect(robot.session, findsOneWidget);
      expect(robot.agent.lastRequest['user_context'], {
        'display_name': 'Peter',
        'name_is_placeholder': false,
        'locale': 'en',
      });
    });

    group('tells the companion the language the app resolved (#228)', () {
      Future<Object?> sentLocale(
        WidgetTester tester,
        List<Locale> device,
      ) async {
        tester.platformDispatcher.localesTestValue = device;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final supabase = SupabaseStub()
          ..always(consentRead, consentStands())
          ..always(profileRead, rows([profileRow(displayName: 'Peter')]));
        final agent = AgentStub()
          ..script([awaiting(toolCallId: 'c1', question: rateQuestion)]);
        final robot = ConsentRobot(tester, supabase: supabase, agent: agent);
        await robot.launch();

        await robot.startSession();

        return (robot.agent.lastRequest['user_context']!
            as Map<String, dynamic>)['locale'];
      }

      testWidgets('German, not the regional variant of the device', (
        tester,
      ) async {
        expect(
          await sentLocale(tester, const [Locale('de', 'AT'), Locale('en')]),
          'de',
        );
      });

      testWidgets('English on a device in a language the app does not ship', (
        tester,
      ) async {
        expect(
          await sentLocale(tester, const [Locale('fr', 'FR'), Locale('it')]),
          'en',
        );
      });
    });

    test('has nothing to say when the profile cannot be read, and reports '
        'it', () async {
      final supabase = SupabaseStub()..rest(profileRead, [restRefused()]);
      final spy = AnalyticsSpy();

      expect(await sourceOver(supabase, spy).current(), isNull);
      // The report is not awaited, and queues behind the analytics gate.
      await pumpEventQueue();
      expect(spy.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_load'},
        ),
      ]);
    });
  });
}
