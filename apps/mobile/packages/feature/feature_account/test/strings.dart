import 'package:feature_account/src/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The delegates every pump in this package hands the test helpers: this
/// feature's own strings (Flutter's are always added).
const accountLocalizations = [AccountLocalizations.delegate];

/// This feature's strings as the screen on test reads them, in whatever
/// language the device speaks: tests assert a message by its key, never its
/// words, so a rewording changes no test and a string that skipped the ARB
/// files fails wherever the tests run in German.
extension AccountStrings on WidgetTester {
  AccountLocalizations get strings =>
      element(find.byType(Navigator).first).l10n;
}
