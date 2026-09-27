import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:testing/testing.dart';

/// One captured PostHog event as `{'event': name, 'properties': {...}}` —
/// a map, so `expect` compares it deeply (records would compare maps by
/// identity).
typedef CapturedEvent = Map<String, Object>;

/// One `identify` call as `{'userId': id, 'properties': {...}}` — a map for
/// the same reason [CapturedEvent] is one.
typedef CapturedIdentity = Map<String, Object>;

/// One exception the app would send to PostHog error tracking.
class const CapturedException({
  required final Object error,
  required final StackTrace? stackTrace,
  required final Map<String, Object> properties,
});

/// Records everything the app would send to PostHog.
///
/// `stored` is the usage-analytics choice this device already holds when
/// the test begins (#204). Allowed by default, so a test about sessions or
/// sign-in sees its events; a test about the choice itself says what is
/// stored, `null` for a fresh install. The spy keeps it in the in-memory
/// preferences store it installs as the platform's.
class AnalyticsSpy({AnalyticsChoice? stored = AnalyticsChoice.allowed}) {
  this {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          if (stored != null) AnalyticsChoiceStore.key: stored.name,
        });
    when(posthog.setup(any)).thenAnswer((_) => _lifecycle('setup'));
    when(posthog.enable()).thenAnswer((_) {
      optedOut = false;
      return _lifecycle('enable');
    });
    when(posthog.disable()).thenAnswer((_) {
      optedOut = true;
      return _lifecycle('disable');
    });
    when(posthog.close()).thenAnswer((_) => _lifecycle('close'));
    when(posthog.flush()).thenAnswer((_) => _lifecycle('flush'));
    when(posthog.isOptOut()).thenAnswer((_) async => optedOut);
    when(
      posthog.capture(
        eventName: anyNamed('eventName'),
        properties: anyNamed('properties'),
      ),
    ).thenAnswer((invocation) {
      events.add({
        'event': invocation.namedArguments[#eventName] as String,
        'properties':
            invocation.namedArguments[#properties] as Map<String, Object>? ??
            const <String, Object>{},
      });
      return Future<void>.value();
    });
    when(
      posthog.captureException(
        error: anyNamed('error'),
        stackTrace: anyNamed('stackTrace'),
        properties: anyNamed('properties'),
      ),
    ).thenAnswer((invocation) {
      exceptions.add(
        CapturedException(
          error: invocation.namedArguments[#error] as Object,
          stackTrace: invocation.namedArguments[#stackTrace] as StackTrace?,
          properties:
              invocation.namedArguments[#properties] as Map<String, Object>? ??
              const <String, Object>{},
        ),
      );
      return Future<void>.value();
    });
    when(
      posthog.identify(
        userId: anyNamed('userId'),
        userProperties: anyNamed('userProperties'),
        userPropertiesSetOnce: anyNamed('userPropertiesSetOnce'),
      ),
    ).thenAnswer((invocation) {
      identities.add({
        'userId': invocation.namedArguments[#userId] as String,
        'properties':
            invocation.namedArguments[#userProperties]
                as Map<String, Object>? ??
            const <String, Object>{},
      });
      return Future<void>.value();
    });
    when(posthog.reset()).thenAnswer((_) {
      resets++;
      return _lifecycle('reset');
    });
  }

  Future<void> _lifecycle(String call) {
    lifecycle.add(call);
    return Future<void>.value();
  }

  final posthog = MockPosthog();

  /// The device's preferences, holding the choice the spy was made with.
  late final preferences = SharedPreferencesAsync();

  /// The SDK's lifecycle as the app drove it, in order: `setup`, `enable`,
  /// `disable`, `close`, `flush` and `reset`.
  final lifecycle = <String>[];

  /// Whether the SDK is opted out, as the native side would persist it:
  /// `disable` sets it, `enable` clears it.
  var optedOut = false;

  /// The gate the builders below go through, over this spy's PostHog and
  /// the choice it was made with, restored the way `main` restores it.
  late final PostHogGate gate = _restored(
    PostHogGate(
      posthog: posthog,
      config: PostHogConfig('phc_test'),
      store: AnalyticsChoiceStore(preferences: preferences),
    ),
  );

  static PostHogGate _restored(PostHogGate gate) {
    unawaited(gate.restore());
    return gate;
  }

  final events = <CapturedEvent>[];

  /// The exceptions the app reported, in order.
  final exceptions = <CapturedException>[];

  /// Every `identify` the app made, in order, as
  /// `{'userId': id, 'properties': {...}}` — a map so `expect` compares it
  /// deeply, like [CapturedEvent].
  final identities = <CapturedIdentity>[];

  /// The user ids the app identified PostHog with, in order.
  Iterable<String> get identified =>
      identities.map((identity) => identity['userId']! as String);

  /// How often the app told PostHog to forget the user.
  var resets = 0;

  /// The [SessionAnalytics] the app is given.
  SessionAnalytics get analytics => SessionAnalytics(gate: gate);

  /// The [AuthAnalytics] the app is given.
  AuthAnalytics get authAnalytics => AuthAnalytics(gate: gate);

  /// The [JournalAnalytics] the app is given.
  JournalAnalytics get journalAnalytics => JournalAnalytics(gate: gate);

  /// The [ErrorReporter] the app is given.
  ErrorReporter get errorReporter => ErrorReporter(gate: gate);

  /// Every string that would leave the device: event names, properties,
  /// identities, and each reported exception's type, text, causes,
  /// properties and stack trace.
  Iterable<String> get outgoingStrings sync* {
    for (final identity in identities) {
      yield identity['userId']! as String;
      yield* _strings(identity['properties']! as Map<String, Object>);
    }
    for (final event in events) {
      yield event['event']! as String;
      yield* _strings(event['properties']! as Map<String, Object>);
    }
    for (final exception in exceptions) {
      yield* _errorStrings(exception.error, Set.identity());
      yield '${exception.stackTrace}';
      yield* _strings(exception.properties);
    }
  }

  static Iterable<String> _strings(Map<String, Object> properties) sync* {
    for (final MapEntry(:key, :value) in properties.entries) {
      yield key;
      yield '$value';
    }
  }

  /// The SDK appends an error's causes as further exception items: an
  /// [AsyncError]'s error, every failure of a [ParallelWaitError], and a
  /// duck-typed `cause` getter. Mirror that walk, cycle-guarded.
  static Iterable<String> _errorStrings(Object error, Set<Object> seen) sync* {
    if (!seen.add(error)) {
      return;
    }
    yield '${error.runtimeType}';
    yield '$error';
    for (final cause in _causes(error)) {
      yield* _errorStrings(cause, seen);
    }
  }

  static Iterable<Object> _causes(Object error) sync* {
    switch (error) {
      case AsyncError(:final error):
        yield error;
      case ParallelWaitError<Object?, Object?>(:final errors):
        if (errors case final Iterable<Object?> errors) {
          yield* errors.nonNulls;
        }
      default:
        final Object? cause;
        try {
          cause = (error as dynamic).cause as Object?;
          // The SDK probes the getter exactly like this; an error without
          // one is the normal case, not a bug to surface.
          // ignore: avoid_catching_errors
        } on NoSuchMethodError {
          return;
        }
        if (cause != null) {
          yield cause;
        }
    }
  }
}

/// A captured event literal, for readable expectations.
CapturedEvent event(String name, [Map<String, Object> properties = const {}]) =>
    {'event': name, 'properties': properties};

/// A captured `identify` literal, for readable expectations.
CapturedIdentity identity(
  String userId, [
  Map<String, Object> properties = const {},
]) => {'userId': userId, 'properties': properties};

/// Matches a reported exception: [error] itself (or its content-free
/// stand-in), with exactly [properties] and a stack trace attached.
Matcher captured(Object error, Map<String, Object> properties) =>
    isA<CapturedException>()
        .having((captured) => captured.error, 'error', error)
        .having((captured) => captured.properties, 'properties', properties)
        .having((captured) => captured.stackTrace, 'stackTrace', isNotNull);

/// What a [type] of exception looks like once its message is withheld.
WithheldException withheld(Type type, {String? code, int? statusCode}) =>
    WithheldException(type, code: code, statusCode: statusCode);
