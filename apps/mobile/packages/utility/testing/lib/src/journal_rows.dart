import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:testing/testing.dart';

/// A `sessions` row as Supabase returns it.
Map<String, Object?> sessionRow({
  String id = SupabaseStub.sessionId,
  List<Object?> transcript = const ['stored'],
  String signature = 'stored-sig',
  PendingQuestion? pending,
  List<AskQuestion> questions = const [],
}) => {
  'id': id,
  'user_id': SupabaseStub.userId,
  'question_set_id': 'legacy-reflections',
  'transcript': transcript,
  'signature': signature,
  'status': 'in_progress',
  'pending': pending?.toJson(),
  'questions': [for (final question in questions) question.toJson()],
  'app_version': '1.0.0',
  'created_at': '2026-09-07T20:00:00+00:00',
  'journal_day': '2026-09-07',
  'updated_at': '2026-09-07T20:05:00+00:00',
};

/// An `entries` row as Supabase returns it, filed at [createdAt] and about
/// the date of [journalDay] (the date of [createdAt] in UTC when not given).
Map<String, Object?> entryRow({
  required String id,
  required String summary,
  required DateTime createdAt,
  DateTime? journalDay,
  Map<String, Answer> answers = const {},
  List<AskQuestion> questions = const [],
}) => {
  'id': id,
  'user_id': SupabaseStub.userId,
  'session_id': null,
  'summary': summary,
  'answers': answers.map(
    (questionId, answer) => MapEntry(questionId, answer.toJson()),
  ),
  'questions': [for (final question in questions) question.toJson()],
  'created_at': createdAt.toUtc().toIso8601String(),
  'journal_day': _dateLiteral(journalDay ?? createdAt.toUtc()),
};

/// The `YYYY-MM-DD` literal Postgres emits for a `date` column.
String _dateLiteral(DateTime day) => [
  day.year.toString().padLeft(4, '0'),
  day.month.toString().padLeft(2, '0'),
  day.day.toString().padLeft(2, '0'),
].join('-');
