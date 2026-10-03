import 'package:human_check/human_check.dart';

/// Stands in for Cloudflare Turnstile's hidden web view, the one leaf of
/// the human check (`package:human_check`): hands out numbered tokens, or
/// none at all once [fails] is set, and counts how many it handed out.
///
/// Turnstile runs in a platform web view, which `flutter test` cannot
/// host, so the app's token source is replaced here the way the http
/// clients are.
class HumanCheckStub() {
  /// Challenges for the app to host, which no test ever asks: [token]
  /// answers in their place.
  static final idleTurnstile = TurnstileChallenges(
    siteKey: 'test-site-key',
    origin: Uri.parse('https://getemotely.test/'),
  );

  /// The token the next check hands out is `turnstile-token-<issued + 1>`.
  var issued = 0;

  /// When true, every check gives no token, as a failed challenge does.
  var fails = false;

  /// The token source to register (`registerHumanCheck(token: ...)`).
  Future<String?> token() async => fails ? null : 'turnstile-token-${++issued}';

  /// What a request carrying the [n]th token says to GoTrue.
  static Map<String, Object?> security(int n) => {
    'captcha_token': 'turnstile-token-$n',
  };
}
