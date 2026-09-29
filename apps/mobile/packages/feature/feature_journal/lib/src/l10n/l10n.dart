import 'package:feature_journal/src/l10n/journal_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:feature_journal/src/l10n/journal_localizations.dart';

/// `context.l10n`: feature_journal's own strings (ADR 0020). Not exported from
/// the barrel: `context.l10n` always means the strings of the package the
/// code is in, and every package that shows text declares its own.
extension JournalL10n on BuildContext {
  JournalLocalizations get l10n => JournalLocalizations.of(this);
}
