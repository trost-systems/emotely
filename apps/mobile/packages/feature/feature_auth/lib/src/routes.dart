import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

/// The auth feature's own screens as routes (ADR 0016): the feature says
/// where its screens live, the app mounts them and decides who may be
/// there.

/// Where a signed-out user gets an account or signs into one, as [mode]
/// says: the last step of onboarding, or "I have an account" (#204).
/// [from] is the location they were going to — a deep link, or the screen
/// they were on when the session ended under them — which the app's
/// redirect sends them to once they sign in.
@TypedGoRoute<SignInRoute>(path: '/sign-in', name: 'signIn')
@immutable
class const SignInRoute({
  final SignInMode mode = SignInMode.signIn,
  final String? from,
}) extends GoRouteData with $SignInRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SignInPage(mode: mode);
}
