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
      });
    });

    test('has nothing to say when the profile cannot be read, and reports '
        'it', () async {
      final supabase = SupabaseStub()..rest(profileRead, [restRefused()]);
      final spy = AnalyticsSpy();

      expect(await sourceOver(supabase, spy).current(), isNull);
      expect(spy.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_load'},
        ),
      ]);
    });
  });
}
