import 'package:feature_session/src/l10n/session_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:feature_session/src/l10n/session_localizations.dart';

/// `context.l10n`: the session feature's own strings (ADR 0020). Not exported
/// from the barrel: `context.l10n` always means the strings of the package the
/// code is in, and every package that shows text declares its own.
extension SessionL10n on BuildContext {
  SessionLocalizations get l10n => SessionLocalizations.of(this);
}
