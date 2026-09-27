import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:profile_repository/profile_repository.dart';

part 'journal_bloc.freezed.dart';
part 'journal_event.dart';
part 'journal_state.dart';

/// The journal as the home screen shows it: every filed entry, the session
/// still in progress if there is one, and the name the user is greeted by
/// (#204) at the time of day [_now] says it is.
class JournalBloc({
  required final JournalRepository _repository,
  required final ConsentRepository _consent,
  required final JournalAnalytics _analytics,
  required final ProfileRepository _profiles,
  required final ErrorReporter _errors,
  final DateTime Function() _now = DateTime.now,
}) extends Bloc<JournalEvent, JournalState> {
  this : super(const JournalState.loading()) {
    on<JournalLoaded>(_onLoaded);
    on<JournalSessionDiscarded>(_onSessionDiscarded);
    on<JournalEntryOpened>(_onEntryOpened);
  }

  Future<void> _onLoaded(
    JournalLoaded event,
    Emitter<JournalState> emit,
  ) async {
    emit(const JournalState.loading());
    final name = _displayName();
    try {
      final entries = await _repository.entries();
      final openSession = await _repository.openSession();
      unawaited(
        _analytics.journalViewed(
          entries: entries.length,
          openSession: openSession != null,
        ),
      );
      emit(
        JournalState.ready(
          entries: entries,
          openSession: openSession,
          displayName: await name,
          now: _now(),
        ),
      );
    } on Exception {
      emit(const JournalState.failure());
    }
  }

  /// The name the journal greets by. A profile that cannot be read leaves
  /// the greeting without a name, never the journal without its entries.
  Future<String?> _displayName() async {
    try {
      return (await _profiles.profile())?.displayName;
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.profileLoadFailed(error, stackTrace));
      return null;
    }
  }

  /// Whether consent stands right now, read from the server and never from
  /// the answer this device happened to read earlier: a withdrawal made on
  /// another device must stop this one before anything is sent (ADR 0014).
  /// A read that fails counts as not standing — the gate stays shut, and
  /// the consent screen, which reads again, says what happened.
  Future<bool> consentStands() async {
    try {
      return await _consent.isGranted();
    } on Exception {
      return false;
    }
  }

  void _onEntryOpened(JournalEntryOpened event, Emitter<JournalState> emit) =>
      unawaited(_analytics.entryOpened());

  Future<void> _onSessionDiscarded(
    JournalSessionDiscarded event,
    Emitter<JournalState> emit,
  ) async {
    if (state case JournalReady(openSession: final session?)) {
      emit(const JournalState.loading());
      try {
        await _repository.discardSession(session.id);
        unawaited(_analytics.sessionDiscarded());
      } on Exception {
        emit(const JournalState.failure());
        return;
      }
      await _onLoaded(const JournalLoaded(), emit);
    }
  }
}
