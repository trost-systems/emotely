import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:testing/testing.dart';

import '../session_robot.dart';
import '../session_strings.dart';

/// The session writes itself to the journal as it goes (ADR 0010): every
/// round updates the user's session row, completion files the entry.
void main() {
  group(JournalRepository, () {
    const sessions = 'POST /rest/v1/sessions';
    const updates = 'PATCH /rest/v1/sessions';
    const complete = 'POST /rest/v1/rpc/complete_session';

    testWidgets('saves the session after every round', (tester) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          awaiting(
            toolCallId: 'c2',
            question: SessionRobot.best,
            transcript: const ['round', 'round'],
            signature: 'sig-2',
          ),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      final supabase = robot.supabaseStub;
      // Until resume lands, a new session replaces an unfinished one.
      final cleared = supabase.to('DELETE /rest/v1/sessions').single;
      expect(cleared.query['status'], 'eq.in_progress');
      final created = supabase.to(sessions).single;
      expect(created.query['select'], 'id');
      expect(created.body, {
        'question_set_id': JournalRepository.questionSetId,
        'transcript': AgentStub.transcript,
        'signature': AgentStub.signature,
        'pending': {
          'tool_call_id': 'c1',
          'question': SessionRobot.rate.toJson(),
        },
        'questions': [SessionRobot.rate.toJson()],
        'app_version': AgentStub.appVersion,
        'journal_day': '2026-10-03',
      });

      await robot.answerRating(7);

      final updated = supabase.to(updates).single;
      expect(updated.query['id'], 'eq.${SupabaseStub.sessionId}');
      expect(updated.body, {
        'transcript': ['round', 'round'],
        'signature': 'sig-2',
        'pending': {
          'tool_call_id': 'c2',
          'question': SessionRobot.best.toJson(),
        },
        'questions': [SessionRobot.rate.toJson(), SessionRobot.best.toJson()],
        'app_version': AgentStub.appVersion,
      });
      expect(supabase.to(sessions), hasLength(1));
    });

    testWidgets('files the session under the day it started on, read when '
        'it starts', (tester) async {
      final agent = AgentStub()
        ..script([awaiting(toolCallId: 'c1', question: SessionRobot.rate)]);
      final robot = SessionRobot(tester, agent)
        ..clock = DateTime(2026, 10, 3, 3, 59);
      await robot.launch();
      // The first round answers after the 04:00 cutoff has passed.
      robot.clock = DateTime(2026, 10, 3, 4, 1);
      await robot.settle();

      expect(
        robot.supabaseStub.to(sessions).single.body,
        containsPair('journal_day', '2026-10-02'),
      );
    });

    testWidgets('files the entry and closes the session in one call', (
      tester,
    ) async {
      const answers = {'q-rate': Answer.rating(7)};
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          completed(summary: 'A seven.', answers: answers),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(7);

      expect(robot.summary, findsOneWidget);
      final filed = robot.supabaseStub.to(complete).single;
      expect(filed.body, {
        'session_id': SupabaseStub.sessionId,
        'summary': 'A seven.',
        'answers': {'q-rate': const Answer.rating(7).toJson()},
        'questions': [SessionRobot.rate.toJson()],
      });
      expect(robot.supabaseStub.to(updates), isEmpty);
      expect(
        robot.analytics.events.last,
        event('session_completed', {'answers': 1}),
      );
    });

    testWidgets('marks the third entry once it is in the journal', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..always('HEAD /rest/v1/entries', rowsCounted(3));
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          completed(
            summary: 'A seven.',
            answers: const {'q-rate': Answer.rating(7)},
          ),
        ]);
      final robot = SessionRobot(tester, agent, supabase: supabase);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(7);
      await tester.pumpAndSettle();

      // The count is read after the entry is filed, so the survey that
      // this triggers can never interrupt the save.
      expect(supabase.to('HEAD /rest/v1/entries'), hasLength(1));
      // Fired once, and after the completion event — never before it.
      final names = [
        for (final captured in robot.analytics.events) captured['event'],
      ];
      expect(
        names.where((name) => name == 'third_entry_written'),
        hasLength(1),
      );
      expect(
        names.indexOf('session_completed'),
        lessThan(names.indexOf('third_entry_written')),
      );
    });

    testWidgets('files the entry even when the milestone cannot be counted', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..always('HEAD /rest/v1/entries', restRefused());
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          completed(
            summary: 'A seven.',
            answers: const {'q-rate': Answer.rating(7)},
          ),
        ]);
      final robot = SessionRobot(tester, agent, supabase: supabase);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(7);
      await tester.pumpAndSettle();

      // Counting is telemetry: it costs the user nothing and the entry
      // still shows — but it is reported, because a milestone that stops
      // being counted is a bug we want to hear about.
      expect(robot.summary, findsOneWidget);
      expect([
        for (final captured in robot.analytics.events) captured['event'],
      ], isNot(contains('third_entry_written')));
      // No SQLSTATE: the count is a HEAD request and postgrest never reads
      // a HEAD response's body, so the refusal arrives as its status alone.
      expect(robot.analytics.exceptions, [
        captured(withheld(PostgrestApiException, statusCode: 409), {
          'step': 'entry_milestone',
        }),
      ]);
    });

    testWidgets('keeps going when a round cannot be saved', (tester) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          completed(summary: 'Saved late.', answers: const {}),
        ]);
      final supabase = SupabaseStub()..rest(sessions, [restRefused()]);
      final robot = SessionRobot(tester, agent, supabase: supabase);
      await robot.launch();
      await robot.settle();

      expect(robot.question, findsOneWidget);
      expect(robot.analytics.events.last, event('session_save_failed'));
      // No row yet, so no id to name; the SQLSTATE says what Postgres
      // objected to, its message stays on the device (it may quote the row).
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'session_save'},
        ),
      ]);

      await robot.answerRating(3);

      // The row is created on completion instead, then the entry is filed.
      expect(supabase.to(sessions), hasLength(2));
      expect(
        supabase.to(complete).single.body,
        containsPair('session_id', SupabaseStub.sessionId),
      );
      expect(robot.summary, findsOneWidget);
    });

    testWidgets('an entry that cannot be filed is retried without the agent', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          completed(summary: 'Kept.', answers: const {}),
        ]);
      final supabase = SupabaseStub()..rest(complete, [restRefused()]);
      final robot = SessionRobot(tester, agent, supabase: supabase);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(9);

      expect(find.text(tester.strings.entrySaveFailedMessage), findsOneWidget);
      expect(robot.summary, findsNothing);
      expect(robot.analytics.events.last, event('entry_save_failed'));
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'entry_save', 'session_id': SupabaseStub.sessionId},
        ),
      ]);

      await robot.tapRetry();

      expect(robot.summary, findsOneWidget);
      expect(agent.requests, hasLength(2));
      expect(supabase.to(complete), hasLength(2));
    });
  });
}
