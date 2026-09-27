import 'package:feature_journal/src/view/greeting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestApiException;
import 'package:testing/testing.dart';

import '../journal_robot.dart';

void main() {
  group(PartOfDay, () {
    test('is morning from 5 until noon, afternoon until 6, evening the '
        'rest of the day and night', () {
      PartOfDay at(int hour, [int minute = 0]) =>
          PartOfDay.at(DateTime(2026, 9, 26, hour, minute));

      expect(at(0), PartOfDay.evening);
      expect(at(4, 59), PartOfDay.evening);
      expect(at(5), PartOfDay.morning);
      expect(at(11, 59), PartOfDay.morning);
      expect(at(12), PartOfDay.afternoon);
      expect(at(17, 59), PartOfDay.afternoon);
      expect(at(18), PartOfDay.evening);
      expect(at(23, 59), PartOfDay.evening);
    });

    test('greets by name, or without one', () {
      expect(greeting(PartOfDay.evening, 'Peter'), 'Good evening, Peter');
      expect(greeting(PartOfDay.morning, null), 'Good morning');
    });
  });

  group(JournalGreeting, () {
    JournalRobot robotWith(WidgetTester tester, {String? name}) {
      final supabase = SupabaseStub();
      if (name != null) {
        supabase.always(profileRead, rows([profileRow(displayName: name)]));
      }
      return JournalRobot(tester, supabase: supabase, agent: AgentStub());
    }

    String title(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(JournalGreeting.titleKey)).data!;

    testWidgets('greets the user by the name in their profile, under the '
        'date', (tester) async {
      final robot = robotWith(tester, name: 'Peter');
      await robot.launch();

      expect(title(tester), 'Good evening, Peter');
      expect(find.text('Saturday, September 26, 2026'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(JournalGreeting.titleKey))
            .style
            ?.fontStyle,
        FontStyle.normal,
      );
    });

    testWidgets('says the time of day the clock says', (tester) async {
      final robot = robotWith(tester, name: 'Pip')
        ..now = DateTime(2026, 9, 27, 7, 30);
      await robot.launch();

      expect(title(tester), 'Good morning, Pip');
    });

    testWidgets('greets without a name when the profile has none', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();

      expect(title(tester), 'Good evening');
    });

    testWidgets('shows the journal when the profile cannot be read, and '
        'reports why', (tester) async {
      final supabase = SupabaseStub()..always(profileRead, restRefused());
      final robot = JournalRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
      );
      await robot.launch();

      expect(title(tester), 'Good evening');
      expect(robot.start, findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_load'},
        ),
      ]);
    });
  });

  group('the way in from sign-up', () {
    testWidgets('starts a session as soon as the journal is read, once', (
      tester,
    ) async {
      final robot = JournalRobot(
        tester,
        supabase: SupabaseStub(),
        agent: AgentStub(),
        startSession: true,
      );
      await robot.launch();

      expect(robot.navigator.sessions, [null]);

      await robot.tap(robot.start);

      expect(robot.navigator.sessions, [null, null]);
    });

    testWidgets('asks for consent first, like "Start a session"', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..always(consentRead, consentStands(granted: false));
      final robot = JournalRobot(
        tester,
        supabase: supabase,
        agent: AgentStub(),
        startSession: true,
      );
      robot.navigator.consentGiven = true;
      await robot.launch();

      expect(robot.navigator.consentRequests, 1);
      expect(robot.navigator.sessions, [null]);
    });
  });
}
