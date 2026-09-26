# apps/web

The landing page (Jaspr, Dart), static and cookieless. Attribution is
link-based: the waitlist stores `utm_source/utm_medium/utm_campaign` as the
row's `source` (ADR 0004). Fonts, icons and images are served from
`web/` itself; loading any of them from a third party puts visitor IPs in
someone else's logs (LG München I, 3 O 17493/20), so never add a CDN link.

The privacy notices (`lib/pages/app_privacy.dart`, `lib/pages/privacy.dart`)
stay high level: for each kind of data, what it is, where it goes, why, the
legal basis and how long it is kept. Describe analytics by kind ("screens,
taps, timings, crashes") and leave event names and properties to the code
and ADR 0005 — readers want the map, and a list goes stale with every new
event. Every claim must match the code, a migration or an ADR;
`test/pages_test.dart` pins what the notice says and the overclaims it must
never make.
