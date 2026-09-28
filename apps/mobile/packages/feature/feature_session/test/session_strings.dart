import 'package:feature_session/feature_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The session's own strings, which every pump in this package hands in
/// (ADR 0020); Flutter's are added by the helpers.
const sessionLocalizations = [SessionLocalizations.delegate];

extension SessionStrings on WidgetTester {
  /// The session's strings in whatever locale the test pumped, read from
  /// the tree: an assertion made through them holds in every locale, and a
  /// string that skipped the ARB files fails outside English.
  SessionLocalizations get strings =>
      SessionLocalizations.of(element(find.byType(Navigator).first));
}
