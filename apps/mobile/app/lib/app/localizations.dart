import 'package:design_system/design_system.dart'
    show DesignSystemLocalizations;
import 'package:emotely/l10n/l10n.dart';
import 'package:feature_account/feature_account.dart' show AccountLocalizations;
import 'package:material_ui/material_ui.dart';

/// Every package's strings, then Flutter's own (ADR 0020). A package that
/// shows text owns its generated localizations class; the app lists its
/// delegate here, and the app's test checks that every delegate speaks
/// every locale in [supportedLocales]. The design system's come after the
/// features', its components' own words.
///
/// Flutter's own come from `material_ui`, whose widgets the app uses: its
/// `GlobalMaterialLocalizations` is the one they read, not the copy in
/// `flutter_localizations` that gen-l10n's `localizationsDelegates` lists.
const localizationsDelegates = <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  AccountLocalizations.delegate,
  DesignSystemLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// The languages the app ships, English first: Flutter falls back to the
/// first when the device speaks none of them. They follow the app's own ARB
/// files; adding one also means `CFBundleLocalizations` in the iOS
/// `Info.plist`, or iOS never reports it.
const supportedLocales = AppLocalizations.supportedLocales;
