import 'package:analytics/src/post_hog_gate.dart';
import 'package:contract/contract.dart';

/// Product analytics for the session, content-free by construction
/// (ADR 0005): only question ids, answer types, counts and status codes
/// leave the device — never a question text or an answer value. A test
/// drives a whole session with needle strings and proves none escapes.
class const SessionAnalytics({required final PostHogGate gate}) {
  /// The user began a session.
  Future<void> sessionStarted() => gate.capture(eventName: 'session_started');

  /// The agent asked [question] as the [index]th question (0-based).
  Future<void> questionAsked({
    required AskQuestion question,
    required int index,
  }) => gate.capture(
    eventName: 'question_asked',
    properties: {..._describe(question), 'index': index},
  );

  /// The user submitted the widget for [question].
  Future<void> answerSubmitted({required AskQuestion question}) => gate.capture(
    eventName: 'answer_submitted',
    properties: _describe(question),
  );

  /// The agent completed the session with [answers] recorded answers.
  Future<void> sessionCompleted({required int answers}) => gate.capture(
    eventName: 'session_completed',
    properties: {'answers': answers},
  );

  /// An entry was filed and the user now has [entries] of them. Captures
  /// `third_entry_written` on the third and on no other, because that is
  /// the moment the "would you miss emotely?" survey asks about: enough of
  /// a habit to have an opinion, early enough that the answer is still
  /// about starting. PostHog survey targeting cannot take a behavioural
  /// cohort, so the trigger has to be an event of its own; the count is
  /// the caller's, and nothing about the entry itself travels with it.
  Future<void> entryWritten({required int entries}) async {
    if (entries == 3) {
      await gate.capture(eventName: 'third_entry_written');
    }
  }

  /// A round failed; [statusCode] is absent when the server was unreachable.
  Future<void> sessionFailed({int? statusCode}) => gate.capture(
    eventName: 'session_failed',
    properties: {'status_code': ?statusCode},
  );

  /// The user picked an unfinished session up from the journal.
  Future<void> sessionResumed() => gate.capture(eventName: 'session_resumed');

  /// The user retried the failed round.
  Future<void> sessionRetried() => gate.capture(eventName: 'session_retried');

  /// A round could not be written to the journal; the session went on.
  Future<void> sessionSaveFailed() =>
      gate.capture(eventName: 'session_save_failed');

  /// The finished entry could not be filed; the user can retry.
  Future<void> entrySaveFailed() =>
      gate.capture(eventName: 'entry_save_failed');

  /// The server refused [appVersion] and demanded at least [minAppVersion];
  /// the user is on the force-update screen.
  Future<void> updateRequired({
    required String minAppVersion,
    required String appVersion,
  }) => gate.capture(
    eventName: 'update_required',
    properties: {'min_app_version': minAppVersion, 'app_version': appVersion},
  );

  static Map<String, Object> _describe(AskQuestion question) => {
    'question_id': question.questionId,
    'answer_type': question.answerType.name,
  };
}
