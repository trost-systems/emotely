import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:feature_auth/src/review_accounts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:human_check/human_check.dart';
import 'package:profile_repository/profile_repository.dart';
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
/// which has no mailbox either). A code request and a password both go
/// through [HumanCheck] first: Supabase Auth refuses either without a
/// Cloudflare Turnstile token (#94). Supabase Auth owns the session
/// (persistence, refresh); this bloc mirrors it into UI state and tells
/// PostHog who the user is. Each sign-in through the screen also leaves the
/// way in on the device ([LastSignInStore]), for the "Last used" tag, and
/// the language the screen was shown in on the account
/// ([mailLanguageKey]), for the language of the sign-in mail.
class AuthBloc({
  required final SupabaseClient _supabase,
  required final AuthAnalytics _analytics,
  required final ErrorReporter _errors,
  required final ProviderSignIn _providers,
  required final LastSignInStore _lastSignIn,
  required final HumanCheck _humanCheck,
  final Set<String> _passwordAccounts = const {},
}) extends Bloc<AuthEvent, AuthState> {
  this : super(_initial(_supabase.auth.currentSession)) {
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthCodeSubmitted>(_onCodeSubmitted);
    on<AuthPasswordSubmitted>(_onPasswordSubmitted);
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

  /// Where the account keeps the language its sign-in mail is written in:
  /// `user_metadata`, which the mail template reads as `.Data`
  /// (`supabase/templates/sign_in_code.html`; English when it is missing).
  /// A key of the app's own, not `locale`: Google's claims are merged into
  /// the same metadata on every sign-in, and they carry a `locale` of
  /// their own.
  static const mailLanguageKey = 'app_locale';

  /// The language the sign-in screen is shown in, once it has said so.
  String? _language;

  static AuthState _initial(Session? session) => session == null
      ? const AuthState.signedOut()
      : AuthState.signedIn(
          userId: session.user.id,
          identity: SignInIdentity.ofUser(session.user),
        );

  /// Whether [email] is one of [_passwordAccounts], normalized the way
  /// [isReviewAccount] normalizes.
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
      await _humanCheck.guard(
        (captchaToken) => _supabase.auth.signInWithOtp(
          email: email,
          shouldCreateUser: event.createAccount,
          // Supabase keeps it only on an account this request creates, so
          // the very first mail is in the app's language; an existing
          // account learns it once signed in ([_keepMailLanguage]).
          data: {mailLanguageKey: ?_language},
          captchaToken: captchaToken,
        ),
      );
      emit(AuthState.codeSent(email: email));
    } on Exception catch (error, stackTrace) {
      unawaited(_analytics.codeRequestFailed());
      unawaited(_errors.codeRequestFailed(error, stackTrace));
      emit(
        AuthState.signedOut(
          problem: _problem(error, fallback: SignInProblem.couldNotSend),
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
          unawaited(_lastSignIn.remember(SignInOption.emailCode));
          _signedIn(session.user, emit);
        } else {
          _rejected(email, SignInProblem.wrongCode, emit);
        }
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.codeVerifyFailed(error, stackTrace));
        _rejected(
          email,
          _problem(error, fallback: SignInProblem.wrongCode),
          emit,
        );
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
        final session = await _humanCheck.guard(
          (captchaToken) => _supabase.auth.signInWithPassword(
            email: email,
            password: event.password,
            captchaToken: captchaToken,
          ),
        );
        unawaited(_analytics.signedIn(SignInMethod.password));
        // A password starts at the email field, the button it tags.
        unawaited(_lastSignIn.remember(SignInOption.emailCode));
        _signedIn(session.user, emit);
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.passwordSignInFailed(error, stackTrace));
        _passwordRefused(
          email,
          _problem(error, fallback: SignInProblem.wrongPassword),
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

  void _onEmailChangeRequested(
    AuthEmailChangeRequested event,
    Emitter<AuthState> emit,
  ) => emit(const AuthState.signedOut());

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
  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    switch ((event.userId, event.identity)) {
      case (final userId?, final identity?):
        if (state case AuthSignedIn(userId: final current)
            when current == userId) {
          _stillSignedIn(userId, identity, emit);
        } else {
          _signed(userId, identity, emit);
        }
      case _:
        if (state is AuthSignedIn) {
          emit(const AuthState.signedOut());
        }
    }
  }

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

  void _rejected(String email, SignInProblem problem, Emitter<AuthState> emit) {
    unawaited(_analytics.codeRejected());
    emit(AuthState.codeSent(email: email, problem: problem));
  }

  void _passwordRefused(
    String email,
    SignInProblem problem,
    Emitter<AuthState> emit,
  ) {
    unawaited(_analytics.passwordFailed());
    emit(AuthState.passwordRequired(email: email, problem: problem));
  }

  /// A sign-in through the screen, by any way in.
  void _signedIn(User user, Emitter<AuthState> emit) {
    _signed(user.id, SignInIdentity.ofUser(user), emit);
    unawaited(_keepMailLanguage(user));
  }

  /// Keeps the screen's language on [user]'s account for the next sign-in
  /// mail, unless the account has it already. Never in the way of the
  /// sign-in: a failure only leaves the next mail in the language kept
  /// before, and the next sign-in tries again.
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

  /// What the user can make of a failed sign-in step; the screen words it,
  /// and the raw message never reaches it. Anything Supabase refused that is
  /// not a rate limit is the step's own [fallback]. The two limits are
  /// GoTrue's, per IP: the email one for sending codes, the request one on
  /// every sign-in bucket (`sign_in_sign_ups`, `token_verifications`) —
  /// where a credential may well be right, so it must not be called wrong.
  static SignInProblem _problem(
    Exception error, {
    required SignInProblem fallback,
  }) => switch (error) {
    AuthApiException(errorCode: 'over_email_send_rate_limit') =>
      SignInProblem.tooManyCodes,
    AuthApiException(errorCode: 'over_request_rate_limit') =>
      SignInProblem.tooManyAttempts,
    // A code asked for with `shouldCreateUser: false` for an address with
    // no account: GoTrue refuses the sign-up it would take.
    AuthApiException(errorCode: 'otp_disabled') => SignInProblem.noAccount,
    // No token, or one GoTrue could not verify with Cloudflare (#94).
    HumanCheckFailed() || AuthApiException(errorCode: 'captcha_failed') =>
      SignInProblem.humanCheckFailed,
    AuthRetryableFetchException() => SignInProblem.unreachable,
    _ => fallback,
  };

  @override
  Future<void> close() async {
    await _sessionChanges.cancel();
    await super.close();
  }
}
