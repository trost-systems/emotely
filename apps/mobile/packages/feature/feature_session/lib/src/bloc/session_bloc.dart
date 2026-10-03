import 'dart:async';
import 'dart:ui';

import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:contract/contract.dart';
import 'package:feature_session/src/user_context_source.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:journal_repository/journal_repository.dart';

part 'session_bloc.freezed.dart';
part 'session_event.dart';
part 'session_state.dart';

/// Drives one journaling session: start, answer question after question,
/// finish with the entry. All state the server needs travels in the signed
/// transcript this bloc holds between rounds, and every round is written to
/// the user's journal so nothing is lost with the app (ADR 0010).
///
/// Analytics and error reports are fire-and-forget: they describe the
/// session, they never gate it.
class SessionBloc({
  required final AgentClient _agentClient,
  required final SessionAnalytics _analytics,
  required final ErrorReporter _errors,
  required final JournalRepository _repository,
  required final UserContextSource _userContext,
  final DateTime Function() _now = DateTime.now,
}) extends Bloc<SessionEvent, SessionState> {
  this : super(const SessionState.initial()) {
    on<SessionStarted>(_onStarted);
    on<SessionAnswered>(_onAnswered);
    on<SessionRetried>(_onRetried);
    on<SessionRestarted>(_onRestarted);
  }

  List<Object?>? _transcript;
  String? _signature;
  String? _sessionId;
  final _asked = <String, AskQuestion>{};

  /// The language the screen showed when the session started (#228).
  Locale? _locale;

  /// When this session started on the device clock: the journal day its
  /// row is created under, however much later that happens (#158). A
  /// resumed session has its row, and its day, already.
  late DateTime _startedAt;

  /// What to repeat on retry: the model round that failed, or the filing of
  /// an entry the model already produced. Neither changes state on failure,
  /// so repeating is always safe.
  late Future<void> Function(Emitter<SessionState> emit) _retry;

  Future<void> _onStarted(
    SessionStarted event,
    Emitter<SessionState> emit,
  ) async {
    _locale = event.locale;
    _startedAt = _now();
    if (event.resume case final id?) {
      _retry = (emit) => _onStarted(event, emit);
      emit(const SessionState.loading(answered: 0));
      final OpenSession? stored;
      try {
        stored = await _repository.session(id);
      } on Exception catch (error, stackTrace) {
        _failed(
          error,
          stackTrace,
          SessionFailureReason.sessionReadFailed,
          emit,
        );
        return;
      }
      // Gone in the meantime — discarded on another device, or finished
      // there: the offer was the journal's, the answer is the server's.
      if (stored != null) {
        await _resume(stored, emit);
        return;
      }
    }
    unawaited(_analytics.sessionStarted());
    await _round(emit, _advance);
  }

  /// Picks a stored session up: the pending question goes straight back on
  /// screen. A row saved after the last answer but before its entry was
  /// filed has no pending question; the agent finishes it again.
  Future<void> _resume(OpenSession session, Emitter<SessionState> emit) {
    unawaited(_analytics.sessionResumed());
    _sessionId = session.id;
    _transcript = session.transcript;
    _signature = session.signature;
    _asked.addEntries([
      for (final question in session.questions)
        MapEntry(question.questionId, question),
    ]);
    if (session.pending case final pending?) {
      _asked[pending.question.questionId] = pending.question;
      emit(
        SessionState.awaitingAnswer(
          pending: pending,
          answered: _asked.length - 1,
        ),
      );
      return Future.value();
    }
    return _round(emit, _advance);
  }

  Future<void> _onAnswered(
    SessionAnswered event,
    Emitter<SessionState> emit,
  ) async {
    if (state case SessionAwaitingAnswer(:final pending)) {
      unawaited(_analytics.answerSubmitted(question: pending.question));
      await _round(
        emit,
        () => _advance(
          answer: (toolCallId: pending.toolCallId, answer: event.answer),
        ),
      );
    }
  }

  /// One round with the agent: the transcript and signature held so far
  /// (none starts a session), the [answer] if there is one, and who the
  /// user is as the app knows it now, in the language the screen shows.
  /// Every round goes through here, so no path can forget the context.
  Future<AdvanceResponse> _advance({SessionAnswer? answer}) async =>
      await _agentClient.advance(
        transcript: _transcript,
        signature: _signature,
        answer: answer,
        userContext: (await _userContext.current() ?? const UserContext())
            .copyWith(locale: _locale),
      );

  /// Ends the session, and with it what the app learned about the user for
  /// it (#264).
  @override
  Future<void> close() async {
    await _userContext.close();
    await super.close();
  }

  Future<void> _onRetried(SessionRetried event, Emitter<SessionState> emit) {
    unawaited(_analytics.sessionRetried());
    return _retry(emit);
  }

  Future<void> _round(
    Emitter<SessionState> emit,
    Future<AdvanceResponse> Function() round,
  ) async {
    _retry = (emit) => _round(emit, round);
    emit(SessionState.loading(answered: _asked.length));
    try {
      final response = await round();
      _transcript = response.transcript;
      _signature = response.signature;
      switch (response) {
        case AwaitingAnswer(:final pending):
          final next = _await(pending);
          await _save(pending);
          emit(next);
        case Completed(:final entry):
          await _file(entry, emit);
      }
    } on AgentException catch (error, stackTrace) {
      unawaited(_analytics.sessionFailed(statusCode: error.statusCode));
      unawaited(
        _errors.sessionFailed(error, stackTrace, statusCode: error.statusCode),
      );
      emit(SessionState.failure(reason: _reasonFor(error.code)));
    } on Exception catch (error, stackTrace) {
      _failed(error, stackTrace, SessionFailureReason.unreachable, emit);
    }
  }

  /// Reports a step that failed without an answer from the agent, and says
  /// so on screen.
  void _failed(
    Exception error,
    StackTrace stackTrace,
    SessionFailureReason reason,
    Emitter<SessionState> emit,
  ) {
    unawaited(_analytics.sessionFailed());
    unawaited(_errors.sessionFailed(error, stackTrace));
    emit(SessionState.failure(reason: reason));
  }

  /// What a refusal means for the user; the agent's words never reach the
  /// screen, only its code does. A lapsed sign-in never gets here as such:
  /// the client renews it and resends before giving up.
  static SessionFailureReason _reasonFor(AgentErrorCode? code) =>
      switch (code) {
        AgentErrorCode.modelUnavailable =>
          SessionFailureReason.modelUnavailable,
        AgentErrorCode.invalidSignature ||
        AgentErrorCode.transcriptTooLong => SessionFailureReason.cannotContinue,
        _ => SessionFailureReason.refused,
      };

  /// Drops the session the agent will not continue and begins a fresh one.
  /// Nothing is deleted here: the fresh session's first save replaces the
  /// unfinished row, as every new session does.
  Future<void> _onRestarted(
    SessionRestarted event,
    Emitter<SessionState> emit,
  ) {
    _transcript = null;
    _signature = null;
    _sessionId = null;
    _asked.clear();
    _startedAt = _now();
    unawaited(_analytics.sessionStarted());
    return _round(emit, _advance);
  }

  SessionState _await(PendingQuestion pending) {
    final index = _asked.length;
    _asked[pending.question.questionId] = pending.question;
    unawaited(
      _analytics.questionAsked(question: pending.question, index: index),
    );
    return SessionState.awaitingAnswer(pending: pending, answered: index);
  }

  /// Writes the round to the journal. Best effort: a round that cannot be
  /// saved is still a round, and the row is created on completion at the
  /// latest; the entry is what must not be lost.
  Future<void> _save(PendingQuestion? pending) async {
    try {
      _sessionId = await _repository.saveRound(
        sessionId: _sessionId,
        startedAt: _startedAt,
        transcript: _transcript!,
        signature: _signature!,
        pending: pending,
        questions: _asked.values,
        appVersion: _agentClient.appVersion,
      );
    } on Exception catch (error, stackTrace) {
      unawaited(_analytics.sessionSaveFailed());
      unawaited(
        _errors.sessionSaveFailed(error, stackTrace, sessionId: _sessionId),
      );
    }
  }

  /// Counts the journal now that this entry is in it, so the third one can
  /// be marked (the survey trigger `third_entry_written`). Runs after the
  /// entry is persisted and after `session_completed`, and swallows its own
  /// failure: a milestone that cannot be counted is not worth a session.
  ///
  /// Swallowed towards the user, not towards us — the failure is reported,
  /// because the alternative is a milestone that stops firing and looks
  /// exactly like nobody reaching three entries.
  Future<void> _markMilestone() async {
    try {
      await _analytics.entryWritten(entries: await _repository.countEntries());
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.entryMilestoneFailed(error, stackTrace));
    }
  }

  /// Files the finished [entry]; the session is only over once it is in the
  /// journal, so a failure here is a failure with a retry, not an entry
  /// shown once and gone.
  Future<void> _file(JournalEntry entry, Emitter<SessionState> emit) async {
    _retry = (emit) => _file(entry, emit);
    emit(SessionState.loading(answered: _asked.length));
    try {
      _sessionId ??= await _repository.saveRound(
        sessionId: null,
        startedAt: _startedAt,
        transcript: _transcript!,
        signature: _signature!,
        pending: null,
        questions: _asked.values,
        appVersion: _agentClient.appVersion,
      );
      await _repository.completeSession(
        sessionId: _sessionId!,
        entry: entry,
        questions: _asked.values,
      );
    } on Exception catch (error, stackTrace) {
      unawaited(_analytics.entrySaveFailed());
      unawaited(
        _errors.entrySaveFailed(error, stackTrace, sessionId: _sessionId),
      );
      emit(
        const SessionState.failure(
          reason: SessionFailureReason.entrySaveFailed,
        ),
      );
      return;
    }
    unawaited(_analytics.sessionCompleted(answers: entry.answers.length));
    unawaited(_markMilestone());
    emit(
      SessionState.completed(
        entry: entry,
        questions: Map<String, AskQuestion>.unmodifiable(_asked),
      ),
    );
  }
}
