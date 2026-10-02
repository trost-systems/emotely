# apps/web/lib/pages

The privacy notices (`app_privacy.dart`, `privacy.dart`) stay high level:
for each kind of data, what it is, where it goes, why, the legal basis and
how long it is kept. Describe analytics by kind ("screens, taps, timings,
crashes") and leave event names and properties to the code and ADR 0005 —
readers want the map, and a list goes stale with every new event. Every
claim must match the code, a migration or an ADR; `test/pages_test.dart`
pins what the notice says and the overclaims it must never make.

A page under `de/` is the German translation of the English page of the
same name, served at the path `germanPaths` (`lib/site_locale.dart`) gives
it. It carries every claim of the original and nothing else, under the
same section ids, and changes in the same pull request as the original:
`pages_test.dart` mirrors each English claim with the German phrase, and
`site_test.dart` fails when the two differ in sections or headings. German
copy says "du" and uses `CONTEXT.md`'s German terms; link to another page
of the site with `PageLink`, which picks its German version once there is
one.
