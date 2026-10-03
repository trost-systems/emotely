// coverage:ignore-file
// The human check's leaf: a headless platform web view, which no widget
// test can host. Tests hand `registerApp` the scripted HumanCheckStub
// instead, the way they replace the http clients.

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:emotely/app/environment.dart';
import 'package:human_check/human_check.dart';

/// How long a check may take before it counts as failed. Turnstile settles
/// in a second or two; a check that never answers (no network, a challenge
/// a hidden web view cannot show) must not leave the sign-in screen
/// spinning.
const _patience = Duration(seconds: 30);

/// One Cloudflare Turnstile challenge in a hidden web view, under the
/// site's origin: its single-use token, or null if it expired before it
/// answered. A fresh web view per call, disposed once it answered, so no
/// token or widget outlives the request it was for.
///
/// What the challenge throws, a `TurnstileException` or the web view's own
/// load error (which is no `Exception`), arrives as [HumanCheckFailed].
Future<String?> turnstileToken() async {
  final turnstile = CloudflareTurnstile.invisible(
    siteKey: turnstileSiteKey,
    baseUrl: turnstileOrigin,
  );
  try {
    return await turnstile.getToken().timeout(_patience);
  } on Object catch (error) {
    throw HumanCheckFailed(error);
  } finally {
    await turnstile.dispose();
  }
}
