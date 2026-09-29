import 'dart:ui';

import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(LanguageTagConverter, () {
    const converter = LanguageTagConverter();

    test('encodes a bare language as its code', () {
      expect(converter.toJson(const Locale('de')), 'de');
    });

    test('encodes script and region with hyphens, never underscores', () {
      // `Locale.toString()` writes `de_AT`, which is no language tag.
      expect(converter.toJson(const Locale('de', 'AT')), 'de-AT');
      expect(
        converter.toJson(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ),
        'zh-Hant-TW',
      );
    });

    test('decodes what it encodes', () {
      for (final locale in const [
        Locale('de'),
        Locale('de', 'AT'),
        Locale('es', '419'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      ]) {
        expect(
          converter.fromJson(converter.toJson(locale)),
          locale,
          reason: '$locale',
        );
      }
    });

    test('rejects anything that is not a language tag', () {
      for (final bad in ['de_AT', '', 'german', 'd', 'de-', 'de-DE-x-y']) {
        expect(
          () => converter.fromJson(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });
}
