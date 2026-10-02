import 'dart:ui';

import 'package:contract/contract.dart';
import 'package:emotely/app/user_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestApiException;
import 'package:testing/testing.dart';

import '../consent/consent_robot.dart';

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
