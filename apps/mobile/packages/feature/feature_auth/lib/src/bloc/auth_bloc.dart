import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:feature_auth/src/internal_accounts.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:human_check/human_check.dart';
import 'package:profile_repository/profile_repository.dart';
// gotrue has its own AuthState (the stream event); ours is the bloc state.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';
part 'email_sign_in.dart';

/// Who is signed in, and the ways in: an email and a password
/// ([_EmailSignIn]: sign in, a new account confirmed by a mailed code, a
/// forgotten password reset by one), or a provider's ID token from its own
/// sheet ([ProviderSignIn]), traded for a session. Every request GoTrue
/// guards with a captcha goes through [HumanCheck] first (#94).
/// Supabase Auth owns the session (persistence, refresh); this bloc mirrors
/// it into UI state and tells PostHog who the user is. Each sign-in through
/// the screen also leaves the way in on the device ([LastSignInStore]), for
/// the "Last used" tag, and the language the screen was shown in on the
/// account ([mailLanguageKey]), for the language of its mails.
class AuthBloc({
  @override required final SupabaseClient _supabase,
  @override required final AuthAnalytics _analytics,
  @override required final ErrorReporter _errors,
  required final ProviderSignIn _providers,
  @override required final LastSignInStore _lastSignIn,
  @override required final HumanCheck _humanCheck,
}) extends Bloc<AuthEvent, AuthState> with _EmailSignIn {
  this : super(_initial(_supabase.auth.currentSession)) {
    on<AuthSignInSubmitted>(_onSignInSubmitted);
    on<AuthSignUpSubmitted>(_onSignUpSubmitted);
    on<AuthResetRequested>(_onResetRequested);
    on<AuthConfirmationSubmitted>(_onConfirmationSubmitted);
    on<AuthResetSubmitted>(_onResetSubmitted);
    on<AuthNewPasswordSubmitted>(_onNewPasswordSubmitted);
    on<AuthCodeResendRequested>(_onCodeResendRequested);
    on<AuthProviderSelected>(_onProviderSelected);
    on<AuthLanguageShown>((event, _) => _language = event.languageCode);
    on<AuthEmailChangeRequested>(_onEmailChangeRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthSessionChanged>(_onSessionChanged);
    if (state case AuthSignedIn(:final userId, :final identity)) {
      _identify(userId, identity.email);
    }
    _sessionChanges = _supabase.auth.onAuthStateChange.listen(
      (change) => add(switch (change.session?.user) {
        null => const AuthEvent.sessionChanged(null, null),
        final user => AuthEvent.sessionChanged(
          user.id,
          SignInIdentity.ofUser(user),
        ),
      }),
      // A failed background refresh is reported here; the SDK keeps the
      // session until it really expires and signs out through the stream
      // then, so there is nothing to do with the error itself.
      onError: (Object _, StackTrace _) {},
    );
  }

  late final StreamSubscription<void> _sessionChanges;

  /// Where the account keeps the language its mails are written in:
  /// `user_metadata`, which the mail templates read as `.Data`
  /// (`supabase/templates/`; English when it is missing). A key of the
  /// app's own, not `locale`: Google's claims are merged into the same
  /// metadata on every sign-in, and they carry a `locale` of their own.
  static const mailLanguageKey = 'app_locale';

  /// The language the sign-in screen is shown in, once it has said so.
  @override
  String? _language;

  static AuthState _initial(Session? session) => session == null
      ? const AuthState.signedOut()
      : AuthState.signedIn(
          userId: session.user.id,
          identity: SignInIdentity.ofUser(session.user),
        );

  /// Sign in with [AuthProviderSelected.provider], from the first step only:
  /// its sheet issues an ID token, Supabase trades it for a session. A
  /// dismissed sheet is no failure; the user is back where they were.
  Future<void> _onProviderSelected(
    AuthProviderSelected event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthSignedOut) {
      return;
    }
    final provider = event.provider;
    emit(AuthState.signingInWith(provider));
    try {
      final token = await _providers.signIn(provider);
      if (token == null) {
        unawaited(_analytics.providerCanceled(provider.method));
        emit(const AuthState.signedOut());
        return;
      }
      final session = await _supabase.auth.signInWithIdToken(
        provider: provider.oauth,
        idToken: token.idToken,
        nonce: token.nonce,
      );
      unawaited(_analytics.signedIn(provider.method));
      unawaited(_lastSignIn.remember(provider.option));
      _signedIn(session.user, emit);
    } on Exception catch (error, stackTrace) {
      unawaited(_analytics.providerFailed(provider.method));
      unawaited(
        _errors.providerSignInFailed(
          error,
          stackTrace,
          provider: provider.method,
        ),
      );
      emit(
        AuthState.signedOut(
          problem: _problem(error, fallback: SignInProblem.providerFailed),
        ),
      );
    }
  }

  /// Back from a code to the email and password, keeping the address.
  void _onEmailChangeRequested(
    AuthEmailChangeRequested event,
    Emitter<AuthState> emit,
  ) {
    if (state case AuthCodeSent(:final email)) {
      emit(AuthState.signedOut(email: email));
    }
  }

  /// Ends the session on this device. The SDK drops it locally first and
  /// reports that on its stream, which is what moves the UI; whether the
  /// server-side revocation then succeeds changes nothing here, and
  /// neither does a provider that cannot be signed out of.
  ///
  /// PostHog hears `signed_out`, and forgets the choice, before any of
  /// that: once the stream reports the sign-out the router is on Welcome,
  /// and nothing Welcome sends may go out under this person's id or
  /// consent (#204).
  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _analytics.signedOut();
    try {
      await _supabase.auth.signOut();
    } on Exception {
      // Already signed out locally; see above.
    }
    try {
      await _providers.signOut();
    } on Exception {
      // Only the provider's own shortcut back in; the session is gone.
    }
  }

  /// Supabase's own view of the session, which wins: a sign-out, an expiry
  /// or a deleted account ends the signed-in state wherever the UI is.
  ///
  /// Except while a code has signed the account in and its password is
  /// still being set (a reset's new one, or a new account's typed last):
  /// the session is real, but the user is not past the screen until the
  /// password is saved ([_savePassword]).
  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    switch ((event.userId, event.identity)) {
      case (final userId?, final identity?):
        if (state case AuthSignedIn(userId: final current)
            when current == userId) {
          _stillSignedIn(userId, identity, emit);
        } else if (!_settingPassword) {
          _signed(userId, identity, emit);
        }
      case _:
        if (state is AuthSignedIn) {
          emit(const AuthState.signedOut());
        }
    }
  }

  bool get _settingPassword => switch (state) {
    AuthCheckingCode() ||
    AuthNewPasswordRequired() ||
    AuthSavingPassword() => true,
    _ => false,
  };

  /// The same user, as the SDK reports on every token refresh — or with a
  /// new address (a confirmed email change): no new sign-in, but the state
  /// shows the new address, and PostHog's flag may have flipped.
  void _stillSignedIn(
    String userId,
    SignInIdentity identity,
    Emitter<AuthState> emit,
  ) {
    emit(AuthState.signedIn(userId: userId, identity: identity));
    if (_isInternal(identity.email) != _internal) {
      _identify(userId, identity.email);
    }
  }

  /// A sign-in through the screen, by any way in.
  @override
  void _signedIn(User user, Emitter<AuthState> emit) {
    _signed(user.id, SignInIdentity.ofUser(user), emit);
    unawaited(_keepMailLanguage(user));
  }

  /// Keeps the screen's language on [user]'s account for its next mail,
  /// unless the account has it already. Never in the way of the sign-in: a
  /// failure only leaves the next mail in the language kept before, and the
  /// next sign-in tries again.
  Future<void> _keepMailLanguage(User user) async {
    final language = _language;
    if (language == null || user.userMetadata[mailLanguageKey] == language) {
      return;
    }
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {mailLanguageKey: language}),
      );
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.mailLanguageSaveFailed(error, stackTrace));
    }
  }

  void _signed(
    String userId,
    SignInIdentity identity,
    Emitter<AuthState> emit,
  ) {
    _identify(userId, identity.email);
    emit(AuthState.signedIn(userId: userId, identity: identity));
  }

  /// The flag last sent to PostHog, so a session change can tell whether
  /// it needs sending again; null until the first identify.
  bool? _internal;

  /// [email] goes no further than [isInternalAccount], which turns it into
  /// the one boolean PostHog gets — the address itself never leaves
  /// (ADR 0005). An account without one (Supabase never issues one here) is
  /// an ordinary user, not an internal one.
  static bool _isInternal(String? email) =>
      email != null && isInternalAccount(email);

  /// Tells PostHog who this device belongs to, and whether that is one of
  /// our own accounts.
  void _identify(String userId, String? email) => unawaited(
    _analytics.identify(
      userId: userId,
      internal: _internal = _isInternal(email),
    ),
  );

  @override
  Future<void> close() async {
    await _sessionChanges.cancel();
    await super.close();
  }
}
