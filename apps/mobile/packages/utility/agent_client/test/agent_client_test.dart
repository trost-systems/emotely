import 'dart:async';
import 'dart:convert';

import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:testing/testing.dart';

void main() {
  group(AgentClient, () {
    const question = AskQuestion(
      questionId: 'q-rate',
      question: 'How was your day?',
      answerType: AnswerType.rating,
    );
    const toolCallId = 'c1';
    const rating = Answer.rating(7);

    test('starts a session with nothing but the app version', () async {
      final stub = AgentStub()
        ..script([awaiting(toolCallId: toolCallId, question: question)]);

      final response = await stub.agentClient.advance();

      expect(stub.lastRequest, {'app_version': AgentStub.appVersion});
      expect(
        response,
        const AdvanceResponse.awaitingAnswer(
          transcript: AgentStub.transcript,
          signature: AgentStub.signature,
          promptId: 'session/v1',
          pending: PendingQuestion(toolCallId: toolCallId, question: question),
        ),
      );
    });

    test('echoes the transcript and signature with the wire answer', () async {
      const summary = 'A good day.';
      final stub = AgentStub()
        ..script([
          completed(summary: summary, answers: const {'q-rate': rating}),
        ]);

      final response = await stub.agentClient.advance(
        transcript: AgentStub.transcript,
        signature: AgentStub.signature,
        answer: (toolCallId: toolCallId, answer: rating),
      );

      expect(stub.lastRequest, {
        'transcript': AgentStub.transcript,
        'signature': AgentStub.signature,
        'answer': {'tool_call_id': toolCallId, 'value': rating.wireValue},
        'app_version': AgentStub.appVersion,
      });
      expect(
        response,
        const AdvanceResponse.completed(
          transcript: ['round', 'round'],
          signature: 'final',
          promptId: 'session/v1',
          entry: JournalEntry(summary: summary, answers: {'q-rate': rating}),
        ),
      );
    });

    test('tells the agent who the user is when it knows', () async {
      final stub = AgentStub()
        ..script([awaiting(toolCallId: toolCallId, question: question)]);

      await stub.agentClient.advance(
        userContext: const UserContext(
          displayName: 'Pebble',
          nameIsPlaceholder: true,
        ),
      );

      expect(stub.lastRequest, {
        'app_version': AgentStub.appVersion,
        'user_context': {'display_name': 'Pebble', 'name_is_placeholder': true},
      });
    });

    test('posts JSON to the endpoint', () async {
      final stub = AgentStub()
        ..script([awaiting(toolCallId: toolCallId, question: question)]);

      await stub.agentClient.advance();

      verify(
        stub.client.post(
          AgentStub.endpoint,
          headers: {'content-type': 'application/json'},
          body: anyNamed('body'),
        ),
      ).called(1);
    });

    test("sends the signed-in user's token as a bearer header", () async {
      final stub = AgentStub()
        ..accessToken = (() => 'jwt-123')
        ..script([awaiting(toolCallId: toolCallId, question: question)]);

      await stub.agentClient.advance();

      expect(stub.lastHeaders['authorization'], 'Bearer jwt-123');
    });

    test('surfaces the code of a refusal, and its message for logs', () async {
      final stub = AgentStub()
        ..script([refused(401, AgentErrorCode.invalidSignature)]);

      await expectLater(
        stub.agentClient.advance(),
        throwsA(
          isA<AgentException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', AgentErrorCode.invalidSignature)
              .having(
                (e) => e.toString(),
                'toString',
                'AgentException(401): invalid_signature',
              ),
        ),
      );
    });

    test('renews the sign-in once and resends when it has lapsed', () async {
      var token = 'expired';
      final stub = AgentStub()
        ..accessToken = (() => token)
        ..refreshAccessToken = (() => Future.sync(() => token = 'renewed'))
        ..script([
          refused(401, AgentErrorCode.unauthorized),
          awaiting(toolCallId: toolCallId, question: question),
        ]);

      final response = await stub.agentClient.advance(
        transcript: AgentStub.transcript,
        signature: AgentStub.signature,
      );

      expect(response, isA<AwaitingAnswer>());
      expect(stub.headers.map((h) => h['authorization']), [
        'Bearer expired',
        'Bearer renewed',
      ]);
      expect(stub.requests[1], stub.requests[0]);
    });

    test('gives up when the renewed sign-in is refused too', () async {
      var renewals = 0;
      final stub = AgentStub()
        ..refreshAccessToken = (() => Future.sync(() => renewals++))
        ..script([
          refused(401, AgentErrorCode.unauthorized),
          refused(401, AgentErrorCode.unauthorized),
        ]);

      await expectLater(
        stub.agentClient.advance(),
        throwsA(
          isA<AgentException>().having(
            (e) => e.code,
            'code',
            AgentErrorCode.unauthorized,
          ),
        ),
      );
      expect(renewals, 1);
      expect(stub.requests, hasLength(2));
    });

    test(
      'renews nothing for a refusal that is not about the sign-in',
      () async {
        var renewals = 0;
        final stub = AgentStub()
          ..refreshAccessToken = (() => Future.sync(() => renewals++))
          ..script([refused(401, AgentErrorCode.invalidSignature)]);

        await expectLater(
          stub.agentClient.advance(),
          throwsA(isA<AgentException>()),
        );
        expect(renewals, 0);
        expect(stub.requests, hasLength(1));
      },
    );

    test(
      'has no code when the error is not the envelope or the code is new',
      () async {
        final stub = AgentStub()
          ..script([
            raw('<html>Bad Gateway</html>', 502),
            raw(jsonEncode({'detail': 'nope'}), 500),
            raw(jsonEncode({'code': 'added_later', 'error': 'new'}), 400),
          ]);

        for (final status in [502, 500, 400]) {
          await expectLater(
            stub.agentClient.advance(),
            throwsA(
              isA<AgentException>()
                  .having((e) => e.statusCode, 'statusCode', status)
                  .having((e) => e.code, 'code', isNull)
                  .having((e) => e.toString(), 'toString', contains('$status')),
            ),
          );
        }
      },
    );

    test('gives up on a round that exceeds the timeout', () async {
      final stub = AgentStub()
        ..script([
          delayed(
            awaiting(toolCallId: toolCallId, question: question),
            const Duration(milliseconds: 50),
          ),
        ]);
      final client = AgentClient(
        httpClient: stub.client,
        endpoint: AgentStub.endpoint,
        appVersion: AgentStub.appVersion,
        accessToken: () => null,
        refreshAccessToken: Future.value,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(client.advance(), throwsA(isA<TimeoutException>()));
    });
  });
}
