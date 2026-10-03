/// The site's seam to Cloudflare Turnstile, the human check GoTrue demands
/// before it mails a code (#94). Only the deletion page asks for one, and
/// only once its reader asks for a code: no other page loads Cloudflare's
/// script, so no other visitor's address reaches Cloudflare.
///
/// Conditional export, like `analytics.dart`: the browser file talks to
/// JS, the server file (this code also runs during static pre-rendering)
/// has no browser to check.
library;

export 'package:emotely_web/turnstile_stub.dart'
    if (dart.library.js_interop) 'package:emotely_web/turnstile_web.dart';
