import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:testing/testing.dart';

void main() {
  const question = AskQuestion(
    questionId: 'q1',
    question: 'How was today?',
    answerType: AnswerType.longtext,
  );
  const pending = PendingQuestion(toolCallId: 'c1', question: question);
  const answers = {'q1': Answer.longtext('Quiet.')};

  late SupabaseStub supabase;
  late JournalRepository repository;

  setUp(() {
    supabase = SupabaseStub();
    repository = JournalRepository(supabase: supabase.supabase);
  });

  group(JournalRepository, () {
    test('reads the session in progress with its pending question', () async {
      supabase.rest('GET /rest/v1/sessions', [
        rows([
          sessionRow(pending: pending, questions: const [question]),
        ]),
      ]);

      final open = await repository.openSession();

      expect(
        open,
        const OpenSession(
          id: SupabaseStub.sessionId,
          transcript: ['stored'],
          signature: 'stored-sig',
          questions: [question],
          pending: pending,
        ),
      );
      final request = supabase.to('GET /rest/v1/sessions').single;
      expect(request.query['status'], 'eq.in_progress');
    });

    test('reads one session in progress by its id', () async {
      supabase.rest('GET /rest/v1/sessions', [
        rows([
          sessionRow(id: 's-1', pending: pending, questions: const [question]),
        ]),
      ]);

      final open = await repository.session('s-1');

      expect(open?.id, 's-1');
      expect(open?.pending, pending);
      final request = supabase.to('GET /rest/v1/sessions').single;
      expect(request.query['id'], 'eq.s-1');
      expect(request.query['status'], 'eq.in_progress');
    });

    test('has no session for an id that is finished or gone', () async {
      supabase.rest('GET /rest/v1/sessions', [rows(const [])]);

      expect(await repository.session('s-done'), isNull);
    });

    test('has no session in progress when the journal holds none', () async {
      supabase.rest('GET /rest/v1/sessions', [rows(const [])]);

      expect(await repository.openSession(), isNull);
    });

    test('lists the filed entries as the server orders them', () async {
      final older = DateTime.utc(2026, 9, 1, 8);
      // Filed after midnight, from a session started the evening before.
      final newer = DateTime.utc(2026, 9, 2, 0, 30);
      supabase.rest('GET /rest/v1/entries', [
        rows([
          entryRow(
            id: 'e2',
            summary: 'Newer',
            createdAt: newer,
            journalDay: DateTime(2026, 9),
            answers: answers,
            questions: const [question],
          ),
          entryRow(id: 'e1', summary: 'Older', createdAt: older),
        ]),
      ]);

      final entries = await repository.entries();

      expect(entries, [
        EntryRecord(
          id: 'e2',
          summary: 'Newer',
          answers: answers,
          questions: const [question],
          journalDay: DateTime(2026, 9),
          createdAt: newer,
        ),
        EntryRecord(
          id: 'e1',
          summary: 'Older',
          answers: const {},
          questions: const [],
          journalDay: DateTime(2026, 9),
          createdAt: older,
        ),
      ]);
      final request = supabase.to('GET /rest/v1/entries').single;
      // Neither column is null, so no null placement is asked for.
      expect(request.query['order'], 'journal_day.desc,created_at.desc');
    });

    test('reads one entry by its id', () async {
      final written = DateTime.utc(2026, 9, 2, 8);
      supabase.rest('GET /rest/v1/entries', [
        rows([
          entryRow(
            id: 'e2',
            summary: 'Newer',
            createdAt: written,
            journalDay: DateTime(2026, 9),
            answers: answers,
            questions: const [question],
          ),
        ]),
      ]);

      final entry = await repository.entry('e2');

      expect(
        entry,
        EntryRecord(
          id: 'e2',
          summary: 'Newer',
          answers: answers,
          questions: const [question],
          journalDay: DateTime(2026, 9),
          createdAt: written,
        ),
      );
      final request = supabase.to('GET /rest/v1/entries').single;
      expect(request.query['id'], 'eq.e2');
    });

    test('has no entry for an id the journal does not hold', () async {
      supabase.rest('GET /rest/v1/entries', [rows(const [])]);

      expect(await repository.entry('gone'), isNull);
    });

    test('counts the entries without fetching any', () async {
      supabase.rest('HEAD /rest/v1/entries', [rowsCounted(3)]);

      expect(await repository.countEntries(), 3);

      // A count-only request: the server counts, no row travels.
      final request = supabase.to('HEAD /rest/v1/entries').single;
      expect(request.body, isNull);
    });

    test('discards a session by id', () async {
      supabase.rest('DELETE /rest/v1/sessions', [rowsChanged()]);

      await repository.discardSession('s9');

      final request = supabase.to('DELETE /rest/v1/sessions').single;
      expect(request.query['id'], 'eq.s9');
    });

    test('the first round replaces any session in progress', () async {
      supabase
        ..rest('DELETE /rest/v1/sessions', [rowsChanged()])
        ..rest('POST /rest/v1/sessions', [rowCreated('s1')]);

      final id = await repository.saveRound(
        sessionId: null,
        startedAt: DateTime(2026, 10, 3, 9, 15),
        transcript: const ['t1'],
        signature: 'sig1',
        pending: pending,
        questions: const [question],
        appVersion: '2.0.0',
      );

      expect(id, 's1');
      final methods = [for (final r in supabase.requests) r.method];
      expect(methods, ['DELETE', 'POST']);
      expect(
        supabase.to('DELETE /rest/v1/sessions').single.query['status'],
        'eq.in_progress',
      );
      expect(supabase.bodies('/rest/v1/sessions').single, {
        'transcript': ['t1'],
        'signature': 'sig1',
        'pending': pending.toJson(),
        'questions': [question.toJson()],
        'app_version': '2.0.0',
        'question_set_id': JournalRepository.questionSetId,
        'journal_day': '2026-10-03',
      });
    });

    group('files a new session under the journal day it started on', () {
      // The device's wall clock decides, cutoff 04:00: a session started
      // before then is about the day before.
      final cases = {
        'just before the cutoff, the day before': (
          DateTime(2026, 10, 3, 3, 59),
          '2026-10-02',
        ),
        'at the cutoff, that day': (DateTime(2026, 10, 3, 4), '2026-10-03'),
        'just after midnight, the day before': (
          DateTime(2026, 10, 3, 0, 10),
          '2026-10-02',
        ),
        'late in the evening, that day': (
          DateTime(2026, 10, 3, 23, 59),
          '2026-10-03',
        ),
        'on the night of the new year, the old year': (
          DateTime(2027, 1, 1, 1, 30),
          '2026-12-31',
        ),
        // Clocks go forward in Europe at 02:00 on 2026-03-29, back at 03:00
        // on 2026-10-25: 04:00 is the cutoff on the clock, however many
        // hours after midnight it comes.
        'at 03:59 on the day clocks go forward, the day before': (
          DateTime(2026, 3, 29, 3, 59),
          '2026-03-28',
        ),
        'at 04:00 on the day clocks go forward, that day': (
          DateTime(2026, 3, 29, 4),
          '2026-03-29',
        ),
        'at 03:59 on the day clocks go back, the day before': (
          DateTime(2026, 10, 25, 3, 59),
          '2026-10-24',
        ),
        'at 04:00 on the day clocks go back, that day': (
          DateTime(2026, 10, 25, 4),
          '2026-10-25',
        ),
      };
      for (final MapEntry(key: name, value: (startedAt, journalDay))
          in cases.entries) {
        test('started $name', () async {
          supabase
            ..rest('DELETE /rest/v1/sessions', [rowsChanged()])
            ..rest('POST /rest/v1/sessions', [rowCreated('s1')]);

          await repository.saveRound(
            sessionId: null,
            startedAt: startedAt,
            transcript: const ['t1'],
            signature: 'sig1',
            pending: pending,
            questions: const [question],
            appVersion: '2.0.0',
          );

          expect(
            supabase.bodies('/rest/v1/sessions').single,
            containsPair('journal_day', journalDay),
          );
        });
      }

      test('reads a moment given in UTC on the device clock', () async {
        supabase
          ..rest('DELETE /rest/v1/sessions', [rowsChanged()])
          ..rest('POST /rest/v1/sessions', [rowCreated('s1')]);
        final startedAt = DateTime(2026, 10, 3, 4, 30);

        await repository.saveRound(
          sessionId: null,
          startedAt: startedAt.toUtc(),
          transcript: const ['t1'],
          signature: 'sig1',
          pending: pending,
          questions: const [question],
          appVersion: '2.0.0',
        );

        expect(
          supabase.bodies('/rest/v1/sessions').single,
          containsPair('journal_day', '2026-10-03'),
        );
      });
    });

    test('later rounds update the row and keep its id', () async {
      supabase.rest('PATCH /rest/v1/sessions', [rowsChanged()]);

      final id = await repository.saveRound(
        sessionId: 's1',
        startedAt: DateTime(2026, 10, 3, 9, 15),
        transcript: const ['t1', 't2'],
        signature: 'sig2',
        pending: null,
        questions: const [question],
        appVersion: '2.0.0',
      );

      expect(id, 's1');
      final request = supabase.to('PATCH /rest/v1/sessions').single;
      expect(request.query['id'], 'eq.s1');
      expect(request.body, {
        'transcript': ['t1', 't2'],
        'signature': 'sig2',
        'pending': null,
        'questions': [question.toJson()],
        'app_version': '2.0.0',
      });
    });

    test('a later round writes the question now pending', () async {
      supabase.rest('PATCH /rest/v1/sessions', [rowsChanged()]);

      await repository.saveRound(
        sessionId: 's1',
        startedAt: DateTime(2026, 10, 3, 9, 15),
        transcript: const ['t1', 't2'],
        signature: 'sig2',
        pending: pending,
        questions: const [question],
        appVersion: '2.0.0',
      );

      expect(
        supabase.to('PATCH /rest/v1/sessions').single.body,
        containsPair('pending', pending.toJson()),
      );
    });

    test('files the entry and closes the session in one call', () async {
      supabase.rest('POST /rest/v1/rpc/complete_session', [
        rpcReturned(SupabaseStub.entryId),
      ]);

      await repository.completeSession(
        sessionId: 's1',
        entry: const JournalEntry(summary: 'A quiet day.', answers: answers),
        questions: const [question],
      );

      expect(supabase.bodies('/rest/v1/rpc/complete_session').single, {
        'session_id': 's1',
        'summary': 'A quiet day.',
        'answers': {'q1': answers['q1']!.toJson()},
        'questions': [question.toJson()],
      });
    });
  });

  group(EntryRecord, () {
    final record = EntryRecord(
      id: 'e1',
      summary: 'A quiet day.',
      answers: answers,
      questions: const [question],
      journalDay: DateTime(2026, 9),
      createdAt: DateTime.utc(2026, 9, 2),
    );

    test('is the entry the session produced', () {
      expect(
        record.entry,
        const JournalEntry(summary: 'A quiet day.', answers: answers),
      );
    });

    test('keys its questions by id', () {
      expect(record.questionsById, {'q1': question});
    });
  });
}
