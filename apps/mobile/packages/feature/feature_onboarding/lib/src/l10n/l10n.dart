import 'package:feature_onboarding/src/l10n/onboarding_localizations.dart';
import 'package:material_ui/material_ui.dart';

export 'package:feature_onboarding/src/l10n/onboarding_localizations.dart';

/// `context.l10n`: onboarding's own strings (ADR 0020). Not exported from
/// the barrel: `context.l10n` always means the strings of the package the
/// code is in, and every package that shows text declares its own.
extension OnboardingL10n on BuildContext {
  OnboardingLocalizations get l10n => OnboardingLocalizations.of(this);
}
