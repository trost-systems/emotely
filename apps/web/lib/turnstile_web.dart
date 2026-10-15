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
  // A synchronous throw from Cloudflare's script fails the check like
  // any other failure, so the form never stays busy.
  final JSString? widget;
  try {
    widget = turnstile.callMethod<JSString?>(
      'render'.toJS,
      '#$containerId'.toJS,
      options,
    );
  } on Object {
    return null;
  }
  if (widget == null) {
    return null;
  }
  try {
    turnstile.callMethod<JSAny?>('execute'.toJS, widget);
    return await token.future;
  } on Object {
    return null;
  } finally {
    try {
      turnstile.callMethod<JSAny?>('remove'.toJS, widget);
    } on Object {
      // Already gone or never rendered: nothing is left to remove.
    }
  }
}

/// The load of Cloudflare's script in flight or done, shared by every
/// request on this page; null again once a load failed, so the next
/// request starts a fresh one.
Future<JSObject?>? _loading;

/// `window.turnstile`, loading Cloudflare's script first if no earlier
/// request on this page did; null if it does not load.
Future<JSObject?> _turnstile() {
  final loaded = globalContext.getProperty<JSObject?>('turnstile'.toJS);
  if (loaded != null) {
    return Future.value(loaded);
  }
  final head = web.document.head;
  if (head == null) {
    return Future.value();
  }
  return _loading ??= _load(head);
}

/// Appends Cloudflare's script and waits until it loaded or failed. A
/// failed script is removed: a dead element never fires again, so a retry
/// appends a fresh one.
Future<JSObject?> _load(web.HTMLHeadElement head) async {
  final done = Completer<void>();
  void finish(web.Event _) {
    if (!done.isCompleted) {
      done.complete();
    }
  }

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = turnstileScript
    ..addEventListener('load', finish.toJS)
    ..addEventListener('error', finish.toJS);
  head.append(script);
  await done.future;
  final turnstile = globalContext.getProperty<JSObject?>('turnstile'.toJS);
  if (turnstile == null) {
    script.remove();
    _loading = null;
  }
  return turnstile;
}
