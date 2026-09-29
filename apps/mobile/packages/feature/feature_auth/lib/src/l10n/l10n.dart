import 'package:feature_auth/src/l10n/auth_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:feature_auth/src/l10n/auth_localizations.dart';

/// `context.l10n`: feature_auth's own strings (ADR 0020). Not exported from
/// the barrel: `context.l10n` always means the strings of the package the
/// code is in, and every package that shows text declares its own.
extension AuthL10n on BuildContext {
  AuthLocalizations get l10n => AuthLocalizations.of(this);
}
