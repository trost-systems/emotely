part of 'session_bloc.dart';

/// What the session screen can ask of [SessionBloc].
@freezed
sealed class SessionEvent with _$SessionEvent {
  /// Begin a fresh session — or, with [resume], pick the stored session of
  /// that id up where it was left. Only the id travels: the bloc reads the
  /// stored round back itself, so a session discarded or finished elsewhere
  /// in the meantime starts fresh rather than resuming a copy.
  ///
  /// [locale] is the one the screen shows (`Localizations.localeOf`), which
  /// only a widget knows: the agent asks and writes the entry in it (#228).
  /// It holds for the whole session, so a question never switches language
  /// half-way.
  const factory started({required Locale locale, String? resume}) =
      SessionStarted;

  /// Submit the widget's answer to the pending question.
  const factory answered(Answer answer) = SessionAnswered;

  /// Repeat the round that failed.
  const factory retried() = SessionRetried;

  /// Give up a session the agent will not continue and begin a fresh one.
  const factory restarted() = SessionRestarted;
}
