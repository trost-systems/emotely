/// Browser side of `turnstile.dart`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:universal_web/web.dart' as web;

/// Cloudflare's script, which must be loaded from Cloudflare itself (it
/// may not be proxied or self-hosted). `render=explicit`: nothing renders
/// until [turnstileToken] asks.
const turnstileScript =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

/// A single-use Turnstile token for [siteKey], or null when the check
/// failed, could not load or is not supported by this browser.
///
/// Each call renders a fresh widget into the element with id
/// [containerId] and removes it once it has answered: a token verifies
/// once, so a retry needs a new one. The widget runs on demand and stays
/// invisible unless Cloudflare wants an interaction, in which case the
/// checkbox appears in the container, worded in [language].
Future<String?> turnstileToken({
  required String containerId,
  required String siteKey,
  required String language,
}) async {
  final turnstile = await _turnstile();
  if (turnstile == null) {
    return null;
  }
  final token = Completer<String?>();
  void settle(String? value) {
    if (!token.isCompleted) {
      token.complete(value);
    }
  }

  // A failure returns true: "handled", so Turnstile logs nothing more and
  // does not retry on its own; the reader's next click is the retry.
  JSBoolean failed([JSAny? _]) {
    settle(null);
    return true.toJS;
  }

  final options = JSObject()
    ..['sitekey'] = siteKey.toJS
    ..['language'] = language.toJS
    ..['execution'] = 'execute'.toJS
    ..['appearance'] = 'interaction-only'.toJS
    ..['retry'] = 'never'.toJS
    ..['callback'] = ((JSString value) => settle(value.toDart)).toJS
    ..['error-callback'] = failed.toJS
    ..['expired-callback'] = failed.toJS
    ..['timeout-callback'] = failed.toJS
    ..['unsupported-callback'] = failed.toJS;
  final widget = turnstile.callMethod<JSString?>(
    'render'.toJS,
    '#$containerId'.toJS,
    options,
  );
  if (widget == null) {
    return null;
  }
  try {
    turnstile.callMethod<JSAny?>('execute'.toJS, widget);
    return await token.future;
  } finally {
    turnstile.callMethod<JSAny?>('remove'.toJS, widget);
  }
}

/// `window.turnstile`, loading Cloudflare's script first if no earlier
/// request on this page did; null if it does not load.
Future<JSObject?> _turnstile() async {
  final loaded = globalContext.getProperty<JSObject?>('turnstile'.toJS);
  if (loaded != null) {
    return loaded;
  }
  final script =
      web.document.querySelector('script[src="$turnstileScript"]') ??
      (web.document.createElement('script') as web.HTMLScriptElement
        ..src = turnstileScript);
  if (!script.isConnected) {
    web.document.head?.append(script);
  }
  final done = Completer<void>();
  void finish(web.Event _) {
    if (!done.isCompleted) {
      done.complete();
    }
  }

  script
    ..addEventListener('load', finish.toJS)
    ..addEventListener('error', finish.toJS);
  await done.future;
  return globalContext.getProperty<JSObject?>('turnstile'.toJS);
}
