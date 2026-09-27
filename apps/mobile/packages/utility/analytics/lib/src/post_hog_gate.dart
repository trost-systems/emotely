import 'dart:async';

import 'package:analytics/src/analytics_choice_store.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// The one door to PostHog: nothing in the app reaches the SDK except
/// through this class, and it opens only once the user allowed usage
/// analytics (#204, § 25 TDDDG).
///
/// Before that, PostHog is **not set up at all** — not set up and opted
/// out, which would still create and send an anonymous id when the SDK
/// loads its remote config — so no id exists on the device and nothing
/// leaves it. Events, error tracking (captured and uncaught alike) and
/// surveys all sit behind this one switch, because they all ride on
/// `setup`.
///
/// The event builders and the error reporter take this gate, never a
/// [Posthog], so a call that skips the choice does not type-check; the
/// [Posthog] instance goes in here and nowhere else (`registerAnalytics`).
/// Every call is a no-op while the gate is shut and never throws: the SDK
/// is a platform channel, and analytics failing must not fail the app.
///
/// Calls made while a choice is being applied wait for it, so the order
/// the app says things in is the order PostHog hears them, and nothing
/// slips through half a transition.
class PostHogGate({
  required final Posthog _posthog,
  required final PostHogConfig _config,
  required final AnalyticsChoiceStore _store,
}) {
  AnalyticsChoice? _choice;

  /// Whether `setup` has run and not been undone by `close`.
  var _setUp = false;

  /// Whether the SDK is set up and collecting: the only state in which a
  /// call goes through.
  var _open = false;

  /// The transition in flight, or the last one; every call queues behind.
  var _settled = Future<void>.value();

  /// Who is signed in, as last told, so that allowing mid-session does not
  /// leave the events that follow anonymous. Kept in memory only, and told
  /// PostHog only once the gate is open.
  ({String userId, Map<String, Object>? properties})? _identity;

  final _changes = StreamController<AnalyticsChoice?>.broadcast();

  /// The choice as it stands: `null` until one is made, and again after
  /// [forget].
  AnalyticsChoice? get choice => _choice;

  /// Every change of [choice] from here on.
  Stream<AnalyticsChoice?> get changes => _changes.stream;

  /// Completes once every transition asked for so far has been applied, so
  /// [choice] can be read as the answer rather than a guess.
  Future<void> get settled => _settled;

  /// Reads the stored choice and, if it allows, sets PostHog up as the
  /// same anonymous person as last launch. `main` awaits this before the
  /// first frame, so the first `identify` already finds the gate open.
  Future<void> restore() => _transition(() async {
    _choice = await _store.read();
    if (_choice == AnalyticsChoice.allowed) {
      await _start(fresh: false);
      _open = true;
    }
  });

  /// The user allowed usage analytics: kept for the next launch, and
  /// PostHog set up afresh. The reset makes sure nothing links this consent
  /// to whoever used the SDK on this device before.
  ///
  /// The allow is then the first thing PostHog hears, as
  /// `usage_analytics_allowed`: the top of the onboarding funnel (#204). It
  /// is sent here, inside the transition, so that nothing queued behind the
  /// answer — the screens that came up under the question — goes out
  /// before it, and so that it is only ever sent by an allow. The gate
  /// opens only once it is sent: the screen observer reads the gate
  /// directly rather than queueing behind the transition, so a screen that
  /// comes up while the SDK is being set up is not counted ahead of it.
  Future<void> allow() => _transition(() async {
    _update(AnalyticsChoice.allowed);
    await _store.write(AnalyticsChoice.allowed);
    await _start(fresh: true);
    await _guarded(
      () => _posthog.capture(eventName: 'usage_analytics_allowed'),
    );
    _open = true;
  });

  /// The user said no, or withdrew: PostHog is switched off before the
  /// answer is written down, so a failed write never leaves it running.
  ///
  /// No `reset` on the way out: the SDK reloads its feature flags under the
  /// fresh id a reset mints, whether or not it is opted out, which would be
  /// sending something after a refusal. The id left behind is never sent;
  /// the next [allow] resets before anything goes out.
  Future<void> deny() => _transition(() async {
    _update(AnalyticsChoice.denied);
    await _stop();
    await _store.write(AnalyticsChoice.denied);
  });

  /// Sign-out and account deletion: the choice belongs to a person, not the
  /// phone, so PostHog forgets who this was (`reset`, while that person's
  /// consent still covers it), switches off, and the question is asked
  /// again of whoever comes next.
  Future<void> forget() => _transition(() async {
    _update(null);
    _identity = null;
    if (_open) {
      await _guarded(_posthog.reset);
    }
    await _stop();
    await _store.clear();
  });

  /// `capture`, if allowed.
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
  }) => _whenOpen(
    () => _posthog.capture(eventName: eventName, properties: properties),
  );

  /// `captureException`, if allowed. The `beforeSend` backstop in the
  /// config filters these on the wire like every other `$exception`.
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) => _whenOpen(
    () => _posthog.captureException(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    ),
  );

  /// `identify`, if allowed; remembered either way, so a later [allow]
  /// tells PostHog who is signed in without waiting for the next sign-in.
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
  }) async {
    // Remembered only once the transition in flight has landed, so a
    // restore that opens the gate does not tell PostHog twice.
    await _settled;
    _identity = (userId: userId, properties: userProperties);
    if (_open) {
      await _guarded(
        () => _posthog.identify(userId: userId, userProperties: userProperties),
      );
    }
  }

  /// The route observer the router is given: screen views (`$screen`) only
  /// while the gate is open, and the context PostHog draws surveys into.
  /// The observer calls the SDK itself rather than through this class, so
  /// the gate is its route filter.
  PosthogObserver screenObserver() => PosthogObserver(
    routeFilter: (route) => _open && defaultPostHogRouteFilter(route),
  );

  Future<void> _transition(Future<void> Function() body) =>
      _settled = _settled.then((_) => _guarded(body));

  void _update(AnalyticsChoice? choice) {
    _choice = choice;
    _changes.add(choice);
  }

  /// Sets the SDK up and tells it who is signed in, without opening the
  /// gate: the caller opens it once there is nothing left to say first.
  Future<void> _start({required bool fresh}) async {
    if (!_setUp) {
      await _posthog.setup(_config);
      _setUp = true;
    }
    // The native SDKs persist an opt-out across launches and let it
    // override the config at `setup`, so an earlier refusal is lifted here.
    if (await _posthog.isOptOut()) {
      await _posthog.enable();
    }
    if (fresh) {
      await _posthog.reset();
    }
    if (_identity case (:final userId, :final properties)) {
      await _guarded(
        () => _posthog.identify(userId: userId, userProperties: properties),
      );
    }
  }

  /// Opts out (persisted natively, so even a stray `setup` stays silent)
  /// and closes the SDK, which uninstalls error autocapture with it.
  Future<void> _stop() async {
    _open = false;
    if (_setUp) {
      _setUp = false;
      await _guarded(_posthog.disable);
      await _guarded(_posthog.close);
    }
  }

  Future<void> _whenOpen(Future<void> Function() call) async {
    await _settled;
    if (_open) {
      await _guarded(call);
    }
  }

  /// Analytics never fails the app: a platform refusal is swallowed here,
  /// and the gate stays in whatever state the choice asked for.
  static Future<void> _guarded(Future<void> Function() call) async {
    try {
      await call();
    } on Exception catch (error) {
      debugPrint('PostHog call failed: ${error.runtimeType}');
    }
  }
}
