import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent_bloc.freezed.dart';
part 'consent_event.dart';
part 'consent_state.dart';

/// Whether the user has given the explicit consent (Art. 9 (2) (a) GDPR)
/// that a session needs, and the two acts that change it.
///
/// The answer always comes from the server ([ConsentRepository]), never from a
/// flag on this device: a reinstall must not lose it and must not invent it.
/// Every screen that can start a session asks this bloc first, and a session
/// never starts on a consent that was not written down — if the write fails,
/// the state says so and the gate stays shut.
///
/// **Consent is checked before a session, not during one.** On one device
/// that is watertight by construction: the account screen is reachable only
/// from the journal, and a running session is pushed on top of it, so there
/// is no route to the withdraw button without leaving the session first.
/// Across devices it is the re-read in the gate (`refresh`) that closes the
/// window, which is why the gate asks the server every time rather than
/// trusting the answer it read at launch. A session already in flight when
/// consent is withdrawn elsewhere finishes its round; the next one does not
/// start.
///
/// **The gate is in the app, not in the agent.** The agent verifies the JWT
/// and holds no database connection at all — that is ADR 0010 decision 2,
/// and it is why no service-role key exists in this repository or in
/// Vercel. Checking consent there would mean either introducing that key or
/// forwarding the user's token to PostgREST on every round, which the same
/// ADR rejected. So what is true is: **this app does not start a session
/// without a recorded consent**, and a bearer token driven directly against
/// the API would not be stopped by anything here. The trade is recorded in
/// ADR 0014 rather than papered over.
class ConsentBloc({
  required final ConsentRepository _repository,
  required final ConsentAnalytics _analytics,
  required final ErrorReporter _errors,
}) extends Bloc<ConsentEvent, ConsentState> {
  this : super(const ConsentState.unknown()) {
    on<ConsentLoaded>(_onLoaded);
    on<ConsentGranted>(_onGranted);
    on<ConsentWithdrawn>(_onWithdrawn);
    on<ConsentDeclined>(_onDeclined);
  }

  Future<void> _onLoaded(
    ConsentLoaded event,
    Emitter<ConsentState> emit,
  ) async {
    emit(const ConsentState.unknown());
    final bool granted;
    try {
      granted = await _repository.isGranted();
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.consentLoadFailed(error, stackTrace));
      emit(const ConsentState.failure());
      return;
    }
    emit(
      ConsentState.known(
        granted: granted,
        since: granted && event.withDate ? await _since() : null,
      ),
    );
  }

  /// When the standing consent was given, if that can be read: the screen
  /// says so when it can and simply leaves it out when it cannot, so a
  /// failed read here is neither shown nor worth a report.
  Future<DateTime?> _since() async {
    try {
      return await _repository.grantedAt();
    } on Exception {
      return null;
    }
  }

  /// The user ticked the box and pressed the button. The session may start
  /// only once the server has the record, so the failure path emits a
  /// failure rather than a granted state.
  Future<void> _onGranted(
    ConsentGranted event,
    Emitter<ConsentState> emit,
  ) async {
    // A second tap while the first is in flight would write the same row
    // again (harmlessly) but could race the state back to `busy` after the
    // screen had already left. One at a time.
    if (state is ConsentBusy) {
      return;
    }
    emit(const ConsentState.busy());
    try {
      await _repository.grant();
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.consentWriteFailed(error, stackTrace));
      emit(const ConsentState.writeFailure());
      return;
    }
    unawaited(_analytics.consentGranted());
    emit(const ConsentState.known(granted: true));
  }

  /// The user took their consent back (Art. 7 (3)). Same shape as granting,
  /// because taking it back must be no harder than giving it.
  Future<void> _onWithdrawn(
    ConsentWithdrawn event,
    Emitter<ConsentState> emit,
  ) async {
    if (state is ConsentBusy) {
      return;
    }
    emit(const ConsentState.busy());
    try {
      await _repository.withdraw();
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.consentWriteFailed(error, stackTrace));
      emit(const ConsentState.withdrawFailure());
      return;
    }
    unawaited(_analytics.consentWithdrawn());
    emit(const ConsentState.known(granted: false));
  }

  /// The user declined. Nothing is written: a refusal is the absence of a
  /// consent, not a record of its own, and inventing a row for it would be
  /// storing a decision the user did not ask us to keep.
  void _onDeclined(ConsentDeclined event, Emitter<ConsentState> emit) {
    unawaited(_analytics.consentDeclined());
    emit(const ConsentState.known(granted: false, justDeclined: true));
  }

  /// Reads the record again and waits for the answer, for the callers that
  /// must not act on a stale one — the gate, above all.
  ///
  /// The state at hand can be minutes old and was read on this device: a
  /// withdrawal made on another device (or on the web) would not be in it,
  /// and starting a session on that stale yes is exactly what withdrawal is
  /// supposed to prevent. Cheap enough to do on the way into every session.
  Future<void> refresh() {
    final settled = stream.firstWhere((state) => state is! ConsentUnknown);
    add(const ConsentEvent.loaded());
    return settled;
  }
}
