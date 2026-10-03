part of 'auth_bloc.dart';

/// The email and password ways in (#187, ADR 0010): sign in, a new account
/// that opens once the code mailed to it is typed in, and a forgotten
/// password reset with a mailed code. Codes, never links: the app has no
/// deep links, and a code works when the mail is read on another device.
///
/// Every request that GoTrue guards with its captcha (#94) — a new account,
/// a password sign-in, a reset, a code sent again — goes through
/// [_humanCheck] for a fresh token; the code checks themselves need none.
mixin _EmailSignIn on Bloc<AuthEvent, AuthState> {
  SupabaseClient get _supabase;
  AuthAnalytics get _analytics;
  ErrorReporter get _errors;
  LastSignInStore get _lastSignIn;
  HumanCheck get _humanCheck;
  String? get _language;
  void _signedIn(User user, Emitter<AuthState> emit);

  Future<void> _onSignInSubmitted(
    AuthSignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    emit(AuthState.checking(email: email));
    await _passwordGrant(
      email,
      event.password,
      emit,
      refused: SignInProblem.wrongPassword,
    );
  }

  /// Signs into [email] with [password]; [refused] is what a refusal tells
  /// the user. An account whose address was never confirmed gets a new
  /// confirmation code instead, and the code step: GoTrue grants it no
  /// session until then.
  Future<void> _passwordGrant(
    String email,
    String password,
    Emitter<AuthState> emit, {
    required SignInProblem refused,
  }) async {
    try {
      // Always a session: an answer without one throws, like a refusal.
      final session = await _humanCheck.guard(
        (captchaToken) => _supabase.auth.signInWithPassword(
          email: email,
          password: password,
          captchaToken: captchaToken,
        ),
      );
      _passwordAccepted(session.user, emit);
    } on Exception catch (error, stackTrace) {
      if (error case AuthApiException(errorCode: 'email_not_confirmed')) {
        await _sendCode(email, CodePurpose.confirmAccount, emit);
        return;
      }
      unawaited(_errors.passwordSignInFailed(error, stackTrace));
      unawaited(_analytics.passwordFailed());
      emit(
        AuthState.signedOut(
          email: email,
          problem: _problem(error, fallback: refused),
        ),
      );
    }
  }

  /// [user] is in with their email and password, by whichever step got
  /// there: the email field is the button the "Last used" tag marks.
  void _passwordAccepted(User user, Emitter<AuthState> emit) {
    unawaited(_analytics.signedIn(SignInMethod.password));
    unawaited(_lastSignIn.remember(SignInOption.email));
    _signedIn(user, emit);
  }

  /// A new account for [AuthSignUpSubmitted.email]. GoTrue answers with the
  /// account and no session, and mails the confirmation code; with
  /// confirmations off it answers with a session, which signs in at once.
  /// An address that has an account already is signed into with the
  /// password typed, which is the likeliest meaning of the request.
  Future<void> _onSignUpSubmitted(
    AuthSignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    _chosen = (email: email, password: event.password);
    emit(AuthState.checking(email: email));
    unawaited(_analytics.signUpRequested());
    try {
      final response = await _humanCheck.guard(
        (captchaToken) => _supabase.auth.signUp(
          email: email,
          password: event.password,
          // The confirmation mail is the account's first: in the language
          // the screen is shown in.
          data: {AuthBloc.mailLanguageKey: ?_language},
          captchaToken: captchaToken,
        ),
      );
      if (response.session case final session?) {
        _passwordAccepted(session.user, emit);
      } else {
        emit(
          AuthState.codeSent(email: email, purpose: CodePurpose.confirmAccount),
        );
      }
    } on Exception catch (error, stackTrace) {
      if (error case AuthApiException(errorCode: 'user_already_exists')) {
        await _passwordGrant(
          email,
          event.password,
          emit,
          refused: SignInProblem.accountExists,
        );
        return;
      }
      unawaited(_errors.signUpFailed(error, stackTrace));
      unawaited(_analytics.signUpFailed());
      emit(
        AuthState.signedOut(
          email: email,
          problem: _problem(error, fallback: SignInProblem.couldNotSend),
        ),
      );
    }
  }

  /// "Forgot password?" for [AuthResetRequested.email]. GoTrue answers the
  /// same whether the address has an account or not, so the step that
  /// follows says "if".
  Future<void> _onResetRequested(
    AuthResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    emit(AuthState.checking(email: email));
    unawaited(_analytics.passwordResetRequested());
    await _sendCode(email, CodePurpose.resetPassword, emit);
  }

  Future<void> _onCodeResendRequested(
    AuthCodeResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state case AuthCodeSent(:final email, :final purpose)) {
      emit(AuthState.checkingCode(email: email, purpose: purpose));
      await _sendCode(email, purpose, emit, again: true);
    }
  }

  /// Mails [email] the code for [purpose] and asks for it. A failure goes
  /// back where the user asked from: the email and password, or the code
  /// step when the code was asked for [again].
  Future<void> _sendCode(
    String email,
    CodePurpose purpose,
    Emitter<AuthState> emit, {
    bool again = false,
  }) async {
    try {
      await _humanCheck.guard(
        (captchaToken) => switch (purpose) {
          CodePurpose.confirmAccount => _supabase.auth.resend(
            type: OtpType.signup,
            email: email,
            captchaToken: captchaToken,
          ),
          CodePurpose.resetPassword => _supabase.auth.resetPasswordForEmail(
            email,
            captchaToken: captchaToken,
          ),
        },
      );
      emit(AuthState.codeSent(email: email, purpose: purpose, resent: again));
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.codeSendFailed(error, stackTrace));
      if (purpose == CodePurpose.resetPassword) {
        unawaited(_analytics.passwordResetFailed());
      }
      final problem = _problem(error, fallback: SignInProblem.couldNotSend);
      emit(
        again
            ? AuthState.codeSent(
                email: email,
                purpose: purpose,
                problem: problem,
              )
            : AuthState.signedOut(email: email, problem: problem),
      );
    }
  }

  /// The address and password of the last sign-up on this screen, kept
  /// only until its confirmation code opens the account. GoTrue keeps an
  /// unconfirmed account's *first* password when the address signs up
  /// again, so the app sets the one typed last ([_onConfirmationSubmitted]).
  ({String email, String password})? _chosen;

  /// The confirmation code, which opens the new account, then the password
  /// typed last for it. GoTrue answers `same_password` in the ordinary
  /// case, which changes nothing and mails nothing.
  Future<void> _onConfirmationSubmitted(
    AuthConfirmationSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    const purpose = CodePurpose.confirmAccount;
    if (state case AuthCodeSent(
      :final email,
      purpose: CodePurpose.confirmAccount,
    )) {
      emit(AuthState.checkingCode(email: email, purpose: purpose));
      final Session session;
      try {
        session = await _verify(email, event.code, OtpType.signup);
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.codeVerifyFailed(error, stackTrace));
        unawaited(_analytics.confirmationCodeRejected());
        _codeRefused(email, purpose, error, emit);
        return;
      }
      final chosen = _chosen;
      _chosen = null;
      if (chosen != null && chosen.email == email) {
        await _savePassword(email, session.user, chosen.password, emit);
      } else {
        // Confirmed from a sign-in: the password typed there already works.
        _passwordAccepted(session.user, emit);
      }
    }
  }

  /// The reset code, and the new password to save once it signed the
  /// account in.
  Future<void> _onResetSubmitted(
    AuthResetSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    const purpose = CodePurpose.resetPassword;
    if (state case AuthCodeSent(
      :final email,
      purpose: CodePurpose.resetPassword,
    )) {
      emit(AuthState.checkingCode(email: email, purpose: purpose));
      final Session session;
      try {
        session = await _verify(email, event.code, OtpType.recovery);
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.codeVerifyFailed(error, stackTrace));
        unawaited(_analytics.resetCodeRejected());
        _codeRefused(email, purpose, error, emit);
        return;
      }
      await _savePassword(
        email,
        session.user,
        event.newPassword,
        emit,
        reset: true,
      );
    }
  }

  Future<void> _onNewPasswordSubmitted(
    AuthNewPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (state case AuthNewPasswordRequired(:final email, :final user)) {
      emit(AuthState.savingPassword(email: email, user: user));
      await _savePassword(email, user, event.newPassword, emit);
    }
  }

  /// The session [code] opens for [email]. Supabase answers 200 without
  /// one for a few flows this app never starts (two-step email changes);
  /// here it can only mean the code opened nothing, so it counts as refused.
  Future<Session> _verify(String email, String code, OtpType type) async {
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: code,
      type: type,
    );
    return response.session ??
        (throw const AuthException('The code opened no session.'));
  }

  void _codeRefused(
    String email,
    CodePurpose purpose,
    Exception error,
    Emitter<AuthState> emit,
  ) => emit(
    AuthState.codeSent(
      email: email,
      purpose: purpose,
      problem: _problem(error, fallback: SignInProblem.wrongCode),
    ),
  );

  /// Sets [password] on [user]'s account, which a code signed in, and lets
  /// them in. The same password as before is set already. Any other
  /// failure keeps the user on the screen to try again: they are signed
  /// in, but an account may not have the password they chose. [reset] says
  /// it is a reset's password, for analytics.
  Future<void> _savePassword(
    String email,
    User user,
    String password,
    Emitter<AuthState> emit, {
    bool reset = false,
  }) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
    } on Exception catch (error, stackTrace) {
      if (error case AuthApiException(errorCode: 'same_password')) {
        _passwordAccepted(user, emit);
        return;
      }
      unawaited(_errors.passwordSaveFailed(error, stackTrace));
      if (reset) {
        unawaited(_analytics.passwordResetFailed());
      }
      emit(
        AuthState.newPasswordRequired(
          email: email,
          user: user,
          problem: _problem(error, fallback: SignInProblem.passwordNotSaved),
        ),
      );
      return;
    }
    _passwordAccepted(user, emit);
  }
}

/// What the user can make of a failed sign-in step; the screen words it,
/// and the raw message never reaches it. Anything Supabase refused that is
/// not named here is the step's own [fallback]. The two limits are GoTrue's,
/// per IP: the email one for mailing codes, the request one on every
/// sign-in bucket (`sign_in_sign_ups`, `token_verifications`) — where a
/// credential may well be right, so it must not be called wrong.
SignInProblem _problem(Exception error, {required SignInProblem fallback}) =>
    switch (error) {
      AuthApiException(errorCode: 'over_email_send_rate_limit') =>
        SignInProblem.tooManyCodes,
      AuthApiException(errorCode: 'over_request_rate_limit') =>
        SignInProblem.tooManyAttempts,
      // Shorter than `minimum_password_length` (supabase/config.toml); the
      // screen checks the same length first, so this is the server's word
      // on a rule the app does not know yet.
      AuthApiException(errorCode: 'weak_password') =>
        SignInProblem.weakPassword,
      // No token, or one GoTrue could not verify with Cloudflare (#94).
      HumanCheckFailed() || AuthApiException(errorCode: 'captcha_failed') =>
        SignInProblem.humanCheckFailed,
      AuthRetryableFetchException() => SignInProblem.unreachable,
      _ => fallback,
    };
