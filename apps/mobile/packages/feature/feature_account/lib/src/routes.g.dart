// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$moreRoute, $consentRoute];

RouteBase get $moreRoute => GoRouteData.$route(
  path: '/more',
  name: 'more',
  hasOverriddenOnExit: false,
  factory: $MoreRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'profile',
      name: 'profile',
      hasOverriddenOnExit: false,
      factory: $ProfileRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'account',
      name: 'account',
      hasOverriddenOnExit: false,
      factory: $AccountRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'privacy',
      name: 'privacy_settings',
      hasOverriddenOnExit: false,
      factory: $PrivacySettingsRoute._fromState,
    ),
  ],
);

mixin $MoreRoute on GoRouteData {
  static MoreRoute _fromState(GoRouterState state) => const MoreRoute();

  @override
  String get location => GoRouteData.$location('/more');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileRoute on GoRouteData {
  static ProfileRoute _fromState(GoRouterState state) => const ProfileRoute();

  @override
  String get location => GoRouteData.$location('/more/profile');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AccountRoute on GoRouteData {
  static AccountRoute _fromState(GoRouterState state) => const AccountRoute();

  @override
  String get location => GoRouteData.$location('/more/account');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PrivacySettingsRoute on GoRouteData {
  static PrivacySettingsRoute _fromState(GoRouterState state) =>
      const PrivacySettingsRoute();

  @override
  String get location => GoRouteData.$location('/more/privacy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $consentRoute => GoRouteData.$route(
  path: '/consent',
  name: 'consent',
  hasOverriddenOnExit: false,
  factory: $ConsentRoute._fromState,
);

mixin $ConsentRoute on GoRouteData {
  static ConsentRoute _fromState(GoRouterState state) => const ConsentRoute();

  @override
  String get location => GoRouteData.$location('/consent');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
