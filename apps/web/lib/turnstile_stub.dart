/// Server side of `turnstile.dart`: there is no browser, so no check.
library;

/// See `turnstile_web.dart`; always null here.
Future<String?> turnstileToken({
  required String containerId,
  required String siteKey,
  required String language,
}) async => null;
