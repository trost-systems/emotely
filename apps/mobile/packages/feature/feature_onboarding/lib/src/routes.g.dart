// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$onboardingRoute];

RouteBase get $onboardingRoute => GoRouteData.$route(
  path: '/welcome',
  name: 'onboarding',
  hasOverriddenOnExit: false,
  factory: $OnboardingRoute._fromState,
);

mixin $OnboardingRoute on GoRouteData {
  static OnboardingRoute _fromState(GoRouterState state) => OnboardingRoute(
    phase:
        _$convertMapValue(
          'phase',
          state.uri.queryParameters,
          _$OnboardingPhaseEnumMap._$fromName,
        ) ??
        OnboardingPhase.beforeSignUp,
    from: state.uri.queryParameters['from'],
  );

  OnboardingRoute get _self => this as OnboardingRoute;

  @override
  String get location => GoRouteData.$location(
    '/welcome',
    queryParams: {
      if (_self.phase != OnboardingPhase.beforeSignUp)
        'phase': _$OnboardingPhaseEnumMap[_self.phase],
      if (_self.from != null) 'from': _self.from,
    },
  );

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

const _$OnboardingPhaseEnumMap = {
  OnboardingPhase.beforeSignUp: 'before-sign-up',
  OnboardingPhase.afterSignIn: 'after-sign-in',
};

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

extension<T extends Enum> on Map<T, String> {
  T? _$fromName(String? value) =>
      entries.where((element) => element.value == value).firstOrNull?.key;
}
