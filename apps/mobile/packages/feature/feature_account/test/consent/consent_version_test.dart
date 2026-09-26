import 'package:feature_account/src/consent/consent_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tripwire that keeps [consentVersion] honest.
///
/// A consent record stores a version and not the text, which only works if a
/// version names exactly one wording. Nothing in the language enforces that:
/// a developer can edit a paragraph and leave the date alone, and then every
/// stored consent points at a text its user never saw, while the app happily
/// never asks again. This test is the enforcement.
void main() {
  group('consent wording', () {
    // Bump BOTH of these together, never one alone. Changing the wording
    // without changing the version leaves old records naming new text;
    // changing the version without changing the wording re-gates every user
    // for nothing.
    //
    // 2026-09-21: digest alone. "the account screen" became "the More tab"
    // when withdrawal moved there — where the control sits, not what is
    // agreed to — so the version stayed 2026-09-20 and nobody was re-asked.
    //
    // 2026-09-26: version and digest. The name the user chose, or the
    // nickname emotely picked, now goes to the model provider with the
    // answers (#204) — a new piece of personal data to a recipient, so the
    // meaning moved. No tester had consented yet, so nobody was re-asked.
    const wordingDigest = 'eaf90d83';

    /// A stable 32-bit FNV-1a over the wording. Not a security hash and it
    /// does not need to be: it only has to change when the text does, and
    /// it keeps `crypto` from becoming a direct dependency for one
    /// assertion. Masked to 32 bits so the arithmetic is exact everywhere.
    String digestOf(Iterable<String> strings) {
      // The separator keeps "ab" + "c" from colliding with "a" + "bc".
      var hash = 0x811c9dc5;
      for (final code in strings.join('\u0000').codeUnits) {
        hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
      }
      return hash.toRadixString(16).padLeft(8, '0');
    }

    test('has not changed without the version changing', () {
      final digest = digestOf(consentWording);

      expect(
        digest,
        wordingDigest,
        reason:
            'The consent wording changed. If the meaning moved, bump '
            "consentVersion to today's date AND set wordingDigest to "
            '$digest — every existing user is then asked again on their '
            'next session, which is the point. If it was only a typo that '
            'changes nothing about what is being agreed to, update '
            'wordingDigest alone.',
      );
    });

    test('is a date the server will accept', () {
      // `record_consent` refuses anything that is not YYYY-MM-DD, and
      // anything dated after today — a version names the day its wording
      // was published, so it cannot be in the future.
      expect(consentVersion, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(
        DateTime.parse(consentVersion).isAfter(DateTime.now()),
        isFalse,
        reason: 'the server refuses a version dated after today',
      );
    });

    test('covers every string the user reads before deciding', () {
      // A paragraph added to the screen but left out of [consentWording]
      // would be editable without tripping the digest, which would defeat
      // the whole arrangement.
      expect(
        consentWording,
        containsAll(<String>[
          consentTitle,
          for (final point in consentPoints) ...[point.lead, point.body],
          consentCheckboxLabel,
          consentAgreeLabel,
          consentDeclineLabel,
        ]),
      );
    });
  });
}
