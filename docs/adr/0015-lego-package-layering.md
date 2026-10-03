# Lego package layering for the Flutter client

The Flutter client (`apps/mobile`) is a pub workspace of packages in three
tiers, after Tide's "Project Miniclient" architecture:

- **utilities** (`packages/utility/*`) depend only on other utilities;
- **features** (`packages/feature/*`) depend only on utilities, and never on
  another feature;
- **the app** (`app`) is glue: it depends on anything and composes the
  features.

Every package carries its own gates — codegen tripwire, format, analyze
against the one shared rule set (`packages/utility/analysis`), and the hard
100% coverage gate — and CI runs those gates only for the packages a pull
request changed plus their dependents (`melos run ci`, scoped through
`EMOTELY_SCOPE`).

## Why

The client had grown to five features inside one package, with one
build_runner pass, one analyzer run and one 260-test suite that every change
paid for in full, and with nothing but discipline keeping `journal` from
importing `session`'s internals. Both costs grow with the app, not with the
change. Packages make the boundary a compile error and let every gate scale
with what changed.

We chose Tide's three tiers over VGV's four layers (data, repository,
business logic, presentation as separate packages) because VGV cuts by layer
and Tide cuts by feature: a feature package owns its bloc, its screens and its
tests, which is the unit an agent touches and a reviewer reads. Repositories
and analytics builders are utilities in this model; the vocabulary is
*Repository* for Supabase-backed data access, as both references use it.

We chose a pub workspace plus melos over path dependencies alone because a
workspace resolves once (one lock file, one package config, no drift between
packages) and melos gives per-package, change-scoped scripts without a
second build system. Tide manages ~300 packages with melos; we have a
handful, and the same tooling holds.

## Consequences

- Adding a package is a checklist, not a design decision: pubspec with
  `resolution: workspace`, tests, and the gates run without further
  wiring; no `analysis_options.yaml`, since ADR 0020 the workspace root's
  covers every package. The root `workspace:` list is globs over the two
  tiers, so a new directory is a member on the next `pub get`.
- A change to the shared rule set, the workspace pubspec or lock, or the
  contract schema runs every package's gates, because it affects every
  package.
- `flutter_launcher_icons` left the dependency graph: its newest release pins
  a `cli_util` that cannot resolve next to melos, and it is only ever run by
  hand (`dart pub global run flutter_launcher_icons` from `app`).
- Reaching another feature needs a seam, since features cannot import each
  other: one abstract navigator per feature, implemented by the app and
  registered as a singleton. `AccountNavigator` asks to be signed out;
  `JournalNavigator` asks for the session, the consent screen, the account
  screen and sign-out, and the app's implementation is where the consent
  bloc is created for the gate and where the user is told why no session
  started. It is the one sanctioned interface with a single production
  implementation, because it genuinely has two — the app's and the test
  fake — and everything else stays concrete. The journal no longer shares
  a consent bloc with the screens it opens: it asks the consent repository
  before every session, which is what it always had to do anyway.
- *2026-09-26:* the same holds for data. The session needs to tell the
  agent who the user is (#204), and the name belongs to the profile, not
  to the session; so `feature_session` declares `UserContextSource`, the
  app implements and registers it beside the navigators, and a test fakes
  it. Same shape, same reason — two implementations, the app's and the
  fake — so it is the navigator's exception applied to data, not a new
  one.

Decided on #39 (design comment of 2026-09-17), implemented as a stack of
pull requests starting with the move to `apps/mobile`.

## Dependency injection

A package can only register itself into a container that is not the widget
tree, so the container is get_it (9.2.1): bare, no injectable codegen, no
wrapper package. That is a deliberate departure from Tide, which generates
its registrations with injectable and hides get_it behind a `tide_di`
package; at a dozen packages both are ceremony. `RepositoryProvider` and
`context.read` for services are gone — they were service location scoped to
the tree, which was never the defect, but a feature package cannot reach a
tree the app builds.

The rules, in the app's `AGENTS.md` and enforced by review when decided;
the amendments below say which a lint enforces now (all but the factories,
the tests' composition and `main`'s async initialization):

- **One composition root.** `registerApp` in the app calls one plain
  `registerX(GetIt, {...})` function per utility and per feature, in
  dependency order. No package registers anything on its own.
- **Blocs are factories; everything else is an eager, user-agnostic
  singleton.** Sign-out drops all state because no per-user object outlives
  a screen. Should one ever need to, it goes into a get_it scope pushed on
  sign-in and popped on sign-out, never into a singleton.
- **Widgets touch the container in exactly two places:** creating their
  bloc, and resolving their feature's navigator. A widget-side effect that
  needs a dependency (an analytics call, a store launch) becomes an event
  the bloc handles — two such reads moved into blocs when this landed.
- **The app owns configuration.** Build-time values are read and validated
  in the app (`urlFrom` fails the launch on a malformed define, naming it)
  and passed into registration functions; no package reads the environment.
  Tide reads defines inside a utility's DI module; we chose the app so there
  is one inventory of defines and one fail-fast point.
- **Tests compose with the production `registerApp`** and replace only the
  leaves — the http clients, the Supabase client, the PostHog instance —
  so a test exercises the production graph with fake edges. This is
  stricter than Tide, whose tests register a separate test container
  wholesale. The container is reset in teardown and `allowReassignment`
  stays off, so a double registration is a loud failure.
- **Async initialization stays in `main`,** awaited behind the native launch
  screen; no async registrations, no Flutter splash. The known cost — the
  Supabase SDK awaits a network token refresh with backoff for up to ten
  seconds when the persisted token is expired and the device is offline —
  is a follow-up about starting on the persisted session, not a DI concern.

## Amendment 2026-09-26: configuration is enforced, not reviewed

"The app owns configuration" is no longer review-only (#165). The ast-grep
rule `no-from-environment` (ADR 0018) fails any `String`, `bool` or
`int.fromEnvironment`, or `bool.hasEnvironment`, outside
`app/lib/app/environment.dart`. The one other file allowed to read a define
is `app/integration_test/environment.dart`, for the smoke account's password,
which the live integration test needs and no build of the app may carry.
The other rules above stay review-only until #170.

## Amendment 2026-10-03: the layering is enforced, not reviewed

Since #170, ast-grep rules in `ast-grep/rules/architecture` (ADR 0018)
fail what review used to catch:

- **Features never depend on features:** `no-feature-dependency` fails a
  `feature_*` key under `dependencies`, `dev_dependencies` or
  `dependency_overrides` in any pubspec under `apps/mobile/packages`, a
  utility's included, since a utility may not depend on a feature either.
  A workspace member is listed by name alone, so `feature-package-name`
  keeps every package under `packages/feature` named `feature_<name>`.
- **One composition root:** `no-registration-outside-root` fails a call of
  any of get_it's `register…` methods in a package's `lib/` outside a
  top-level function named `register…` (or `_register…`). That the app
  calls them in dependency order stays a review matter.
- **Widgets touch the container in exactly two places:**
  `no-container-lookup` fails `GetIt.I` or `GetIt.instance` anywhere in a
  package's `lib/` but `BlocProvider(create: (_) => GetIt.I<SomeBloc>())`
  and `GetIt.I<SomeNavigator>()`, with `main` exempt. It holds all of
  `lib/`, not widgets alone: no other code reads the container either, and
  "inside a widget" is not a syntactic fact.

Still review-only: blocs as factories and everything else as user-agnostic
singletons, tests composing with the production `registerApp`, and async
initialization in `main`. Test code is outside the two get_it rules: it
registers its fake navigators and reads the container.
