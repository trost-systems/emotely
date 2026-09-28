import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tripwire that keeps [usageAnalyticsVersion] honest, the way
/// `consent_version_test.dart` keeps the journal consent's: a record names
/// a version, not a text, which only works if a version names one wording
/// — in every language the app ships (ADR 0020 decision 8).
void main() {
  group('usage analytics wording', () {
    // Bump BOTH of these together, never one alone, unless the edit changes
    // nothing about what is being agreed to (a typo, a new faithful
    // translation): then the digest alone.
    //
    // 2026-09-26: the first wording, published with the first-launch sheet.
    //
    // 2026-09-28: digest alone. The German wording joined the English
    // (ADR 0020), a faithful translation of the same question: what is
    // answered did not change, so the version stayed 2026-09-26 and no
    // answer is recorded again. The English strings are byte for byte those
    // of 2026-09-26: alone, they still digest to 37cf5733.
    const wordingDigest = '80394087';

    /// The same 32-bit FNV-1a over the wording as the journal consent's
    /// tripwire: it only has to change when the text does.
    String digestOf(Iterable<String> strings) {
      // The separator keeps "ab" + "c" from colliding with "a" + "bc".
      var hash = 0x811c9dc5;
      for (final code in strings.join('\u0000').codeUnits) {
        hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
      }
      return hash.toRadixString(16).padLeft(8, '0');
    }

    test('has not changed without the version changing', () {
      // Every supported locale, in the order the app lists them.
      final digest = digestOf([
        for (final locale in AccountLocalizations.supportedLocales)
          ...usageAnalyticsWording(lookupAccountLocalizations(locale)),
      ]);

      expect(
        digest,
        wordingDigest,
        reason:
            'The usage-analytics wording changed in at least one of '
            '${AccountLocalizations.supportedLocales}. If the meaning moved '
            "(in any language), bump usageAnalyticsVersion to today's date "
            'AND set wordingDigest to $digest — every device records its '
            'answer against the new wording on its next sign-in. If it was '
            'only a typo, or a new faithful translation, update '
            'wordingDigest alone.',
      );
    });

    test('is a date the server will accept', () {
      expect(usageAnalyticsVersion, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(
        DateTime.parse(usageAnalyticsVersion).isAfter(DateTime.now()),
        isFalse,
        reason: 'the server refuses a version dated after today',
      );
    });

    test('covers every string the user reads before deciding', () {
      for (final locale in AccountLocalizations.supportedLocales) {
        final strings = lookupAccountLocalizations(locale);
        expect(
          usageAnalyticsWording(strings),
          containsAll(<String>[
            strings.usageAnalyticsTitle,
            strings.usageAnalyticsBody,
            strings.usageAnalyticsCounted,
            strings.usageAnalyticsNever,
            strings.usageAnalyticsDenyButton,
            strings.usageAnalyticsAllowButton,
            strings.usageAnalyticsChangeHint,
          ]),
          reason: '$locale',
        );
      }
    });
  });
}
