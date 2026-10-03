/// @docImport 'package:human_check/src/turnstile.dart';
library;

/// Where a token comes from: one Cloudflare Turnstile challenge per call,
/// answering its single-use token, or null when the challenge gave none.
///
/// It may also throw: an [Exception] counts as a failed check, and a
/// source that knows more throws [HumanCheckFailed] with its own cause.
/// The app wires it to [TurnstileChallenges.token], whose web view
/// `TurnstileHost` shows; feature and app tests hand in a scripted one
/// (`HumanCheckStub` in `testing`), so no test of theirs needs a web view.
typedef HumanCheckToken = Future<String?> Function();

/// The human check gave no token: the challenge failed, timed out, or
/// could not load. The call it guarded was never made.
///
/// [cause] is what the challenge threw, if anything, for error tracking;
/// it never reaches a screen.
class const HumanCheckFailed([final Object? cause]) implements Exception;

/// The proof that a person, not a script, is asking Supabase Auth for
/// something a script could abuse (#94).
///
/// Once the hosted project enforces its captcha, GoTrue refuses a code
/// request, a password sign-in, a sign-up or a password recovery with
/// `400 captcha_failed` unless the request carries a token that verifies
/// with Cloudflare. A token verifies once and lapses after five minutes,
/// so every such call gets a fresh one, and only from here:
///
/// ```dart
/// await humanCheck.guard(
///   (token) => supabase.auth.signInWithOtp(email: e, captchaToken: token),
/// );
/// ```
///
/// Calls GoTrue does not check — verifying a code, refreshing a session,
/// trading a Google or Apple ID token — need none, and asking for one
/// would only make them slower.
class HumanCheck(final HumanCheckToken _token) {
  /// Runs [call] with a fresh token and answers what it answers; what it
  /// throws, such as GoTrue's own refusal, reaches the caller untouched.
  ///
  /// Throws [HumanCheckFailed], without making the call, when the check
  /// gives no token.
  Future<T> guard<T>(Future<T> Function(String token) call) async {
    final String? token;
    try {
      token = await _token();
    } on HumanCheckFailed {
      rethrow;
    } on Exception catch (error) {
      throw HumanCheckFailed(error);
    }
    if (token == null || token.isEmpty) {
      throw const HumanCheckFailed();
    }
    return await call(token);
  }
}
