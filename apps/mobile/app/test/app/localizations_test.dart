import 'dart:io';

import 'package:emotely/app/localizations.dart';
import 'package:emotely/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../config/config_robot.dart';
import '../helpers/helpers.dart';

/// The app decides which languages ship; every package it composes has to
/// speak all of them (ADR 0020).
void main() {
  group('localizations', () {
    test('ship English and German', () {
      expect(
        supportedLocales,
        unorderedEquals(const [Locale('en'), Locale('de')]),
      );
    });

    test('fall back to English on a device in any other language', () {
      // Flutter falls back to the first supported locale when none of the
      // device's match, and gen-l10n sorts alphabetically unless told
      // otherwise: German would greet every French phone.
      expect(supportedLocales.first, const Locale('en'));
    });

    test('are all declared to iOS', () {
      // iOS hands Flutter only the languages in CFBundleLocalizations: a
      // locale missing there never reaches the app on an iPhone, however
      // complete its ARB files are.
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final declared = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)?.group(1);

      expect(declared, isNotNull, reason: 'Info.plist lists no languages');
      expect(
        RegExp('<string>([^<]+)</string>')
            .allMatches(declared!)
            .map((match) => match.group(1)),
        unorderedEquals(supportedLocales.map((locale) => locale.languageCode)),
      );
    });

    testWidgets('are what a phone in another language reads', (tester) async {
      // The one test in the app that looks at the words themselves: every
      // other test asserts a message by its key, so rewording never breaks
      // it. This one proves the device's language reaches the screen, and
      // that the German is a translation, not the English again.
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final robot = ConfigRobot(
        tester,
        ConfigStub()..script([configMalformed()]),
      );

      await robot.launch();
      await robot.settle();

      final german = robot.strings;
      final english = lookupAppLocalizations(const Locale('en'));
      expect(german.localeName, 'de');
      expect(find.text(german.configUnreadableMessage), findsOneWidget);
      expect(
        german.configUnreadableMessage,
        isNot(english.configUnreadableMessage),
      );
    });

    test('are supported by every delegate, in every shipped locale', () {
      // A package missing a translation fails here, before a user on that
      // locale meets an English screen or a missing-localizations error.
      for (final delegate in localizationsDelegates) {
        for (final locale in supportedLocales) {
          expect(
            delegate.isSupported(locale),
            isTrue,
            reason: '${delegate.type} does not support $locale',
          );
        }
      }
    });
  });
}
