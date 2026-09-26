// `SupabaseClient.table` and the typed builders behind it are marked
// @experimental in supabase 3.0.0-dev; this file is the one place that uses
// them, on purpose, so the warning is silenced here rather than globally.
// ignore_for_file: experimental_member_use

import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:journal_repository/src/journal_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_schema/supabase_schema.dart';

/// The app's side of ADR 0010: journal rows written and read straight from
/// Supabase under the signed-in user's own rights. Nothing here goes through
/// the agent, and nothing here can reach another user's rows.
///
/// Tables and columns come from `supabase_schema`, generated from the
/// migrations, so a renamed column or a missing required value fails to
/// compile instead of failing at the server.
class const JournalRepository({required final SupabaseClient supabase}) {
  /// The set the agent walks today; it is not on the wire yet, so the app
  /// names it. Mirrors `defaultQuestionSet.id` in `apps/agent`.
  static const questionSetId = 'legacy-reflections';

  static const _inProgress = 'in_progress';

  /// The session still in progress, if any: what the journal offers to
  /// continue.
  Future<OpenSession?> openSession() async {
    final row = await supabase
        .table(Sessions.table)
        .select()
        .where(Sessions.status.eq(_inProgress))
        .maybeSingle();
    return row == null ? null : OpenSession.fromJson(row.toJson());
  }

  /// The session [id], if it is still in progress: what a route names when
  /// it asks to continue one. Finished or discarded since, it is nothing.
  Future<OpenSession?> session(String id) async {
    final row = await supabase
        .table(Sessions.table)
        .select()
        .where(Sessions.id.eq(id) & Sessions.status.eq(_inProgress))
        .maybeSingle();
    return row == null ? null : OpenSession.fromJson(row.toJson());
  }

  /// Every filed entry, newest first.
  Future<List<EntryRecord>> entries() async {
    final rows = await supabase
        .table(Entries.table)
        .select()
        .order(Entries.createdAt.desc());
    return [for (final row in rows) EntryRecord.fromJson(row.toJson())];
  }

  /// One filed entry by its [id], or nothing if the journal holds no such
  /// entry — deleted since, or never this user's, which RLS answers the
  /// same way (ADR 0010).
  Future<EntryRecord?> entry(String id) async {
    final row = await supabase
        .table(Entries.table)
        .select()
        .where(Entries.id.eq(id))
        .maybeSingle();
    return row == null ? null : EntryRecord.fromJson(row.toJson());
  }

  /// How many entries the user has filed. Asked for the count alone — the
  /// server counts and no row travels — because the one caller wants a
  /// milestone, not the journal.
  Future<int> countEntries() => supabase.table(Entries.table).count();

  /// Drops the unfinished session [sessionId]; the next one starts fresh.
  Future<void> discardSession(String sessionId) =>
      supabase.table(Sessions.table).delete().where(Sessions.id.eq(sessionId));

  /// Records a round: the signed transcript the agent handed back, the
  /// question now pending (none once the session is over) and every
  /// question asked so far. The first call creates the row, replacing any
  /// session still in progress, and every call returns the row's id.
  Future<String> saveRound({
    required String? sessionId,
    required List<Object?> transcript,
    required String signature,
    required PendingQuestion? pending,
    required Iterable<AskQuestion> questions,
    required String appVersion,
  }) async {
    final asked = [for (final question in questions) question.toJson()];
    if (sessionId != null) {
      final round = SessionsUpdate(
        transcript: transcript,
        signature: signature,
        pending: pending?.toJson(),
        questions: asked,
        appVersion: appVersion,
      );
      // A null value leaves a column alone; a round with nothing pending
      // has to clear the question it answered, so it says so.
      await supabase
          .table(Sessions.table)
          .update(pending == null ? round.setPendingToNull() : round)
          .where(Sessions.id.eq(sessionId));
      return sessionId;
    }
    await supabase
        .table(Sessions.table)
        .delete()
        .where(Sessions.status.eq(_inProgress));
    final created = await supabase
        .table(Sessions.table)
        .insert(
          SessionsInsert(
            transcript: transcript,
            signature: signature,
            pending: pending?.toJson(),
            questions: asked,
            appVersion: appVersion,
            questionSetId: questionSetId,
          ),
        )
        .select([Sessions.id])
        .single();
    return created.id;
  }

  /// Files the [entry] and closes the session in one transaction on the
  /// server, so a journal never holds one without the other. Functions are
  /// not generated yet, so this call stays untyped.
  Future<void> completeSession({
    required String sessionId,
    required JournalEntry entry,
    required Iterable<AskQuestion> questions,
  }) => supabase.rpc<Object?>(
    'complete_session',
    params: {
      'session_id': sessionId,
      'summary': entry.summary,
      'answers': entry.toJson()['answers'],
      'questions': [for (final question in questions) question.toJson()],
    },
  );
}
