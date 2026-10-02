import 'dart:ui' show Locale;

import 'package:url_launcher/url_launcher.dart';

const _site = 'https://getemotely.com';

/// The path prefix of the site's pages in [locale]'s language. The site has
/// English at `/…` and German at `/de/…` (#229); any other language gets
/// the English original rather than a page that does not exist.
String _prefix(Locale locale) => switch (locale.languageCode) {
  'de' => '/de',
  _ => '',
};

/// Where the app's privacy notice lives, in the language the app shows
/// ([locale], from `Localizations.localeOf`). Apple guideline 5.1.1 (i) and
/// Google Play's User Data policy both require it to be reachable from
/// inside the app, not only from the store listing.
String privacyNoticeUrl(Locale locale) =>
    '$_site${_prefix(locale)}/app-privacy';

/// The imprint § 5 DDG asks of a German provider, in [locale]'s language;
/// linked next to the notice.
String imprintUrl(Locale locale) => '$_site${_prefix(locale)}/imprint';

/// Opens the full notice in the browser, in [locale]'s language.
/// Fire-and-forget: if no browser can be opened there is nothing a screen
/// can do, and what the screen says already covers the essentials.
Future<void> openPrivacyNotice(Locale locale) => launchUrl(
  Uri.parse(privacyNoticeUrl(locale)),
  mode: LaunchMode.externalApplication,
);

/// Opens the imprint (§ 5 DDG), in [locale]'s language.
Future<void> openImprint(Locale locale) => launchUrl(
  Uri.parse(imprintUrl(locale)),
  mode: LaunchMode.externalApplication,
);
