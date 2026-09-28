import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The delegates every pump in this package hands the test helpers: this
/// feature's own strings (Flutter's are always added).
const accountLocalizations = [AccountLocalizations.delegate];

/// This feature's strings in whatever locale the pumped app shows, read from
/// the tree rather than named in English, so a test holds in every locale
/// and a string that skipped the ARB files fails under any but English.
extension AccountStrings on WidgetTester {
  AccountLocalizations get strings =>
      AccountLocalizations.of(element(find.byType(Navigator).first));
}
