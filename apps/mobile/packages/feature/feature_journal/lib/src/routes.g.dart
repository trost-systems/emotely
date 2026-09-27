// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$journalRoute];

RouteBase get $journalRoute => GoRouteData.$route(
  path: '/',
  name: 'journal',
  hasOverriddenOnExit: false,
  factory: $JournalRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'entries/:id',
      name: 'entry',
      hasOverriddenOnExit: false,
      factory: $EntryRoute._fromState,
    ),
  ],
);

mixin $JournalRoute on GoRouteData {
  static JournalRoute _fromState(GoRouterState state) => JournalRoute(
    startSession:
        _$convertMapValue(
          'start-session',
          state.uri.queryParameters,
          _$boolConverter,
        ) ??
        false,
  );

  JournalRoute get _self => this as JournalRoute;

  @override
  String get location => GoRouteData.$location(
    '/',
    queryParams: {
      if (_self.startSession != false)
        'start-session': _self.startSession.toString(),
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

mixin $EntryRoute on GoRouteData {
  static EntryRoute _fromState(GoRouterState state) =>
      EntryRoute(id: state.pathParameters['id']!);

  EntryRoute get _self => this as EntryRoute;

  @override
  String get location =>
      GoRouteData.$location('/entries/${Uri.encodeComponent(_self.id)}');

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

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}
