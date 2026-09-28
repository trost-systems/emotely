import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

// Every helper below takes the strings of the package under test and the
// locale to show them in (ADR 0020). `testing` cannot import a feature, so a
// feature's tests hand in its own class's delegate:
//
//     pageUnderTest(
//       const EntryPage(),
//       localizations: const [JournalLocalizations.delegate],
//     )
//
// Flutter's own strings (back buttons, dialogs, pickers) are always there,
// from `material_ui`, whose widgets the app uses.
//
// Read a string through the package's own class
// (`lookupJournalLocalizations(locale).entryTitle`), never as a literal: the
// same test then holds in every locale, and a string that bypassed the ARB
// files shows in English whatever locale is asked for, so it fails.

/// The delegates a helper pumps with: the package's own, then Flutter's.
List<LocalizationsDelegate<Object?>> _delegates(
  Iterable<LocalizationsDelegate<Object?>> localizations,
) => [...localizations, ...GlobalMaterialLocalizations.delegates];

/// Wraps [child] the way the app does: real themes, a scaffold, no mocked
/// chrome. Use it wherever a bare widget must be pumped, e.g. for the
/// accessibility check.
Widget appWrapper(
  Widget child, {
  ThemeMode themeMode = ThemeMode.light,
  Iterable<LocalizationsDelegate<Object?>> localizations = const [],
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  localizationsDelegates: _delegates(localizations),
  supportedLocales: [locale],
  locale: locale,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

/// Standard app wrapper for widget tests.
/// A whole page — one that brings its own Scaffold — under the app's themes,
/// the way the app's navigator would show it.
Widget pageUnderTest(
  Widget page, {
  ThemeMode themeMode = ThemeMode.light,
  Iterable<LocalizationsDelegate<Object?>> localizations = const [],
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  localizationsDelegates: _delegates(localizations),
  supportedLocales: [locale],
  locale: locale,
  home: page,
);

/// A feature's own routes under the app's themes and a router of their own,
/// opened at [initialLocation] — the way the app mounts them (ADR 0016),
/// without the app. [above] wraps the navigator, where the app puts what
/// every screen needs over it (the auth bloc, the startup gate); tests
/// hand in only what the routes under test read.
Widget featureUnderTest({
  required List<RouteBase> routes,
  required String initialLocation,
  Widget Function(BuildContext context, Widget child)? above,
  ThemeMode themeMode = ThemeMode.light,
  Iterable<LocalizationsDelegate<Object?>> localizations = const [],
  Locale locale = const Locale('en'),
}) => MaterialApp.router(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: themeMode,
  localizationsDelegates: _delegates(localizations),
  supportedLocales: [locale],
  locale: locale,
  routerConfig: GoRouter(routes: routes, initialLocation: initialLocation),
  builder: above == null
      ? null
      : (context, child) => above(context, child ?? const SizedBox.shrink()),
);

extension PumpApp on WidgetTester {
  /// Taps the app bar's back button and settles, in any locale.
  /// `WidgetTester.pageBack` finds the button by its English tooltip, "Back",
  /// so it finds nothing on a German screen.
  Future<void> tapBack() async {
    await tap(find.byType(BackButton));
    await pumpAndSettle();
  }

  /// Pumps [widget] inside a themed [MaterialApp] scaffold.
  Future<void> pumpApp(
    Widget widget, {
    ThemeMode themeMode = ThemeMode.light,
    Iterable<LocalizationsDelegate<Object?>> localizations = const [],
    Locale locale = const Locale('en'),
  }) => pumpWidget(
    appWrapper(
      widget,
      themeMode: themeMode,
      localizations: localizations,
      locale: locale,
    ),
  );
}
