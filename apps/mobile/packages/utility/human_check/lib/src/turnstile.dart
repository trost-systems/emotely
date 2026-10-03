import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:human_check/src/human_check.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The JavaScript channel the challenge page reports through.
const _channel = 'EmotelyHumanCheck';

/// Cloudflare Turnstile challenges, the production token source of
/// [HumanCheck] (#94): [token] runs one in a web view that [TurnstileHost]
/// shows over the app, and answers its single-use token.
///
/// The web view loads a page of our own under [origin], whose hostname the
/// widget behind [siteKey] must list; nothing is fetched from it, only
/// Cloudflare's script. The widget runs in managed mode and stays
/// invisible unless Cloudflare wants an interaction; then its checkbox
/// appears at the bottom of the screen and takes taps until it answers.
///
/// A check that has not answered within [patience] fails, unless it asked
/// for an interaction, which then has [interactionPatience] to happen.
class TurnstileChallenges({
  required final String siteKey,
  required final Uri origin,
  final Duration patience = const Duration(seconds: 30),
  final Duration interactionPatience = const Duration(minutes: 3),
}) {
  final _current = ValueNotifier<TurnstileChallenge?>(null);
  var _hosts = 0;

  /// A fresh token, or [HumanCheckFailed] when the check failed, timed
  /// out, was superseded by a newer one, or has no [TurnstileHost] to run
  /// in.
  Future<String?> token() async {
    if (_hosts == 0) {
      throw const HumanCheckFailed('no TurnstileHost is mounted');
    }
    _current.value?._fail('superseded');
    final challenge = TurnstileChallenge._(this);
    _current.value = challenge;
    try {
      return await challenge._token.future;
    } finally {
      if (_current.value == challenge) {
        _current.value = null;
      }
    }
  }

  void _attach() => _hosts++;

  void _detach() {
    _hosts--;
    if (_hosts == 0) {
      _current.value?._fail('host disposed');
    }
  }

  /// The page the web view loads: Cloudflare's script, one widget, and a
  /// report of every outcome through [_channel].
  String get _page =>
      '''
<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;background:transparent}</style>
<script>
function send(kind, value) {
  $_channel.postMessage(JSON.stringify({kind: kind, value: value || ''}));
}
function failed(code) { send('error', String(code)); return true; }
function start() {
  turnstile.render('#check', {
    sitekey: ${jsonEncode(siteKey)},
    appearance: 'interaction-only',
    retry: 'never',
    'refresh-expired': 'never',
    callback: function (token) { send('token', token); },
    'error-callback': failed,
    'expired-callback': function () { failed('expired'); },
    'timeout-callback': function () { failed('timeout'); },
    'unsupported-callback': function () { failed('unsupported'); },
    'before-interactive-callback': function () { send('interactive'); }
  });
}
</script>
<script async defer onerror="failed('script')"
  src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=start"></script>
</head><body><div id="check"></div></body></html>
''';
}

/// One running check: its web view, and whether it waits for the user.
class TurnstileChallenge._(final TurnstileChallenges _challenges) {
  this {
    _timer = Timer(_challenges.patience, () => _fail('timeout'));
    unawaited(_load());
  }

  final _token = Completer<String?>();
  late Timer _timer;

  /// The web view the challenge runs in.
  final controller = WebViewController();

  /// Whether Cloudflare asked the user to interact.
  final interactive = ValueNotifier(false);

  Future<void> _load() async {
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));
    await controller.addJavaScriptChannel(
      _channel,
      onMessageReceived: (message) => _receive(message.message),
    );
    await controller.loadHtmlString(
      _challenges._page,
      baseUrl: _challenges.origin.toString(),
    );
  }

  void _receive(String message) {
    final report = _decode(message);
    switch (report) {
      case ('token', final String token) when token.isNotEmpty:
        _settle(() => _token.complete(token));
      case ('interactive', _):
        interactive.value = true;
        _timer.cancel();
        _timer = Timer(_challenges.interactionPatience, () => _fail('timeout'));
      case (_, final code):
        _fail(code);
    }
  }

  static (String, String) _decode(String message) {
    try {
      final Object? decoded = jsonDecode(message);
      if (decoded case {
        'kind': final String kind,
        'value': final String value,
      }) {
        return (kind, value);
      }
    } on FormatException {
      // Answered as malformed below.
    }
    return ('error', 'malformed report');
  }

  void _fail(String cause) =>
      _settle(() => _token.completeError(HumanCheckFailed(cause)));

  void _settle(void Function() complete) {
    _timer.cancel();
    if (!_token.isCompleted) {
      complete();
    }
  }
}

/// Shows the running [TurnstileChallenges] check over [child]: a web view
/// at the bottom of the screen that is transparent until Cloudflare asks
/// for an interaction, and ignores taps until then. The app mounts it once,
/// over the navigator; a check without one fails.
class const TurnstileHost({
  required final TurnstileChallenges challenges,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<TurnstileHost> createState() => _TurnstileHostState();
}

class _TurnstileHostState() extends State<TurnstileHost> {
  @override
  void initState() {
    super.initState();
    widget.challenges._attach();
  }

  @override
  void dispose() {
    widget.challenges._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TurnstileChallenge?>(
        valueListenable: widget.challenges._current,
        builder: (context, challenge, child) => Stack(
          // Not directional: the host may sit above any Directionality.
          alignment: Alignment.topLeft,
          fit: StackFit.passthrough,
          children: [child!, if (challenge != null) _ChallengeView(challenge)],
        ),
        child: widget.child,
      );
}

class const _ChallengeView(final TurnstileChallenge challenge)
    extends StatelessWidget {
  /// Turnstile's normal widget size.
  static const size = Size(300, 65);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: challenge.interactive,
          builder: (context, interactive, view) =>
              IgnorePointer(ignoring: !interactive, child: view),
          child: SizedBox.fromSize(
            size: size,
            child: WebViewWidget(controller: challenge.controller),
          ),
        ),
      ),
    ),
  );
}
