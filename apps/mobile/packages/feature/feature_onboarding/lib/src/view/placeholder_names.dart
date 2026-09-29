import 'package:feature_onboarding/src/l10n/l10n.dart';

/// The names given on "Skip for now", in the user's language: playful,
/// gender-neutral, and plainly not anyone's real name, so nobody mistakes
/// one for a name they chose (#204, ADR 0019).
///
/// An ARB file holds no lists, so the translation is one comma-separated
/// message, and its translator picks the names and how many. The screen
/// hands them to the bloc on a skip; the one picked is the user's name from
/// then on, kept as it was picked when the phone's language changes.
extension OnboardingPlaceholderNames on OnboardingLocalizations {
  /// [placeholderNames], one name per entry, trimmed.
  List<String> get placeholderNameList => [
    for (final name in placeholderNames.split(','))
      if (name.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
  ];
}
