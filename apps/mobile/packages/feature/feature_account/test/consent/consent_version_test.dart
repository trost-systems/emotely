import 'package:feature_account/feature_account.dart';
import 'package:feature_account/src/l10n/account_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;

/// The tripwire that keeps [consentVersion] honest.
///
/// A consent record stores a version and not the text, which only works if a
/// version names exactly one wording. Nothing in the language enforces that:
/// a developer can edit a paragraph and leave the date alone, and then every
/// stored consent points at a text its user never saw, while the app happily
/// never asks again. This test is the enforcement.
///
/// A version names the wording in every language the app ships, one text
/// per locale (ADR 0020 decision 8), so the digest runs over all of them:
/// editing the German trips it exactly as editing the English does.
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
    // 2026-09-26: version and digest. The name the user chose, or the one
    // emotely picked, now goes to the model provider with the
    // answers (#204) — a new piece of personal data to a recipient, so the
    // meaning moved. No tester had consented yet, so nobody was re-asked.
    //
    // 2026-09-28: digest alone. The German wording joined the English
    // (ADR 0020), a faithful translation of the same terms: what is agreed
    // to did not change, so the version stayed 2026-09-26 and nobody was
    // re-asked. The English strings are byte for byte those of 2026-09-26:
    // alone, they still digest to eaf90d83.
    //
    // 2026-09-29: version and digest. The placeholder name is no longer
    // called a nickname ("the name you chose or emotely picked for you"),
    // as CONTEXT.md names it. The same data goes to the same recipient, but
    // a consent names one text, and nobody had consented yet, so the
    // version moved with it rather than the digest alone.
    const wordingDigest = '4fdda4d8';

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
      // Every supported locale, in the order the app lists them.
      final digest = digestOf([
        for (final locale in AccountLocalizations.supportedLocales)
          ...consentWording(lookupAccountLocalizations(locale)),
      ]);

      expect(
        digest,
        wordingDigest,
        reason:
            'The consent wording changed in at least one of '
            '${AccountLocalizations.supportedLocales}. If the meaning moved '
            "(in any language), bump consentVersion to today's date AND set "
            'wordingDigest to $digest — every existing user is then asked '
            'again on their next session, which is the point. If it was only '
            'a typo, or a new faithful translation, that changes nothing '
            'about what is being agreed to, update wordingDigest alone.',
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
      for (final locale in AccountLocalizations.supportedLocales) {
        final strings = lookupAccountLocalizations(locale);
        expect(
          consentWording(strings),
          containsAll(<String>[
            strings.consentTitle,
            for (final point in consentPoints(strings)) ...[
              point.lead,
              point.body,
            ],
            strings.consentCheckboxLabel,
            strings.consentAgreeButton,
            strings.consentDeclineButton,
          ]),
          reason: '$locale',
        );
      }
    });

    // The one place outside the app's localizations test that reads the
    // words themselves: here they are the requirement. Explicit consent has
    // to name what is sent, to whom, what may not be done with it, and a
    // third-country transfer with its safeguard (EDPB 05/2020 para 64 (vi)),
    // in every language the consent is given in. A rewording that drops one
    // fails here, whatever the digest says.
    const requiredPhrases = {
      'en': [
        'the name you chose',
        'emotely picked for you',
        'training',
        'outside the EU',
        'standard contractual clauses',
      ],
      'de': [
        'Namen, den du gewählt hast',
        'den emotely für dich ausgesucht hat',
        'trainieren',
        'außerhalb der EU',
        'Standardvertragsklauseln',
      ],
    };

    test('names every element an explicit consent must, in every language', () {
      expect(
        requiredPhrases.keys,
        unorderedEquals(
          AccountLocalizations.supportedLocales.map((l) => l.languageCode),
        ),
        reason: 'a new locale needs its required phrases here',
      );
      for (final MapEntry(key: language, value: phrases)
          in requiredPhrases.entries) {
        final wording = consentWording(
          lookupAccountLocalizations(Locale(language)),
        ).join(' ');
        for (final phrase in phrases) {
          expect(wording, contains(phrase), reason: language);
        }
      }
    });
  });
}
