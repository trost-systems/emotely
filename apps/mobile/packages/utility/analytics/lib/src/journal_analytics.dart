import 'package:analytics/src/post_hog_gate.dart';

/// Journal analytics, content-free by construction (ADR 0005): counts and
/// flags only, never a summary or an answer.
class const JournalAnalytics({required final PostHogGate gate}) {
  /// The journal was shown with [entries] entries and, if [openSession], a
  /// session to continue.
  Future<void> journalViewed({
    required int entries,
    required bool openSession,
  }) => gate.capture(
    eventName: 'journal_viewed',
    properties: {'entries': entries, 'open_session': openSession},
  );

  /// The user opened a filed entry.
  Future<void> entryOpened() => gate.capture(eventName: 'entry_opened');

  /// The user dropped an unfinished session.
  Future<void> sessionDiscarded() =>
      gate.capture(eventName: 'session_discarded');
}
