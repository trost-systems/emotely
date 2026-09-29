import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_locale.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What the frame around every page says, in one language.
final class const _Chrome({
  required final String howItWorks,
  required final String questions,
  required final String imprint,
  required final String privacy,
  required final String appPrivacy,
  required final String deleteAccount,
  required final String untranslated,
  required final String languageName,
  required final String description,
});

const _english = _Chrome(
  howItWorks: 'How it works',
  questions: 'Questions',
  imprint: 'Imprint',
  privacy: 'Privacy',
  appPrivacy: 'App privacy',
  deleteAccount: 'Delete your account',
  untranslated: '',
  languageName: 'English',
  description:
      'emotely asks you a few good questions every evening and writes the '
      'journal entry for you. Five minutes, no blank page, open source, your '
      'words stay yours.',
);

// The words the app itself uses for the same rows (feature_account's
// ARB files): „Impressum“, „Datenschutz“, „Konto löschen“.
const _german = _Chrome(
  howItWorks: 'So funktioniert’s',
  questions: 'Fragen',
  imprint: 'Impressum',
  privacy: 'Datenschutz auf der Website',
  appPrivacy: 'Datenschutz in der App',
  deleteAccount: 'Konto löschen',
  untranslated: ' (auf Englisch)',
  languageName: 'Deutsch',
  description:
      'emotely stellt dir jeden Abend ein paar gute Fragen und schreibt '
      'den Tagebucheintrag für dich. Fünf Minuten, keine leere Seite, Open '
      'Source, deine Worte bleiben deine.',
);

_Chrome _chromeOf(SiteLocale locale) => switch (locale) {
  .en => _english,
  .de => _german,
};

/// The frame of every page in one [locale]: the page's language on
/// `<html lang>`, the `hreflang` alternates of the page at [path], the
/// header with the switch to the other language, the page, the footer.
/// Built only on the server, like the pages it frames.
class const SiteShell({
  required final SiteLocale locale,
  required final String path,
  required final Component child,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final chrome = _chromeOf(locale);
    final home = locale.pathFor('/');
    final english = englishPathOf(path);
    final translated = SiteLocale.de.has(english);
    final other = switch (locale) {
      .en => SiteLocale.de,
      .de => SiteLocale.en,
    };
    return div(classes: 'site', [
      Document.html(attributes: {'lang': locale.code}),
      Document.head(
        // The fallback for a page without a description of its own; a
        // page's own Document.head sits deeper, so it wins.
        meta: {'description': chrome.description},
        children: [
          // Open Graph wants `property`, which Document.meta cannot emit.
          meta(
            attributes: {
              'property': 'og:description',
              'content': chrome.description,
            },
          ),
          // Every version lists every version, itself included, with
          // absolute URLs; x-default is the English original (Google,
          // "Tell Google about localized versions of your page").
          if (translated)
            for (final (hreflang, target) in [
              ('en', english),
              ('de', SiteLocale.de.pathFor(english)),
              ('x-default', english),
            ])
              link(
                rel: 'alternate',
                href: '$siteUrl$target',
                attributes: {'hreflang': hreflang},
              ),
        ],
      ),
      header(classes: 'site-header', [
        a(href: home, classes: 'wordmark', const [.text('emotely')]),
        nav([
          a(href: '$home#how', [.text(chrome.howItWorks)]),
          a(href: '$home#faq', [.text(chrome.questions)]),
          const a(href: repositoryUrl, [.text('GitHub')]),
          // The other language, named in itself, where this page has one:
          // chosen by the reader, never by the browser's language.
          if (translated)
            a(
              href: other.pathFor(english),
              attributes: {'hreflang': other.code, 'lang': other.code},
              [.text(_chromeOf(other).languageName)],
            ),
        ]),
      ]),
      child,
      footer(classes: 'site-footer', [
        p([
          const .text('© 2026 Peter Trost · '),
          PageLink('/imprint', chrome.imprint, locale: locale),
          const .text(' · '),
          PageLink('/privacy', chrome.privacy, locale: locale),
          const .text(' · '),
          // Google Play requires the app's policy to be reachable; the store
          // listings link straight here, and so does every page.
          PageLink('/app-privacy', chrome.appPrivacy, locale: locale),
          const .text(' · '),
          // Google asks for the deletion route to be easy to find, so it
          // sits in the footer of every page rather than only in privacy.
          PageLink('/delete-account', chrome.deleteAccount, locale: locale),
          const .text(' · '),
          const a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
        ]),
      ]),
    ]);
  }
}

/// A link, worded [label], to the page whose English path is [to], in
/// [locale]: its translation where [germanPaths] lists one, otherwise the
/// English original with a note saying so, so a German reader is not
/// surprised by English.
class const PageLink(
  final String to,
  final String label, {
  required final SiteLocale locale,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => a(href: locale.pathFor(to), [
    .text(locale.has(to) ? label : '$label${_chromeOf(locale).untranslated}'),
  ]);
}
