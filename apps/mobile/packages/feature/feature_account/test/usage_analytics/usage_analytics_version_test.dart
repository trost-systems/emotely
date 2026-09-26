import 'package:feature_account/src/usage_analytics/usage_analytics_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tripwire that keeps [usageAnalyticsVersion] honest, the way
/// `consent_version_test.dart` keeps the journal consent's: a record names
/// a version, not a text, which only works if a version names one wording.
void main() {
  group('usage analytics wording', () {
    // Bump BOTH of these together, never one alone, unless the edit changes
    // nothing about what is being agreed to (a typo): then the digest alone.
    //
    // 2026-09-26: the first wording, published with the first-launch sheet.
    const wordingDigest = '37cf5733';

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
      final digest = digestOf(usageAnalyticsWording);

      expect(
        digest,
        wordingDigest,
        reason:
            'The usage-analytics wording changed. If the meaning moved, bump '
            "usageAnalyticsVersion to today's date AND set wordingDigest to "
            '$digest — every device records its answer against the new '
            'wording on its next sign-in. If it was only a typo, update '
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
      expect(
        usageAnalyticsWording,
        containsAll(<String>[
          usageAnalyticsTitle,
          usageAnalyticsBody,
          usageAnalyticsCounted,
          usageAnalyticsNever,
          usageAnalyticsDenyLabel,
          usageAnalyticsAllowLabel,
          usageAnalyticsChangeHint,
        ]),
      );
    });
  });
}
