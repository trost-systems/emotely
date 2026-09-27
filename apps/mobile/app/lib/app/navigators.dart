import 'dart:async';

import 'package:analytics/analytics.dart' show OnboardingNext;
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_session/feature_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The app's side of every feature's navigator (ADR 0015): a feature says
/// what it needs from another feature, the app says how — with that
/// feature's route (ADR 0016), from the context of the tap that asked. A
/// feature's own screens it reaches itself.

/// What onboarding leads to outside itself: sign-in behind "I have an
/// account", and, once the account holds the name, the journal — or the
/// first session straight away for a new account (#204), through the
/// journal's own way in, so the consent gate is the one "Start a session"
/// uses. A deep link the user was following wins over both.
class const AppOnboardingNavigator() implements OnboardingNavigator {
  @override
  void signIn(BuildContext context, {String? from}) =>
      SignInRoute(from: from).go(context);

  @override
  void finish(
    BuildContext context, {
    required OnboardingNext next,
    String? from,
  }) => from == null
      ? JournalRoute(startSession: next == OnboardingNext.session).go(context)
      : context.go(from);
}

/// What sign-in needs of onboarding: the name to greet a new account by,
/// and the way back. Back from sign-up reopens the greeting on the device,
/// and the redirect takes the user there; back from sign-in is Welcome.
class const AppSignInNavigator(final OnboardingStore _onboarding)
    implements SignInNavigator {
  @override
  String? signUpName() => switch (_onboarding.progress.displayName) {
    '' => null,
    final name => name,
  };

  @override
  void leave(BuildContext context, SignInMode mode) => switch (mode) {
    SignInMode.signUp => unawaited(_onboarding.reopen()),
    SignInMode.signIn => const OnboardingRoute().go(context),
  };
}

/// Signing out is the auth feature's act: the router lands on Welcome once
/// the auth bloc has ended the session. The consent screen is the account
/// feature's own route, pushed here so the More tab, which lives in the
/// tab shell, gets it on the root navigator above the bar.
class const AppAccountNavigator() implements AccountNavigator {
  @override
  void signOut(BuildContext context) =>
      context.read<AuthBloc>().add(const AuthEvent.signOutRequested());

  /// The More tab reads the record again once the route closes, so what
  /// the route answered is of no use to it here.
  @override
  Future<void> requestConsent(BuildContext context) =>
      const ConsentRoute().push<ConsentOutcome>(context);
}

/// What the journal leads to outside itself: the session and the consent
/// gate.
class const AppJournalNavigator() implements JournalNavigator {
  @override
  Future<void> startSession(BuildContext context, {String? resume}) =>
      SessionRoute(resume: resume).push<void>(context);

  /// The consent screen on its own route ([ConsentRoute]), answering how
  /// it was left. A decline, a failed write and a dismissed route all leave
  /// the gate shut and land the user back on the journal — but they are
  /// not the same thing to say, so the message is chosen by what actually
  /// happened rather than always reading as a refusal.
  @override
  Future<bool> requestConsent(BuildContext context) async {
    final outcome = await const ConsentRoute().push<ConsentOutcome>(context);
    if (outcome == ConsentOutcome.granted) {
      return true;
    }
    // The journal is still there under the popped route, unless a sign-out
    // replaced the stack meanwhile; then there is nobody to tell.
    if (context.mounted) {
      _saySoFar(context, outcome);
    }
    return false;
  }

  /// Tells the user, back on the journal, why no session started. A refusal
  /// and a failed write are not the same news: telling someone who ticked
  /// the box and hit a network error that they chose "Not now" is untrue.
  /// Dismissing the screen says nothing at all — the user left, and knows
  /// it — and so does a failed read, whose screen already said its piece.
  static void _saySoFar(BuildContext context, ConsentOutcome? outcome) {
    final message = switch (outcome) {
      ConsentOutcome.writeFailed => consentFailureMessage,
      ConsentOutcome.declined => consentDeclinedMessage,
      ConsentOutcome.granted || null => null,
    };
    if (message == null) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}
