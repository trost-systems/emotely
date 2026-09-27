# apps/web

The landing page (Jaspr, Dart), static and cookieless. Attribution is
link-based: the waitlist stores `utm_source/utm_medium/utm_campaign` as the
row's `source` (ADR 0004). Fonts, icons and images are served from
`web/` itself; loading any of them from a third party puts visitor IPs in
someone else's logs (LG München I, 3 O 17493/20), so never add a CDN link.
