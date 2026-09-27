import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/src/view/onboarding_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

/// Onboarding's one screen as a route (ADR 0016): its steps are bloc state,
/// not a page stack, so one location holds them all and the step reached
/// is read from the device, never from the location.
///
/// [phase] is when it runs: before sign-up, where the app's redirect sends
/// a signed-out user until every step is done; or once after a sign-in,
/// where it saves the name to the account, or asks an account without one.
/// [from] is where the user was going when onboarding came in between — a
/// deep link, or the screen they were on when signed out — carried through
/// to sign-in and past it.
@TypedGoRoute<OnboardingRoute>(path: '/welcome', name: 'onboarding')
@immutable
class const OnboardingRoute({
  final OnboardingPhase phase = OnboardingPhase.beforeSignUp,
  final String? from,
}) extends GoRouteData with $OnboardingRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      OnboardingPage(phase: phase, from: from);
}
