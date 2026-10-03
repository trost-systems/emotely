import 'dart:async';
import 'dart:convert';

import 'package:agent_client/src/advance_response.dart';
import 'package:agent_client/src/agent_error_code.dart';
import 'package:contract/contract.dart';
import 'package:http/http.dart' as http;

/// The client's answer to the pending question: the tool call it answers
/// and the typed [Answer] the widget produced. Only its wire value is posted.
typedef SessionAnswer = ({String toolCallId, Answer answer});

/// The app's calls to the agent under the user's sign-in: one per session
/// round, and the one that revokes a Sign in with Apple grant before the
/// account is deleted, at `revoke-apple` beside [endpoint].
///
/// The session is stateless on the server; the caller echoes the signed
/// transcript it was handed last time.
class const AgentClient({
  required final http.Client httpClient,
  required final Uri endpoint,
  required final String appVersion,
  required final String? Function() accessToken,
  required final Future<void> Function() refreshAccessToken,
  final Duration timeout = defaultTimeout,
}) {
  /// A round is one model call; anything slower than this is a hung request
  /// and surfaces as a failure the user can retry.
  static const defaultTimeout = Duration(seconds: 30);

  /// Advances the session: no transcript starts one, a transcript plus the
  /// [answer] to its pending question continues it. Every request names the
  /// [appVersion] so the server can gate behavior per version, and carries
  /// the signed-in user's token from [accessToken]; without one the server
  /// refuses the round (ADR 0010).
  ///
  /// A token that lapsed is not the user's problem: when the agent answers
  /// [AgentErrorCode.unauthorized], the token is renewed with
  /// [refreshAccessToken] and the same round is sent once more. A renewal
  /// that cannot happen signs the user out through the auth stream, which
  /// is what takes them to sign-in; nothing here decides that.
  ///
  /// [userContext] tells the agent who the user is, on every round: the
  /// agent keeps nothing between rounds, and the context stays out of the
  /// signed transcript. Without one the agent knows no name.
  Future<AdvanceResponse> advance({
    List<Object?>? transcript,
    String? signature,
    SessionAnswer? answer,
    UserContext? userContext,
  }) async {
    final body = jsonEncode({
      'transcript': ?transcript,
      'signature': ?signature,
      if (answer != null)
        'answer': {
          'tool_call_id': answer.toolCallId,
          'value': answer.answer.wireValue,
        },
      'app_version': appVersion,
      'user_context': ?userContext?.toJson(),
    });
    final json = await _renewingOnce(() => _post(endpoint, body));
    return AdvanceResponse.fromJson(json);
  }

  /// Revokes the signed-in account's Sign in with Apple grant before the
  /// account is deleted (#193): Apple's sheet issued [authorizationCode]
  /// moments ago, and the agent trades it for a token and revokes that.
  /// Completes once the agent says it is revoked; anything else throws an
  /// [AgentException], whose code says whether the code was for another
  /// Apple ID or Apple could not be reached. A lapsed token is renewed and
  /// the code resent once, as for a round.
  Future<void> revokeApple({required String authorizationCode}) async {
    final body = jsonEncode({'authorization_code': authorizationCode});
    final json = await _renewingOnce(
      () => _post(endpoint.resolve('revoke-apple'), body),
    );
    if (json['status'] != 'revoked') {
      throw const AgentException(200, 'unexpected response');
    }
  }

  /// [send], and once more after renewing the token if the agent says it
  /// lapsed.
  Future<Map<String, dynamic>> _renewingOnce(
    Future<Map<String, dynamic>> Function() send,
  ) async {
    try {
      return await send();
    } on AgentException catch (error) {
      if (error.code != AgentErrorCode.unauthorized) {
        rethrow;
      }
      await refreshAccessToken();
      return await send();
    }
  }

  Future<Map<String, dynamic>> _post(Uri url, String body) async {
    final response = await httpClient
        .post(
          url,
          headers: {
            'content-type': 'application/json',
            if (accessToken() case final token?)
              'authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(timeout);
    // The server sends `application/json` without a charset, which
    // package:http would decode as Latin-1 — emoji answers must survive.
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw _refusal(response.statusCode, text);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  static AgentException _refusal(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body) as Object?;
      if (decoded case {
        'error': final String message,
        'code': final Object? code,
      }) {
        return AgentException(
          statusCode,
          message,
          code: AgentErrorCode.fromWire(code),
        );
      }
    } on FormatException {
      // Not JSON: an edge or gateway answered, not the agent.
    }
    return AgentException(statusCode, 'unexpected response');
  }
}

/// A non-200 answer from the agent. [code] is what the app acts on, null
/// when the answer did not come from the agent or names a code this build
/// does not know; [message] is the agent's English, for logs and error
/// reports only — never for a screen.
class const AgentException(
  final int statusCode,
  final String message, {
  final AgentErrorCode? code,
}) implements Exception {
  @override
  String toString() => 'AgentException($statusCode): $message';
}
