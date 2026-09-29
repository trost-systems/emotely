import 'dart:async';
import 'dart:convert';

import 'package:agent_client/src/startup_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;

/// What this build calls itself when asking for a store link.
///
/// `defaultTargetPlatform` rather than `dart:io`'s `Platform`: it reports the
/// platform the framework is running as, which a test can drive with
/// `TargetPlatformVariant`, where `Platform` would report the host the test
/// runs on. Anything without a store of its own asks for the neutral link.
String currentPlatform() => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => 'ios',
  TargetPlatform.android => 'android',
  _ => 'unknown',
};

/// Reads `GET /api/config`: what the app must know before it may run.
///
/// Unauthenticated by design. The users this call exists to block are on a
/// version the server no longer serves, and they must be told so before the
/// sign-in screen — which their build may no longer be able to drive.
class const ConfigClient({
  required final http.Client httpClient,
  required final Uri endpoint,
  final Duration timeout = defaultTimeout,

  /// What this build calls itself, so the server can pick the right store
  /// listing. Defaults to [currentPlatform]; anything the server does not
  /// recognise gets a neutral link rather than none.
  final String? platform,
}) {
  /// Shorter than a session round: this runs before the first frame the user
  /// can act on, and a slow answer is indistinguishable from a hung one.
  static const defaultTimeout = Duration(seconds: 10);

  /// The startup config, or a thrown [ConfigException] if it cannot be had.
  /// The caller blocks on failure rather than guessing a minimum.
  Future<StartupConfig> fetch() async {
    // The store link differs per platform (iOS and Android have different
    // listings), and only the server knows the current ones.
    final url = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'platform': platform ?? currentPlatform(),
      },
    );
    final http.Response response;
    try {
      response = await httpClient.get(url).timeout(timeout);
    } on Exception catch (error, stackTrace) {
      // A transport error names a host, never content — the same rule
      // `ErrorReporter.contentFree` applies to `ClientException` itself.
      // The original trace is kept: it names the socket or TLS layer that
      // failed, which is the only clue a report of this carries.
      Error.throwWithStackTrace(
        ConfigException('Could not reach emotely: $error', unreachable: true),
        stackTrace,
      );
    }
    if (response.statusCode != 200) {
      throw ConfigException('emotely answered ${response.statusCode}.');
    }
    final Object? decoded;
    try {
      // Same UTF-8 care as the session client: the server sends
      // `application/json` with no charset.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on Exception catch (_, stackTrace) {
      // Never the error's text: a `FormatException` embeds the source it
      // choked on, which here is the response body (ADR 0005). The trace is
      // content-free and says which decoder gave up, so it travels.
      Error.throwWithStackTrace(
        const ConfigException('emotely sent a config it could not read.'),
        stackTrace,
      );
    }
    // Every key the decoder needs, present and a String, checked before it
    // runs: a missing or mistyped field inside the generated `fromJson` is a
    // `TypeError`, and an Error must not be caught (`avoid_catching_errors`).
    // A partial config is just a bad response and has to block like one, not
    // crash the app on launch. The decode itself still goes through
    // `fromJson`, so the wire names live in one place — the generated code
    // the contract test pins — and not a second time in this condition.
    if (decoded case final Map<String, dynamic> json
        when StartupConfig.wireKeys.every((key) => json[key] is String)) {
      return StartupConfig.fromJson(json);
    }
    throw const ConfigException('emotely sent a config it could not read.');
  }
}

/// The startup config could not be read. Always blocking: the app cannot tell
/// "no minimum" from "could not ask", and must not assume the friendlier one.
///
/// [message] is for error tracking, in English, and never shown: the app
/// words what the user reads itself, in their language (ADR 0020), and
/// tells the two cases apart by [unreachable] — no answer at all, as against
/// an answer it cannot use.
class const ConfigException(
  final String message, {
  final bool unreachable = false,
}) implements Exception {
  @override
  String toString() => 'ConfigException: $message';
}
