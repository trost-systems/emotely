import 'package:feature_account/src/l10n/account_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:feature_account/src/l10n/account_localizations.dart';

/// `context.l10n`: feature_account's own strings (ADR 0020). Not exported
/// from the barrel: `context.l10n` always means the strings of the package
/// the code is in, and every package that shows text declares its own.
extension AccountL10n on BuildContext {
  AccountLocalizations get l10n => AccountLocalizations.of(this);
}
