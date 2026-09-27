// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$signInRoute];

RouteBase get $signInRoute => GoRouteData.$route(
  path: '/sign-in',
  name: 'signIn',
  hasOverriddenOnExit: false,
  factory: $SignInRoute._fromState,
);

mixin $SignInRoute on GoRouteData {
  static SignInRoute _fromState(GoRouterState state) => SignInRoute(
    mode:
        _$convertMapValue(
          'mode',
          state.uri.queryParameters,
          _$SignInModeEnumMap._$fromName,
        ) ??
        SignInMode.signIn,
    from: state.uri.queryParameters['from'],
  );

  SignInRoute get _self => this as SignInRoute;

  @override
  String get location => GoRouteData.$location(
    '/sign-in',
    queryParams: {
      if (_self.mode != SignInMode.signIn)
        'mode': _$SignInModeEnumMap[_self.mode],
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

const _$SignInModeEnumMap = {
  SignInMode.signUp: 'sign-up',
  SignInMode.signIn: 'sign-in',
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
