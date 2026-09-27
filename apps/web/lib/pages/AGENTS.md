# apps/web/lib/pages

The privacy notices (`app_privacy.dart`, `privacy.dart`) stay high level:
for each kind of data, what it is, where it goes, why, the legal basis and
how long it is kept. Describe analytics by kind ("screens, taps, timings,
crashes") and leave event names and properties to the code and ADR 0005 —
readers want the map, and a list goes stale with every new event. Every
claim must match the code, a migration or an ADR; `test/pages_test.dart`
pins what the notice says and the overclaims it must never make.
