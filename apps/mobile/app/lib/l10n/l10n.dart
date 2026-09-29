import 'package:emotely/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:emotely/l10n/app_localizations.dart';

/// `context.l10n`: the app's own strings (ADR 0020).
///
/// Every package that shows text declares this same getter for its own
/// class and never exports it, so `context.l10n` always means the strings of
/// the package the code is in. Two in scope at once would not compile.
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
