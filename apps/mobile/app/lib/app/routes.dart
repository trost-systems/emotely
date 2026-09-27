import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_session/feature_session.dart';
import 'package:go_router/go_router.dart';

/// The app's route table (ADR 0016): every feature declares the routes of
/// its own screens and moves between them itself; the app mounts those
/// trees and adds nothing of its own but the shell.
///
/// Onboarding and sign-in stand alone, and the redirect sends every
/// signed-out location to one of them (#204). Signed in, the user lives in
/// two tabs: the journal (with its entries) and More (with the account
/// under it). The session and the
/// consent screen sit at the root, outside the shell, so pushing them
/// covers the tab bar. Features reach each other's screens only through
/// their navigators (ADR 0015), which the app implements with these routes.
List<RouteBase> get appRoutes => [
  $onboardingRoute,
  $signInRoute,
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(routes: [$journalRoute]),
      StatefulShellBranch(routes: [$moreRoute]),
    ],
  ),
  $sessionRoute,
  $consentRoute,
];
