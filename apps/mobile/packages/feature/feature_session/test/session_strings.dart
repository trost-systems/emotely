import 'package:feature_session/src/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The session's own strings, which every pump in this package hands in
/// (ADR 0020); Flutter's are added by the helpers.
const sessionLocalizations = [SessionLocalizations.delegate];

extension SessionStrings on WidgetTester {
  /// The session's strings as the widgets on screen read them, in whatever
  /// language the test pumped: tests assert a message by its key, so a
  /// rewording never breaks them, and a string that skipped the ARB files
  /// fails wherever the test runs in another language.
  SessionLocalizations get strings =>
      element(find.byType(Navigator).first).l10n;
}
