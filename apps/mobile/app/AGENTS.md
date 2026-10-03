# apps/mobile/app — Flutter client

State management: bloc. Widgets: the standalone `material_ui`/`cupertino_ui`
packages. Custom look lives in `ThemeData` (Baskervville serif,
emotely-orange seed), not in hand-rolled widgets.

## Routing (ADR 0016)

- Every feature declares the routes of its own screens in its
  `lib/src/routes.dart`: a `GoRouteData` class per screen with a
  `@TypedGoRoute` annotation, generated into `routes.g.dart` there (`dart
  run build_runner build` in the feature; `melos run codegen:check` is the
  tripwire), exported through the barrel with `hide $appRoutes`. The app's
  `lib/app/routes.dart` is a plain list that mounts them — onboarding,
  sign-in, the shell with its two branches, the session and the consent
  screen at the root — and generates nothing.
- A feature moves between its own screens itself
  (`EntryRoute(id:).go(context)`). It reaches another feature's screen
  only through its navigator, and the app's implementation in
  `lib/app/navigators.dart` answers with that feature's route: `.push<T>`
  when the caller awaits an answer (the session's end, the consent
  outcome). The seams take the `BuildContext` of the tap; a caller that
  awaits the server before asking checks `context.mounted` first, and so
  does an implementation that uses the context after its own await.
- A screen that needs an object gets a bloc that loads it by the id in its
  location (`EntryRoute(id:)`, `SessionRoute(resume:)`), not a constructor
  argument from the caller.
- Screens are routes; steps are bloc state. Sign-in's email-then-code, the
  session's questions, the onboarding steps and the consent screen's
  states are one page whose bloc picks the widget, not a page stack.
- The guard is `authRedirect` in `lib/app/router.dart`, pure over "signed
  in?", "is onboarding ready for the account?" (the `OnboardingStore`,
  restored in `main` before the first frame) and the matched location;
  its table is `test/app/router_test.dart`. `RouteRefresh` re-runs it only
  when one of those booleans flips, and forgets the device's onboarding
  progress on sign-out. Never gate a screen on auth or onboarding state
  inside a widget — add to the redirect.
- The router is built once, in `_RouterState`, over the auth bloc above
  it. `ConfigGate`, the usage-analytics sheet (`UsageAnalyticsPrompt`,
  under the gate) and `PostHogWidget` live in `MaterialApp.router`'s
  `builder`, over the navigator.
- Signed in, the user lives in two tabs (a `StatefulShellRoute` in
  `routes.dart`, rendered by `lib/app/shell.dart`): the journal with its
  entries, and More (`feature_account`'s `MorePage`) with the Profile
  and account screens under it. A screen that must cover the tab bar —
  the session, the consent screen — is declared by its feature with a
  root path (`/session`, `/consent`), mounted outside the shell, and
  pushed.

## Dependencies (ADR 0015)

- `lib/app/dependencies.dart` is the one composition root: `registerApp`
  calls every utility's and every feature's one plain
  `registerX(GetIt getIt, {...})` function, in dependency order.
- Blocs are factories, created by the screen that owns them. Everything
  else is an eager singleton and user-agnostic: nothing per-user outlives a
  screen, so sign-out already drops all state. The day a per-user object
  must outlive a screen, it goes into a get_it scope pushed on sign-in and
  popped on sign-out — not into a singleton.
- Every feature's navigator is implemented in `lib/app/navigators.dart` and
  registered next to the feature in `registerApp`. The app is the only
  place that knows two features' pages and blocs together, so cross-feature
  routes, and what the user is told about their outcome, live there.
- A feature that needs *data* another feature owns declares the same kind
  of seam: an abstract source the app implements and registers next to
  the navigators. The session's `UserContextSource` (who the user is, for
  the agent) is implemented in `lib/app/user_context.dart`, over
  the profile repository. It is the one seam registered as a factory: it
  remembers the profile for one session (#264), so each session bloc gets
  its own and closes it, which keeps the user's data no longer than the
  screen. The account's `AccountDeviceData` (what a
  deleted account leaves on the device, today sign-in's "Last used"
  method) in `lib/app/account_device_data.dart`.
- Build-time values (`--dart-define`s) are read and validated in the app
  only (`lib/app/environment.dart`, `urlFrom`) and passed into registration
  functions. No package calls `String.fromEnvironment`; CI's `ast-grep`
  job fails any read outside that file, apart from the smoke password in
  `integration_test/environment.dart`, which must never reach `lib/`.
- Tests compose with the same `registerApp` and replace only the leaves:
  the two http clients, the Supabase client, the PostHog instance and the
  preferences store (`test/helpers/app_harness.dart`). `getIt.reset()`
  runs in teardown; `allowReassignment` stays off so a double registration
  fails loudly.
- PostHog is reached only through `PostHogGate` (the `analytics` utility):
  every event builder and the error reporter take the gate, never
  `Posthog`, and `main` hands the instance and its config to `registerApp`
  and nothing else. The gate calls `setup` only once the user allowed
  usage analytics (#204, § 25 TDDDG), so nothing else calls `setup`.
