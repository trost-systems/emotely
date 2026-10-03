/// Build-time configuration, all from `--dart-define`s so nothing
/// environment-specific is committed. This is the only place they are read.
library;

import 'package:feature_auth/feature_auth.dart' show GoogleClientIds;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Where the agent runs (`--dart-define=EMOTELY_AGENT_URL=…`).
const agentUrl = String.fromEnvironment(
  'EMOTELY_AGENT_URL',
  defaultValue: 'https://api.getemotely.com/api/advance-session',
);

/// The PostHog project token (`--dart-define=POSTHOG_KEY=phc_…`). Empty
/// means analytics off: the SDK skips setup and captures go nowhere.
const posthogKey = String.fromEnvironment('POSTHOG_KEY');

/// EU cloud, like the agent (ADR 0004).
const posthogHost = 'https://eu.i.posthog.com';

/// The startup config (`--dart-define=EMOTELY_CONFIG_URL=…`), read once
/// before anything else: it says whether this build may still run and where
/// to send the user if not (#49).
///
/// The store link used to be a `--dart-define` here. It moved to the server,
/// because the only people who ever see it are the ones who cannot install a
/// build carrying a corrected one.
const configUrl = String.fromEnvironment(
  'EMOTELY_CONFIG_URL',
  defaultValue: 'https://api.getemotely.com/api/config',
);

/// The Supabase project (`--dart-define=EMOTELY_SUPABASE_URL=…`). Public by
/// design; row-level security is what protects the data (ADR 0010).
const supabaseUrl = String.fromEnvironment(
  'EMOTELY_SUPABASE_URL',
  defaultValue: 'https://khfkszlujgkfjgnawdlf.supabase.co',
);

/// The project's publishable key
/// (`--dart-define=EMOTELY_SUPABASE_PUBLISHABLE_KEY=sb_publishable_…`).
/// Public like the URL: it only ever acts under the signed-in user's rights.
const supabasePublishableKey = String.fromEnvironment(
  'EMOTELY_SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_di6BB76PPuuoDklt7jtI0w_KlwO_8JF',
);

/// The Cloudflare Turnstile widget's site key
/// (`--dart-define=EMOTELY_TURNSTILE_SITE_KEY=…`), public like the
/// publishable key: it only names the widget. Supabase Auth holds the
/// secret half and checks every token with Cloudflare (#94). The web
/// deletion page uses the same widget, since the project verifies against
/// one secret.
///
/// The default is the production widget `emotely` (managed, domain
/// getemotely.com). A build against a local Supabase stack, whose
/// `config.toml` holds Cloudflare's always-pass test secret, passes
/// Cloudflare's test site key `1x00000000000000000000AA` instead: its dummy
/// token is the only one that secret accepts.
const turnstileSiteKey = String.fromEnvironment(
  'EMOTELY_TURNSTILE_SITE_KEY',
  defaultValue: '0x4AAAAAAFM-YfLo___9K9cj',
);

/// The origin the hidden web view runs the check under. Nothing is loaded
/// from it; Cloudflare only accepts a token from a hostname the widget
/// lists, and the widget lists the site's domain.
const turnstileOrigin = 'https://getemotely.com/';

/// Whether a debug build shows Flutter's DEBUG banner
/// (`--dart-define=EMOTELY_DEBUG_BANNER=false` turns it off). The
/// verification CLI (the run-app skill) turns it off, so screenshots posted
/// as pull request evidence look like the app people install. Profile and
/// release builds have no banner, and outside debug the define is never
/// read.
const debugBanner =
    kDebugMode &&
    bool.fromEnvironment('EMOTELY_DEBUG_BANNER', defaultValue: true);

/// The app's Google OAuth clients (Google Cloud project `emotely-sign-in`),
/// for Sign in with Google (#51). Public identifiers, and deliberately not
/// defines: the iOS client is also baked into `ios/Runner/Info.plist` as
/// its reversed URL scheme, which a define could not follow. Supabase lists
/// the same two in `supabase/config.toml`.
const googleClients = GoogleClientIds(
  server:
      '928057308670-ak9h2h5h8s9rpsgcgto30uf5ecg4thq6'
      '.apps.googleusercontent.com',
  ios:
      '928057308670-dcev1tfqmach6ihsuqntvn5ke2tu46li'
      '.apps.googleusercontent.com',
);

/// A define that has to be an absolute URL, checked once at launch so a bad
/// value fails the launch and names its define — not the first request,
/// somewhere behind the sign-in screen.
Uri urlFrom(String value, {required String define}) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, define, 'must be an absolute URL');
  }
  return uri;
}
