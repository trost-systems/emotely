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
  /// The choice and whose it is, as the store keeps it.
  StoredChoice? _stored;

  /// Who is signed in, as last told ([restore], [signedInAs]): the account
  /// an answer given now belongs to.
  String? _account;

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
  AnalyticsChoice? get choice => _stored?.choice;

  /// The choice as it stands if it is [account]'s, else `null`: one made
  /// before sign-up that no account has adopted yet is nobody's, and one
  /// made by someone else is never theirs. What the consent record may say
  /// about [account] (ADR 0014).
  AnalyticsChoice? choiceOf(String account) => switch (_stored) {
    (:final choice, account: final owner?) when owner == account => choice,
    _ => null,
  };

  /// Every change of [choice] from here on.
  Stream<AnalyticsChoice?> get changes => _changes.stream;

  /// Completes once every transition asked for so far has been applied, so
  /// [choice] can be read as the answer rather than a guess.
  Future<void> get settled => _settled;

  /// Reads the stored choice and, if it allows and it is [account]'s — the
  /// account whose session the app starts with, `null` for none — sets
  /// PostHog up as the same anonymous person as last launch. `main` awaits
  /// this before the first frame, so the first `identify` already finds the
  /// gate open.
  ///
  /// A session can end while the app is closed (an expiry, a revoked
  /// refresh token, an account deleted elsewhere), and nothing on the
  /// device sees it go (#216). So whose the choice is is checked here,
  /// before PostHog is set up and before anything queued behind this can
  /// go out: a choice that belongs to an account other than [account],
  /// or to any account when nobody is signed in, is forgotten and asked
  /// again. A choice made before sign-up is adopted by [account], if there
  /// is one. A stored value this build cannot read — including one from a
  /// build that did not keep whose it was — is removed.
  Future<void> restore({required String? account}) => _transition(() async {
    _account = account;
    _stored = await _store.read();
    switch (_claimBy(account)) {
      case _Claim.forget:
        _stored = null;
      case _Claim.adopt:
        await _adopt(account);
      case _Claim.keep:
        break;
    }
    if (_stored == null) {
      await _store.clear();
    }
    if (choice == AnalyticsChoice.allowed) {
      await _start(fresh: false);
      _open = true;
    }
  });

  /// Who is signed in now: [account], or nobody for `null`. The session
  /// changed while the app was running — a sign-in, a sign-out however it
  /// came about, another account taking the session's place.
  ///
  /// A choice that belongs to anyone other than [account] is forgotten as
  /// [forget] forgets it: PostHog resets while its owner's consent still
  /// covers that, switches off, and the question is asked again. A choice
  /// made before sign-up is adopted by the account that signs in. Queued
  /// like every transition, so nothing asked for after the session changed
  /// goes out under a choice that is not the new account's.
  Future<void> signedInAs(String? account) => _transition(() async {
    _account = account;
    if (_identity?.userId != account) {
      _identity = null;
    }
    switch (_claimBy(account)) {
      case _Claim.forget:
        await _forget();
      case _Claim.adopt:
        await _adopt(account);
      case _Claim.keep:
        break;
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
    await _store.write(AnalyticsChoice.allowed, account: _account);
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
    await _store.write(AnalyticsChoice.denied, account: _account);
  });

  /// Sign-out and account deletion: the choice belongs to a person, not the
  /// phone, so PostHog forgets who this was (`reset`, while that person's
  /// consent still covers it), switches off, and the question is asked
  /// again of whoever comes next.
  ///
  /// What that person already said (`signed_out`, `account_deleted`) must
  /// still arrive, so the queue is flushed and the SDK is opted out, not
  /// closed. The SDK keeps its queue on disk and `close` stops it before a
  /// send completes: the event would go out only at the next [allow] on
  /// this device, under whoever gave it, and twice if the flush had got it
  /// out already. Opted out, the SDK takes nothing new and only delivers
  /// its queue. A later [deny] closes it, an [allow] reopens it without a
  /// second `setup`, and the next launch does not set it up at all.
  Future<void> forget() => _transition(_forget);

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

  /// Records [choice] as the answer of whoever is signed in now, or of
  /// nobody yet.
  void _update(AnalyticsChoice? choice) {
    _stored = choice == null ? null : (choice: choice, account: _account);
    _changes.add(choice);
  }

  /// What [account] coming or going means for the stored choice.
  _Claim _claimBy(String? account) => switch (_stored) {
    null => _Claim.keep,
    (choice: _, account: null) => account == null ? _Claim.keep : _Claim.adopt,
    (choice: _, account: final owner?) =>
      owner == account ? _Claim.keep : _Claim.forget,
  };

  /// Makes the choice made before sign-up [account]'s, on the device too,
  /// so the next launch knows whose it is.
  Future<void> _adopt(String? account) async {
    if (_stored case (:final choice, account: _)) {
      _stored = (choice: choice, account: account);
      await _store.write(choice, account: account);
    }
  }

  Future<void> _forget() async {
    _update(null);
    _identity = null;
    if (_open) {
      _open = false;
      await _guarded(_posthog.flush);
      await _guarded(_posthog.reset);
      // Opted out, not closed: see [forget].
      await _guarded(_posthog.disable);
    }
    await _store.clear();
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

/// What a change of who is signed in means for the stored choice.
enum _Claim() {
  /// It is the account's, or nobody's while nobody is signed in.
  keep,

  /// It was made before sign-up, and the account signing in takes it.
  adopt,

  /// It is someone else's: forgotten, and asked again.
  forget,
}
