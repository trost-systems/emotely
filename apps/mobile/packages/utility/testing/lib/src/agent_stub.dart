import 'dart:convert';

import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:testing/testing.dart';

/// One scripted server round.
typedef Round = Future<http.Response> Function();

/// The agent, scripted at the http seam: canned rounds go out in order,
/// every request body and header set is recorded for assertions.
class AgentStub() {
  final client = MockClient();
  final requests = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];
  final _rounds = <Round>[];

  /// The token the client attaches; the app harness points this at the
  /// Supabase session, a bare stub sends none.
  String? Function() accessToken = () => null;

  /// How the client renews a lapsed token; the app harness points this at
  /// the Supabase session, a bare stub renews nothing.
  Future<void> Function() refreshAccessToken = Future.value;

  /// The endpoint the stub answers on; any URL works, it never leaves the
  /// process.
  static final Uri endpoint = Uri.parse(
    'https://agent.test/api/advance-session',
  );

  /// Where the client revokes a Sign in with Apple grant: beside
  /// [endpoint], as on the real agent (#193).
  static final Uri revokeAppleEndpoint = Uri.parse(
    'https://agent.test/api/revoke-apple',
  );

  /// The transcript and signature every round hands out unless overridden.
  static const transcript = <Object?>['round'];
  static const signature = 'sig';
  static const appVersion = '1.2.3';

  /// An [AgentClient] talking to this stub.
  AgentClient get agentClient => AgentClient(
    httpClient: client,
    endpoint: endpoint,
    appVersion: appVersion,
    accessToken: () => accessToken(),
    refreshAccessToken: () => refreshAccessToken(),
  );

  /// The last request body, decoded.
  Map<String, dynamic> get lastRequest => requests.last;

  /// The headers of the last request.
  Map<String, String> get lastHeaders => headers.last;

  /// Queues the next rounds, served first-in first-out.
  void script(List<Round> rounds) {
    _rounds.addAll(rounds);
    when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((invocation) {
          requests.add(
            jsonDecode(invocation.namedArguments[#body] as String)
                as Map<String, dynamic>,
          );
          headers.add(
            (invocation.namedArguments[#headers] as Map<String, String>?) ??
                const {},
          );
          if (_rounds.isEmpty) {
            throw StateError('agent stub script exhausted');
          }
          return _rounds.removeAt(0)();
        });
  }
}

/// The agent asks [question]; the transcript and signature are what the
/// client must echo on the next round.
Round awaiting({
  required String toolCallId,
  required AskQuestion question,
  String signature = AgentStub.signature,
  List<Object?> transcript = AgentStub.transcript,
}) =>
    () async => _json({
      'status': 'awaiting_answer',
      'transcript': transcript,
      'signature': signature,
      'prompt_id': 'session/v1',
      'pending': {'tool_call_id': toolCallId, 'question': question.toJson()},
    });

/// The agent finished with [summary] and the recorded [answers].
Round completed({
  required String summary,
  required Map<String, Answer> answers,
}) =>
    () async => _json({
      'status': 'completed',
      'transcript': const ['round', 'round'],
      'signature': 'final',
      'prompt_id': 'session/v1',
      'entry': {
        'summary': summary,
        'answers': answers.map((id, answer) => MapEntry(id, answer.toJson())),
      },
    });

/// The agent revoked the Sign in with Apple grant (#193).
Round revoked() =>
    () async => _json({'status': 'revoked'});

/// The agent refused the round with [statusCode] and [code], the way it
/// does: the code to act on, English beside it for logs.
Round refused(int statusCode, AgentErrorCode code) =>
    () async => _response({'code': code.wire, 'error': code.wire}, statusCode);

/// A raw server response, for bodies that are not the JSON envelope.
Round raw(String body, int statusCode) =>
    () async => http.Response.bytes(utf8.encode(body), statusCode);

/// The network failed before any response.
Round unreachable() =>
    () async => throw http.ClientException('Connection refused');

/// [round], but only after [delay] — long enough to observe the in-flight
/// state before `pumpAndSettle` runs the clock forward.
Round delayed(Round round, [Duration delay = const Duration(seconds: 1)]) =>
    () => Future<http.Response>.delayed(delay, round);

http.Response _json(Map<String, Object?> body) => _response(body, 200);

// Mirrors the server: `application/json` with no charset, UTF-8 bytes.
http.Response _response(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
