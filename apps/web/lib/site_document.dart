/// The HTML document every route is rendered into: the `<head>` the whole
/// site shares, and the app as its body. Kept apart from `main.server.dart`
/// so tests render exactly what the build writes.
library;

import 'package:emotely_web/app.dart';
import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

const _description =
    'emotely asks you a few good questions every evening and writes the '
    'journal entry for you. Five minutes, no blank page, open source, your '
    'words stay yours.';

/// PostHog, cookieless (ADR 0004): nothing is stored in the browser, no
/// person profiles, no autocapture, no replay, no surveys. The library is
/// loaded deferred from the EU asset host and initialised once the document
/// is ready; `lib/analytics.dart` is the only caller afterwards.
const _posthogInit =
    "window.addEventListener('DOMContentLoaded',function(){"
    "window.posthog&&window.posthog.init('$posthogKey',{"
    "api_host:'$posthogHost',defaults:'2026-08-29',"
    "cookieless_mode:'always',person_profiles:'never',"
    'autocapture:false,capture_pageview:true,'
    'disable_session_recording:true,disable_surveys:true})})';

/// The document. `<html lang>` is not set here: each page's shell sets it
/// for the language the page is written in (`SiteShell`).
Component siteDocument() => Document(
  title: 'emotely — a journal that asks, listens and writes',
  meta: const {'description': _description, 'theme-color': '#f6f1e9'},
  head: [
    // Open Graph wants `property`, which Document.meta cannot emit.
    const meta(attributes: {'property': 'og:title', 'content': 'emotely'}),
    const meta(
      attributes: {'property': 'og:description', 'content': _description},
    ),
    const meta(attributes: {'property': 'og:type', 'content': 'website'}),
    const meta(
      attributes: {'property': 'og:url', 'content': 'https://getemotely.com/'},
    ),
    const link(rel: 'stylesheet', href: '/styles.css'),
    // The legacy emotely mark: the ICO for old browsers and Safari, the
    // SVG for the rest, the PNG for home screens.
    const link(
      rel: 'icon',
      href: '/favicon.ico',
      attributes: {'sizes': '32x32'},
    ),
    const link(
      rel: 'icon',
      href: '/favicon.svg',
      attributes: {'type': 'image/svg+xml'},
    ),
    const link(rel: 'apple-touch-icon', href: '/apple-touch-icon.png'),
    // Fonts are self-hosted (see styles.css); the body face is preloaded
    // so the first paint is already in it.
    const link(
      rel: 'preload',
      href: '/fonts/baskervville-latin.woff2',
      attributes: {'as': 'font', 'type': 'font/woff2', 'crossorigin': ''},
    ),
    if (posthogKey.isNotEmpty) ...[
      const script(
        src: 'https://eu-assets.i.posthog.com/static/array.js',
        defer: true,
        attributes: {'crossorigin': 'anonymous'},
      ),
      const script(content: _posthogInit),
    ],
  ],
  body: const App(),
);
