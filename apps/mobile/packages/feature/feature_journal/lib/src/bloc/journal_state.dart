part of 'journal_bloc.dart';

/// What the journal screen shows.
///
/// No generated `toString`: [JournalReady] carries the user's display name,
/// and a `BlocObserver` printing a state must never print it (ADR 0005).
@Freezed(toStringOverride: false)
sealed class JournalState with _$JournalState {
  /// The journal is being read.
  const factory loading() = JournalLoading;

  /// The [entries], newest first, and the session to continue if any; the
  /// user greeted by [displayName], when their profile has one, as of
  /// [now].
  const factory ready({
    required List<EntryRecord> entries,
    required DateTime now,
    OpenSession? openSession,
    String? displayName,
  }) = JournalReady;

  /// The journal could not be read; the screen offers a retry.
  const factory failure() = JournalFailure;
}
