import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'journal_models.freezed.dart';
part 'journal_models.g.dart';

/// A session still in progress, as the journal stores it: enough to put the
/// pending question back on screen and continue without a server round.
@freezed
abstract class OpenSession with _$OpenSession {
  const factory({
    required String id,
    required List<Object?> transcript,
    required String signature,
    required List<AskQuestion> questions,
    PendingQuestion? pending,
  }) = _OpenSession;

  factory fromJson(Map<String, dynamic> json) => _$OpenSessionFromJson(json);
}

/// A filed entry, as the journal stores it: about its `journalDay`, the
/// day its session started on (#158), and filed at `createdAt`, which
/// orders entries within a day.
///
/// `journalDay` is a calendar date and reads as local midnight of it, so it
/// formats as that date wherever the user is now.
@freezed
abstract class EntryRecord with _$EntryRecord {
  const factory({
    required String id,
    required String summary,
    required Map<String, Answer> answers,
    required List<AskQuestion> questions,
    required DateTime journalDay,
    required DateTime createdAt,
  }) = _EntryRecord;

  factory fromJson(Map<String, dynamic> json) => _$EntryRecordFromJson(json);
}

extension EntryRecordX on EntryRecord {
  /// The entry as the session produced it.
  JournalEntry get entry => JournalEntry(summary: summary, answers: answers);

  /// The questions keyed by id, the shape the entry view renders from.
  Map<String, AskQuestion> get questionsById => {
    for (final question in questions) question.questionId: question,
  };
}
