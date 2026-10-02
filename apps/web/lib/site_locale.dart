/// The languages the site speaks, and which page has a version in which.
///
/// Language is chosen by path alone: English at `/…`, German at `/de/…`.
/// Nothing reads the browser's language or redirects — Google asks for
/// separate URLs per language and advises against automatic redirection,
/// and a page that looks the same for everyone keeps the site static and
/// cookieless.
library;

import 'package:emotely_web/beta_links.dart';

/// A language of the site.
enum SiteLocale() {
  /// English, the original of every page, at `/…`.
  en,

  /// German, at `/de/…`, for the pages listed in [germanPaths].
  de;

  /// The value of `<html lang>` on a page in this language.
  String get code => name;

  /// Where the page at [englishPath] lives in this language: its German
  /// path when [germanPaths] lists one, otherwise the English page itself —
  /// a German reader following a link to a page not yet translated lands on
  /// the English original rather than on a page that does not exist.
  String pathFor(String englishPath) => switch (this) {
    .en => englishPath,
    .de => germanPaths[englishPath] ?? englishPath,
  };

  /// Whether the page at [englishPath] exists in this language.
  bool has(String englishPath) =>
      this == .en || germanPaths.containsKey(englishPath);
}

/// Every page that exists in German, keyed by its English path. The one
/// table the routes, the links between the languages, the `hreflang`
/// alternates and the tests read.
const germanPaths = {
  '/': '/de',
  '/confirm': '/de/confirm',
  '/app-privacy': '/de/app-privacy',
  '/delete-account': '/de/delete-account',
  '/imprint': '/de/imprint',
  // Unlisted like its original: only the two beta pages name each other.
  betaPath: germanBetaPath,
};

/// The English original of the page at [path]: the path itself for an
/// English page, the table's key for a German one.
String englishPathOf(String path) =>
    [
      for (final MapEntry(key: english, value: german) in germanPaths.entries)
        if (german == path) english,
    ].firstOrNull ??
    path;
