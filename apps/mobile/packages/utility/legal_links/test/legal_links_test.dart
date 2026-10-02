import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_links/legal_links.dart';
import 'package:testing/testing.dart';

void main() {
  group('legal links', () {
    testWidgets('open the notice and the imprint in the browser', (
      tester,
    ) async {
      final launcher = UrlLauncherSpy.setup();
      const locale = Locale('de');

      await openPrivacyNotice(locale);
      await openImprint(locale);

      expect(launcher.launched, [privacyNoticeUrl(locale), imprintUrl(locale)]);
    });

    test('point at getemotely.com', () {
      for (final locale in const [Locale('en'), Locale('de')]) {
        expect(Uri.parse(privacyNoticeUrl(locale)).host, 'getemotely.com');
        expect(Uri.parse(imprintUrl(locale)).host, 'getemotely.com');
      }
    });

    // The site has the notice in English and German (#229): a German app
    // opens the German text, any other language the English original,
    // which is what the site serves when it has no translation.
    for (final (locale, notice, imprint) in [
      (
        const Locale('en'),
        'https://getemotely.com/app-privacy',
        'https://getemotely.com/imprint',
      ),
      (
        const Locale('de'),
        'https://getemotely.com/de/app-privacy',
        'https://getemotely.com/de/imprint',
      ),
      (
        const Locale('de', 'AT'),
        'https://getemotely.com/de/app-privacy',
        'https://getemotely.com/de/imprint',
      ),
      (
        const Locale('fr'),
        'https://getemotely.com/app-privacy',
        'https://getemotely.com/imprint',
      ),
    ]) {
      test('$locale opens $notice', () {
        expect(privacyNoticeUrl(locale), notice);
        expect(imprintUrl(locale), imprint);
      });
    }
  });
}
