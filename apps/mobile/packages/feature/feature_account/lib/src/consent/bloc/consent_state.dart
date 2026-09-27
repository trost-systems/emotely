part of 'consent_bloc.dart';

/// Where consent stands. Carries no journal content and no personal data —
/// only whether a record exists — so the generated `toString` stays.
@freezed
sealed class ConsentState with _$ConsentState {
  /// Not read yet, or being read again. The gate is shut while this holds:
  /// not knowing is not the same as knowing the user consented.
  const factory unknown() = ConsentUnknown;

  /// The server answered: consent to the current wording either stands
  /// ([granted]) or does not. Withdrawn, never asked, and consented to an
  /// older wording are all `granted: false` — all three mean "ask first".
  ///
  /// [justDeclined] marks the one case where the user said no *here*, a
  /// moment ago, rather than simply not having a record. The gate is shut
  /// either way; the difference is only what the journal may truthfully say
  /// about why, so nothing but a message depends on it.
  ///
  /// [since] is when the standing consent was given, when it was asked for
  /// and could be read; nothing depends on it but what a screen says.
  const factory known({
    required bool granted,
    @Default(false) bool justDeclined,
    DateTime? since,
  }) = ConsentKnown;

  /// A grant or a withdrawal is being written.
  const factory busy() = ConsentBusy;

  /// Consent could not be read; the screen offers a retry. Distinct from
  /// `known(granted: false)` on purpose — a failed read must not be shown
  /// as a refusal, nor let a session through.
  const factory failure() = ConsentFailure;

  /// The consent could not be recorded. The session must not start on this:
  /// an unrecorded consent is one the controller cannot demonstrate.
  const factory writeFailure() = ConsentWriteFailure;

  /// The withdrawal could not be recorded; consent still stands on the
  /// server, and the screen says so rather than pretending it is gone.
  const factory withdrawFailure() = ConsentWithdrawFailure;
}

/// What the screens ask of a state, so no widget re-derives it.
extension ConsentStateX on ConsentState {
  /// Whether a session may start right now. Only a read-back `granted: true`
  /// opens the gate: unknown, busy, every failure and every refusal keep it
  /// shut.
  bool get allowsSession => switch (this) {
    ConsentKnown(:final granted) => granted,
    _ => false,
  };
}
