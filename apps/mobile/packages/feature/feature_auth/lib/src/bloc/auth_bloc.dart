import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:feature_auth/src/review_accounts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
// gotrue has its own AuthState (the stream event); ours is the bloc state.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';

/// Who is signed in, and the ways in: the two-step email code (request a
/// code for an email, then verify it), or a provider's ID token from its own
/// sheet ([ProviderSignIn]), traded for a session. The app stores' review
/// accounts ([reviewAccounts]) take a password at the second step instead,
/// since a reviewer has no mailbox to read, and so do the
/// [_passwordAccounts] the app names (the smoke account in a debug build,
/// which has no mailbox either). Supabase Auth owns the session
/// (persistence, refresh); this bloc mirrors it into UI state and tells
/// PostHog who the user is.
class AuthBloc({
  required final SupabaseClient _supabase,
  required final AuthAnalytics _analytics,
  required final ErrorReporter _errors,
  required final ProviderSignIn _providers,
  final Set<String> _passwordAccounts = const {},
}) extends Bloc<AuthEvent, AuthState> {
  this : super(_initial(_supabase.auth.currentSession)) {
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthCodeSubmitted>(_onCodeSubmitted);
    on<AuthPasswordSubmitted>(_onPasswordSubmitted);
    on<AuthProviderSelected>(_onProviderSelected);
    on<AuthEmailChangeRequested>(_onEmailChangeRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthSessionChanged>(_onSessionChanged);
    if (state case AuthSignedIn(:final userId)) {
      _identify(userId, _supabase.auth.currentSession?.user.email);
    }
    _sessionChanges = _supabase.auth.onAuthStateChange.listen(
      (change) => add(
        AuthEvent.sessionChanged(
          change.session?.user.id,
          change.session?.user.email,
        ),
      ),
      // A failed background refresh is reported here; the SDK keeps the
      // session until it really expires and signs out through the stream
      // then, so there is nothing to do with the error itself.
      onError: (Object _, StackTrace _) {},
    );
  }

  late final StreamSubscription<void> _sessionChanges;

  static AuthState _initial(Session? session) => session == null
      ? const AuthState.signedOut()
      : AuthState.signedIn(userId: session.user.id);

  /// Whether [email] is one of [_passwordAccounts], normalised the way
  /// [isReviewAccount] normalises.
  bool _isPasswordAccount(String email) => _passwordAccounts
      .map((account) => account.trim().toLowerCase())
      .contains(email.trim().toLowerCase());

  Future<void> _onEmailSubmitted(
    AuthEmailSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    // No code, no email: the review account is asked for its password.
    if (isReviewAccount(email) || _isPasswordAccount(email)) {
      emit(AuthState.passwordRequired(email: email));
      return;
    }
    emit(AuthState.requestingCode(email: email));
    unawaited(_analytics.codeRequested());
    try {
      await _supabase.auth.signInWithOtp(email: email);
      emit(AuthState.codeSent(email: email));
    } on Exception catch (error, stackTrace) {
      unawaited(_analytics.codeRequestFailed());
      unawaited(_errors.codeRequestFailed(error, stackTrace));
      emit(
        AuthState.signedOut(
          error: _describe(error, fallback: couldNotSendMessage),
        ),
      );
    }
  }

  Future<void> _onCodeSubmitted(
    AuthCodeSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (state case AuthCodeSent(:final email)) {
      emit(AuthState.verifying(email: email));
      try {
        final response = await _supabase.auth.verifyOTP(
          email: email,
          token: event.code,
          type: OtpType.email,
        );
        // Supabase answers 200 without a session for a few flows this app
        // never starts (two-step email changes); here it can only mean the
        // code did not sign anyone in.
        if (response.session case final session?) {
          unawaited(_analytics.signedIn(SignInMethod.code));
          _signedIn(session.user.id, session.user.email, emit);
        } else {
          _rejected(email, wrongCodeMessage, emit);
        }
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.codeVerifyFailed(error, stackTrace));
        _rejected(email, _describe(error, fallback: wrongCodeMessage), emit);
      }
    }
  }

  /// The password grant for a review account. Only ever `signInWithPassword`:
  /// the app has no sign-up path, so an address that is not on the server
  /// is refused like a wrong password.
  Future<void> _onPasswordSubmitted(
    AuthPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (state case AuthPasswordRequired(:final email)) {
      emit(AuthState.checkingPassword(email: email));
      try {
        // Always a session: an answer without one throws, like a refusal.
        final session = await _supabase.auth.signInWithPassword(
          email: email,
          password: event.password,
        );
        unawaited(_analytics.signedIn(SignInMethod.password));
        _signedIn(session.user.id, session.user.email, emit);
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.passwordSignInFailed(error, stackTrace));
        _passwordRefused(
          email,
          _describe(error, fallback: wrongPasswordMessage),
          emit,
        );
      }
    }
  }

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
      _signedIn(session.user.id, session.user.email, emit);
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
          error: _describe(error, fallback: providerFailedMessage),
        ),
      );
    }
  }

  void _onEmailChangeRequested(
    AuthEmailChangeRequested event,
    Emitter<AuthState> emit,
  ) => emit(const AuthState.signedOut());

  /// Ends the session on this device. The SDK drops it locally first and
  /// reports that on its stream, which is what moves the UI; whether the
  /// server-side revocation then succeeds changes nothing here, and
  /// neither does a provider that cannot be signed out of.
  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
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
    unawaited(_analytics.signedOut());
  }

  /// Supabase's own view of the session, which wins: a sign-out, an expiry
  /// or a deleted account ends the signed-in state wherever the UI is.
  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    switch (event.userId) {
      case null:
        if (state is AuthSignedIn) {
          emit(const AuthState.signedOut());
        }
      case final userId:
        if (state != AuthState.signedIn(userId: userId)) {
          _signedIn(userId, event.email, emit);
        } else if (_isInternal(event.email) != _internal) {
          // The same user with a new address (a confirmed email change):
          // no new sign-in, but the flag may have flipped.
          _identify(userId, event.email);
        }
    }
  }

  void _rejected(String email, String error, Emitter<AuthState> emit) {
    unawaited(_analytics.codeRejected());
    emit(AuthState.codeSent(email: email, error: error));
  }

  void _passwordRefused(String email, String error, Emitter<AuthState> emit) {
    unawaited(_analytics.passwordFailed());
    emit(AuthState.passwordRequired(email: email, error: error));
  }

  void _signedIn(String userId, String? email, Emitter<AuthState> emit) {
    _identify(userId, email);
    emit(AuthState.signedIn(userId: userId));
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

  /// User-facing copy for the failures a sign-in can hit; the raw message
  /// never reaches the screen. Anything Supabase refused that is not a rate
  /// limit is the step's own [fallback]. The two limits are GoTrue's, per
  /// IP: the email one for sending codes, the request one on every sign-in
  /// bucket (`sign_in_sign_ups`, `token_verifications`) — where a
  /// credential may well be right, so it must not be called wrong.
  static String _describe(Exception error, {required String fallback}) =>
      switch (error) {
        AuthApiException(errorCode: 'over_email_send_rate_limit') =>
          tooManyCodesMessage,
        AuthApiException(errorCode: 'over_request_rate_limit') =>
          tooManyAttemptsMessage,
        AuthRetryableFetchException() => unreachableMessage,
        _ => fallback,
      };

  static const tooManyCodesMessage =
      'Too many codes were requested. Please try again later.';
  static const tooManyAttemptsMessage =
      'Too many attempts. Wait a few minutes and try again.';
  static const couldNotSendMessage =
      'Could not send a code to that email. Check the address and try again.';
  static const wrongCodeMessage =
      'That code is wrong or has expired. Request a new one if needed.';
  static const wrongPasswordMessage = 'That password was not accepted.';
  static const unreachableMessage = 'Could not reach the sign-in service.';
  static const providerFailedMessage =
      'That sign-in did not go through. Try again, or use your email.';

  @override
  Future<void> close() async {
    await _sessionChanges.cancel();
    await super.close();
  }
}
