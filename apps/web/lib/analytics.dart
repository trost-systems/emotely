/// The site's PostHog seam. The snippet in `main.server.dart` initializes
/// `window.posthog` cookieless (ADR 0004); `track` is the only caller
/// afterwards. Events carry a source tag and a reason, never an address.
///
/// Conditional export: the browser file talks to JS, the server file (this
/// code also runs during static pre-rendering) does nothing.
library;

export 'package:emotely_web/analytics_stub.dart'
    if (dart.library.js_interop) 'package:emotely_web/analytics_web.dart';
