/// Build-time configuration, all `-D` defines so nothing environment-specific
/// is committed; this is the only place they are read. Both values are public
/// by design (ADR 0010): the key only ever acts as `anon`, and what `anon`
/// may do to the waitlist is decided in Postgres (ADR 0011).
library;

/// The Supabase project (`-DEMOTELY_SUPABASE_URL=…`).
final supabaseUrl = Uri.parse(
  const String.fromEnvironment(
    'EMOTELY_SUPABASE_URL',
    defaultValue: 'https://khfkszlujgkfjgnawdlf.supabase.co',
  ),
);

/// The project's publishable key (`-DEMOTELY_SUPABASE_PUBLISHABLE_KEY=…`).
const supabasePublishableKey = String.fromEnvironment(
  'EMOTELY_SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_di6BB76PPuuoDklt7jtI0w_KlwO_8JF',
);

/// The PostHog project token (`-DPOSTHOG_KEY=phc_…`), the same project as
/// the app (ADR 0004). Empty means analytics off: no script is emitted.
const posthogKey = String.fromEnvironment('POSTHOG_KEY');

/// EU cloud, like the app and the agent.
const posthogHost = 'https://eu.i.posthog.com';

/// Where the code lives; the site links to it everywhere trust is asked for.
const repositoryUrl = 'https://github.com/trost-systems/emotely';

/// The support and sender address (a Google Group behind the domain).
const contactEmail = 'hello@getemotely.com';

/// The site's own origin, for the absolute URLs `hreflang` alternates need.
const siteUrl = 'https://getemotely.com';
