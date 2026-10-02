import 'package:emotely_web/main.server.options.dart';
import 'package:emotely_web/site_document.dart';
import 'package:emotely_web/site_locale.dart';
import 'package:html/dom.dart' as html;
import 'package:jaspr/server.dart';
import 'package:jaspr_test/server_test.dart';

/// Renders [path] the way `jaspr build` does and returns the document.
Future<html.Document> _render(ServerTester tester, String path) async {
  tester.pumpComponent(siteDocument());
  final response = await tester.request(path);
  expect(response.statusCode, 200, reason: path);
  return response.document!;
}

Map<String, String> _alternates(html.Document document) => {
  for (final link in document.querySelectorAll('link[rel="alternate"]'))
    link.attributes['hreflang']!: link.attributes['href']!,
};

Iterable<String> _hrefs(html.Element element) => element
    .querySelectorAll('a')
    .map((link) => link.attributes['href'])
    .nonNulls;

void main() {
  setUpAll(() => Jaspr.initializeApp(options: defaultServerOptions));

  group('SiteLocale', () {
    test('an English path maps to its German page where one exists', () {
      expect(SiteLocale.de.pathFor('/app-privacy'), '/de/app-privacy');
      expect(SiteLocale.de.pathFor('/imprint'), '/de/imprint');
    });

    test('a page without a German version stays English in German', () {
      expect(SiteLocale.de.pathFor('/privacy'), '/privacy');
    });

    test('English always maps to itself', () {
      expect(SiteLocale.en.pathFor('/app-privacy'), '/app-privacy');
      expect(SiteLocale.en.pathFor('/'), '/');
    });

    test('every German path lives under /de', () {
      for (final path in germanPaths.values) {
        expect(path, anyOf('/de', startsWith('/de/')));
      }
    });

    test('the landing page and its islands exist in German', () {
      expect(SiteLocale.de.pathFor('/'), '/de');
      expect(SiteLocale.de.pathFor('/confirm'), '/de/confirm');
      expect(SiteLocale.de.pathFor('/delete-account'), '/de/delete-account');
      expect(SiteLocale.de.pathFor('/beta'), '/de/beta');
    });

    test('a German path leads back to its English original', () {
      expect(englishPathOf('/de/imprint'), '/imprint');
      expect(englishPathOf('/de'), '/');
      expect(englishPathOf('/imprint'), '/imprint');
    });
  });

  group('Alternate languages', () {
    // Google reads hreflang only when every version lists every version,
    // itself included, with absolute URLs; x-default names the page for a
    // reader whose language the site does not speak (English).
    for (final MapEntry(key: english, value: german) in germanPaths.entries) {
      final expected = {
        'en': 'https://getemotely.com$english',
        'de': 'https://getemotely.com$german',
        'x-default': 'https://getemotely.com$english',
      };

      testServer('$english and $german list each other and themselves', (
        tester,
      ) async {
        expect(_alternates(await _render(tester, english)), expected);
        expect(_alternates(await _render(tester, german)), expected);
      });
    }

    testServer('a page in one language only lists no alternates', (
      tester,
    ) async {
      expect(_alternates(await _render(tester, '/privacy')), isEmpty);
    });
  });

  group('Language switch', () {
    html.Element? languageSwitch(html.Document document) =>
        document.querySelector('.site-header a[hreflang]');

    testServer('an English page offers its German version', (tester) async {
      final link = languageSwitch(await _render(tester, '/'))!;

      expect(link.attributes['href'], '/de');
      expect(link.attributes['hreflang'], 'de');
      expect(link.attributes['lang'], 'de');
      expect(link.text, 'Deutsch');
    });

    testServer('a German page offers its English original', (tester) async {
      final link = languageSwitch(await _render(tester, '/de/app-privacy'))!;

      expect(link.attributes['href'], '/app-privacy');
      expect(link.attributes['hreflang'], 'en');
      expect(link.attributes['lang'], 'en');
      expect(link.text, 'English');
    });

    testServer('a page in one language only offers no switch', (tester) async {
      expect(languageSwitch(await _render(tester, '/privacy')), isNull);
    });
  });

  group('Beta', () {
    // Unlisted in both languages: the two beta pages may name each other
    // (the language switch), and nothing else on the site names either.
    testServer('nothing but the beta pages links to them', (tester) async {
      const betaPaths = {'/beta', '/de/beta'};
      final pages = {
        ...germanPaths.keys,
        ...germanPaths.values,
        '/privacy',
      }.difference(betaPaths);
      for (final path in pages) {
        final document = await _render(tester, path);

        expect(
          _hrefs(document.body!).where(betaPaths.contains),
          isEmpty,
          reason: path,
        );
        expect(
          _alternates(document).values
              .any((href) => betaPaths.any(href.endsWith)),
          isFalse,
          reason: path,
        );
      }
    });
  });

  group('Language of a page', () {
    // Screen readers pick their voice, and browsers their hyphenation and
    // translation offer, from <html lang>; a German page announced as
    // English is read out in an English voice.
    for (final (path, lang) in [
      ('/', 'en'),
      ('/app-privacy', 'en'),
      ('/imprint', 'en'),
      ('/de/app-privacy', 'de'),
      ('/de/imprint', 'de'),
    ]) {
      testServer('$path is declared "$lang"', (tester) async {
        final document = await _render(tester, path);

        expect(document.documentElement!.attributes['lang'], lang);
      });
    }
  });

  group('Description', () {
    String? description(html.Document document) => document
        .querySelector('meta[name="description"]')
        ?.attributes['content'];

    // A German page without a description of its own would show a search
    // engine the English one.
    testServer('a German page falls back to a German description', (
      tester,
    ) async {
      final document = await _render(tester, '/de/imprint');

      expect(description(document), contains('Tagebucheintrag'));
    });

    testServer('a page’s own description wins over the fallback', (
      tester,
    ) async {
      final document = await _render(tester, '/de/app-privacy');

      expect(description(document), startsWith('Wie die emotely-App'));
    });

    testServer('an English page keeps the English description', (tester) async {
      final document = await _render(tester, '/imprint');

      expect(description(document), contains('journal entry'));
    });
  });

  group('Every German page and its English original', () {
    // A translation, not a second page: the same anchors, so a link to
    // #faq lands in the same place in either language, and the same
    // headings, so a section added to one alone fails here.
    for (final MapEntry(key: english, value: german) in germanPaths.entries) {
      testServer('$german has the sections and headings of $english', (
        tester,
      ) async {
        final englishPage = await _render(tester, english);
        final germanPage = await _render(tester, german);

        List<String> ids(html.Document document) => document
            .querySelectorAll('main [id]')
            .map((element) => element.id)
            .toList();
        List<int> headings(html.Document document) => [
          for (final tag in ['h1', 'h2', 'h3'])
            document.querySelectorAll('main $tag').length,
        ];

        expect(ids(germanPage), ids(englishPage));
        expect(headings(germanPage), headings(englishPage));
      });
    }
  });

  group('Every German page', () {
    // The table is what the links between the languages read; a path in it
    // without its route would be a link to nothing.
    for (final MapEntry(key: english, value: german) in germanPaths.entries) {
      testServer('$german renders, in German, beside $english', (tester) async {
        final germanPage = await _render(tester, german);
        final englishPage = await _render(tester, english);

        expect(germanPage.documentElement!.attributes['lang'], 'de');
        expect(englishPage.documentElement!.attributes['lang'], 'en');
      });
    }
  });

  group('Footer', () {
    testServer('English pages link the English legal pages', (tester) async {
      final document = await _render(tester, '/app-privacy');
      final footer = document.querySelector('.site-footer')!;

      expect(footer.text, contains('Imprint'));
      expect(footer.text, contains('App privacy'));
      expect(
        _hrefs(footer),
        containsAll(['/imprint', '/privacy', '/app-privacy']),
      );
    });

    testServer('German pages link the German legal pages', (tester) async {
      final document = await _render(tester, '/de/app-privacy');
      final footer = document.querySelector('.site-footer')!;

      expect(footer.text, contains('Impressum'));
      expect(footer.text, contains('Datenschutz in der App'));
      expect(footer.text, contains('Konto löschen'));
      expect(_hrefs(footer), containsAll(['/de/imprint', '/de/app-privacy']));
      // The site notice has no German version yet, and the link says so
      // rather than surprising a German reader with English.
      expect(_hrefs(footer), contains('/privacy'));
      expect(footer.text, contains('auf Englisch'));
      expect(footer.text, isNot(contains('Imprint')));
    });

    testServer('German pages carry a German header', (tester) async {
      final document = await _render(tester, '/de/imprint');
      final header = document.querySelector('.site-header')!;

      expect(header.text, contains('So funktioniert’s'));
      expect(header.text, contains('Fragen'));
      expect(header.text, isNot(contains('How it works')));
    });
  });

  group('German notice and its English original', () {
    // The German notice is a translation, not a second text: the same
    // sections under the same anchors, so a link to #rights lands in the
    // same place in either language, and a section added to one without
    // the other fails here.
    testServer('have the same section ids and the same headings', (
      tester,
    ) async {
      final english = await _render(tester, '/app-privacy');
      final german = await _render(tester, '/de/app-privacy');

      List<String> ids(html.Document document) => document
          .querySelectorAll('main [id]')
          .map((element) => element.id)
          .toList();
      Map<String, int> headings(html.Document document) => {
        for (final tag in ['h1', 'h2', 'h3', 'li', 'p', 'strong'])
          tag: document.querySelectorAll('main $tag').length,
      };
      List<String> anchors(html.Document document) => document
          .querySelectorAll('main nav.toc a')
          .map((link) => link.attributes['href']!)
          .toList();

      expect(ids(german), ids(english));
      expect(ids(english), isNotEmpty);
      expect(headings(german), headings(english));
      expect(anchors(german), anchors(english));
    });

    testServer('the imprints have the same shape', (tester) async {
      final english = await _render(tester, '/imprint');
      final german = await _render(tester, '/de/imprint');

      for (final tag in ['h1', 'h2', 'p', 'br', 'a']) {
        expect(
          german.querySelectorAll('main $tag').length,
          english.querySelectorAll('main $tag').length,
          reason: tag,
        );
      }
    });
  });
}
