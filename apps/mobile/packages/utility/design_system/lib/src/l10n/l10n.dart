import 'package:design_system/src/l10n/design_system_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:design_system/src/l10n/design_system_localizations.dart';

/// `context.l10n`: the words design_system's components say themselves
/// (ADR 0020). Not exported from the barrel: `context.l10n` always means the
/// strings of the package the code is in, and every package that shows text
/// declares its own.
extension DesignSystemL10n on BuildContext {
  DesignSystemLocalizations get l10n => DesignSystemLocalizations.of(this);
}
