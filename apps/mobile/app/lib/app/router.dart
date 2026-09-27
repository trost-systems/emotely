import 'dart:async';

import 'package:analytics/analytics.dart' show OnboardingPhase;
import 'package:emotely/app/routes.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The one decision above every screen — who may be where, before and
/// around the account — as a redirect (ADR 0016, ADR 0019).
///
/// Signed out, a user belongs in onboarding until every step before
/// sign-up is done on this device ([readyForAccount]), and on sign-up
/// after; "I have an account" (sign-in as a sign-in) is open either way.
/// Signed in, the moment of sign-in leads through onboarding's step after
/// sign-in, which saves the name the device holds or asks an account
/// without one; so does a signed-in device still holding a name for the
/// account (the app closed between the two). Everything else stands.
///
/// Where the user was going — a deep link, or the screen they were on when
/// the session ended under them — travels along as `from` and is where
/// they land once in. Only a location of this app's is honoured: anything
/// that does not start with `/`, or that would lead back to sign-in or
/// onboarding, is dropped.
///
/// Pure, so it can be read and tested on its own: [signedIn] is the auth
/// bloc's answer at the moment the router asks, [readyForAccount] the
/// onboarding store's, and [uri] the location being entered, query and
/// all.
String? authRedirect({
  required bool signedIn,
  required bool readyForAccount,
  required Uri uri,
}) => signedIn
    ? _whenSignedIn(uri, readyForAccount: readyForAccount)
    : _whenSignedOut(uri, readyForAccount: readyForAccount);

String? _whenSignedOut(Uri uri, {required bool readyForAccount}) {
  final from = _from(uri);
  final signUp = SignInRoute(mode: SignInMode.signUp, from: from).location;
  final onboarding = OnboardingRoute(from: from).location;
  if (uri.path == _signIn) {
    // "I have an account" is open whatever onboarding says; sign-up only
    // once onboarding has asked everything before it.
    return !_has(uri, _signUpMode) || readyForAccount ? null : onboarding;
  }
  if (readyForAccount) {
    return signUp;
  }
  final inOnboarding = uri.path == _welcome && !_has(uri, _afterSignIn);
  return inOnboarding ? null : onboarding;
}

String? _whenSignedIn(Uri uri, {required bool readyForAccount}) {
  final atWelcome = uri.path == _welcome;
  if (atWelcome && _has(uri, _afterSignIn)) {
    return null;
  }
  if (uri.path == _signIn || readyForAccount) {
    return OnboardingRoute(
      phase: OnboardingPhase.afterSignIn,
      from: _from(uri),
    ).location;
  }
  if (atWelcome) {
    return _from(uri) ?? const JournalRoute().location;
  }
  return null;
}

final _signIn = const SignInRoute().location;
final _welcome = const OnboardingRoute().location;
final _journal = const JournalRoute().location;

/// The query that makes sign-in a sign-up, and onboarding its step after
/// sign-in, as the routes themselves spell them.
final _signUpMode = Uri.parse(
  const SignInRoute(mode: SignInMode.signUp).location,
).queryParameters;
final _afterSignIn = Uri.parse(
  const OnboardingRoute(phase: OnboardingPhase.afterSignIn).location,
).queryParameters;

bool _has(Uri uri, Map<String, String> query) => query.entries.every(
  (entry) => uri.queryParameters[entry.key] == entry.value,
);

/// Where the user was going: what sign-in and onboarding carry along, or
/// the location itself anywhere else — nothing for the journal, which is
/// where everyone lands anyway.
String? _from(Uri uri) {
  if (uri.path == _signIn || uri.path == _welcome) {
    return _local(uri.queryParameters['from']);
  }
  return uri.path == _journal ? null : _local(uri.toString());
}

String? _local(String? from) =>
    from != null &&
        from.startsWith('/') &&
        !from.startsWith(_signIn) &&
        !from.startsWith(_welcome)
    ? from
    : null;

/// Tells the router to ask [authRedirect] again whenever one of its inputs
/// changes — whether someone is signed in, and whether onboarding is ready
/// for the account — and only then. The auth bloc moves through several
/// states while a code is typed, and the onboarding store on every
/// keystroke of the name; none of those changes where the user may be.
///
/// A sign-out also forgets this device's onboarding progress before the
/// router asks, so whoever comes next starts at Welcome (#204): it is
/// here because this is where the sign-out is first seen, whatever caused
/// it — the Profile screen, an expired token, an account deleted.
///
/// The owner disposes it; the router does not own its listenable.
class RouteRefresh(final AuthBloc _auth, final OnboardingStore _onboarding)
    extends ChangeNotifier {
  this {
    _signedIn = _auth.state is AuthSignedIn;
    _ready = _onboarding.readyForAccount;
    _changes = [
      _auth.stream.listen((state) {
        final signedIn = state is AuthSignedIn;
        if (signedIn != _signedIn) {
          _signedIn = signedIn;
          if (!signedIn) {
            unawaited(_onboarding.clear());
          }
          notifyListeners();
        }
      }),
      _onboarding.changes.listen((_) {
        final ready = _onboarding.readyForAccount;
        if (ready != _ready) {
          _ready = ready;
          notifyListeners();
        }
      }),
    ];
  }

  late bool _signedIn;
  late bool _ready;
  late final List<StreamSubscription<void>> _changes;

  @override
  void dispose() {
    for (final changes in _changes) {
      unawaited(changes.cancel());
    }
    super.dispose();
  }
}

/// The router over the route table, guarded by [authRedirect] against the
/// live state of [auth] and [onboarding]. The redirect reads both when it
/// runs rather than values captured earlier, so a sign-out from anywhere —
/// the Profile screen, an expired token, an account deleted elsewhere —
/// lands on Welcome and replaces whatever was on the stack.
GoRouter createRouter({
  required AuthBloc auth,
  required OnboardingStore onboarding,
  required RouteRefresh refresh,
  required List<NavigatorObserver> observers,
}) => GoRouter(
  routes: appRoutes,
  initialLocation: const JournalRoute().location,
  refreshListenable: refresh,
  redirect: (context, state) => authRedirect(
    signedIn: auth.state is AuthSignedIn,
    readyForAccount: onboarding.readyForAccount,
    uri: state.uri,
  ),
  observers: observers,
);
