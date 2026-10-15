# apps/web

The landing page (Jaspr, Dart), static and cookieless. Attribution is
link-based: the waitlist stores `utm_source/utm_medium/utm_campaign` as the
row's `source` (ADR 0004). Fonts, icons and images are served from
`web/` itself; loading any of them from a third party puts visitor IPs in
someone else's logs (LG München I, 3 O 17493/20), so never add a CDN link.

The two outside scripts are PostHog's (every page, EU) and Cloudflare
Turnstile's, which Cloudflare forbids proxying or self-hosting. Turnstile
loads only from `lib/turnstile_web.dart`, only on the deletion page and
only once its reader asks for a code (#94); the site privacy notice says
exactly that. Another page that needs a human check calls
`turnstileToken` on the reader's action the same way, and the notice
names the page.
