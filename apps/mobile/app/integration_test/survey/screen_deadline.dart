import 'dart:async';

/// A screen's walk that did not finish within its deadline, and what it
/// was waiting on when the deadline passed.
class ScreenDeadlineExceeded(
  final String screen,
  final Duration limit,
  final String waitingOn,
) implements Exception {
  @override
  String toString() =>
      'survey: $screen did not finish within ${limit.inSeconds} s; '
      'it was at $waitingOn';
}

/// Runs [walk], one screen of the survey, and fails with
/// [ScreenDeadlineExceeded] once [limit] passes, saying what [waitingOn]
/// reports. On Test Lab a step that never finishes otherwise waits out the
/// whole test's timeout (20 minutes on an iPhone) and leaves nothing but
/// "timed out" behind.
Future<T> withinDeadline<T>(
  String screen,
  Duration limit,
  Future<T> Function() walk, {
  required String Function() waitingOn,
}) => walk().timeout(
  limit,
  onTimeout: () => throw ScreenDeadlineExceeded(screen, limit, waitingOn()),
);

/// The walk's trail through the screens: each screen and each step on it,
/// written to the device's log as it happens (Test Lab keeps the log of a
/// run that hung or crashed), and the last of them kept for
/// [ScreenDeadlineExceeded].
class Breadcrumbs(final void Function(String line) log) {
  var _screen = 'launch';

  /// The screen and the step the walk reached last.
  var last = 'launch';

  /// The walk moved on to [name].
  void screen(String name) {
    _screen = name;
    last = name;
    log('survey: $name');
  }

  /// The walk is about to take [step] on the current screen.
  void step(String step) {
    last = '$_screen: $step';
    log('survey: $last');
  }
}
