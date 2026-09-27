import 'package:design_system/design_system.dart';
import 'package:emotely/app/router.dart';
import 'package:emotely/config/bloc/config_bloc.dart';
import 'package:emotely/config/view/config_gate.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Root of the emotely client: the two blocs that sit above every screen,
/// and the router that decides which screen that is (ADR 0016).
///
/// The blocs come out of the container `registerApp` filled (ADR 0015);
/// the widget itself is handed the two things the router needs that are
/// not blocs, by whoever mounts it:
///
/// - [screenViews], the route observer PostHog counts screens and draws
///   surveys through, built by the PostHog gate so that it counts nothing
///   until the user allowed usage analytics (#204). It is built once per
///   mounted app: it registers itself with the widgets binding and tracks
///   this navigator's routes, so neither a fresh one each frame nor one
///   shared between apps would do.
/// - [onboarding], the device's onboarding progress the redirect asks
///   about, restored before it is handed in.
class const EmotelyApp({
  required final NavigatorObserver screenViews,
  required final OnboardingStore onboarding,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => GetIt.I<AuthBloc>()),
      // Not lazy: the gate must ask before the first frame the user could
      // act on, not when something happens to read it.
      BlocProvider(
        lazy: false,
        create: (_) => GetIt.I<ConfigBloc>()..add(const ConfigEvent.loaded()),
      ),
    ],
    child: _Router(screenViews: screenViews, onboarding: onboarding),
  );
}

/// Owns the router for as long as the app is mounted: built once over the
/// auth bloc above it, never per rebuild, or every rebuild would start the
/// navigation over.
class const _Router({
  required final NavigatorObserver screenViews,
  required final OnboardingStore onboarding,
}) extends StatefulWidget {
  @override
  State<_Router> createState() => _RouterState();
}

class _RouterState() extends State<_Router> {
  late final AuthBloc _auth = context.read<AuthBloc>();
  late final _refresh = RouteRefresh(_auth, widget.onboarding);
  late final GoRouter _router = createRouter(
    auth: _auth,
    onboarding: widget.onboarding,
    refresh: _refresh,
    observers: [widget.screenViews],
  );

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'emotely',
    theme: lightTheme,
    darkTheme: darkTheme,
    routerConfig: _router,
    // PostHog draws a popover survey into the navigator's own context, which
    // it reaches through `PosthogObserver`; without the observer it finds no
    // context and logs that it cannot show the survey, and without the
    // wrapper it has nothing to draw into (ADR 0004). Surveys carry only
    // what the user types into them — no journal text passes through here,
    // and session replay stays off (ADR 0005).
    //
    // The wrapper goes in `builder`, under the router rather than over it:
    // above `MaterialApp` its own state would outlive a remount of the app
    // and keep the old route stack alive with it. The startup gate sits
    // inside it too, over the navigator: nothing below it is built until
    // the server has said this build may run (#49). Under the gate, the
    // usage-analytics question: once this build may run, it comes before
    // anything else the user sees, over whatever screen the router shows
    // (#204). The PostHog wrapper does nothing until the SDK is set up.
    builder: (context, child) => PostHogWidget(
      child: ConfigGate(
        child: UsageAnalyticsPrompt(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
}
