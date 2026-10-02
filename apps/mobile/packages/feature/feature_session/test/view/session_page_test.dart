import 'dart:async';

import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_session/src/view/session_page.dart';
import 'package:feature_session/src/widgets/longtext_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:testing/testing.dart';

import '../session_robot.dart';
import '../session_strings.dart';

void main() {
  group(SessionPage, () {
    testWidgets('shows a thinking state until the agent asks', (tester) async {
      final agent = AgentStub()
        ..script([
          delayed(awaiting(toolCallId: 'c1', question: SessionRobot.rate)),
        ]);
      final robot = SessionRobot(tester, agent);

      await robot.launch();

      expect(find.text(tester.strings.sessionTitle), findsOneWidget);
      expect(robot.thinking, findsOneWidget);
      expect(find.text(tester.strings.thinkingLabel), findsOneWidget);
      expect(agent.requests, hasLength(1));
      // Nothing is known about the user but the language on screen.
      expect(agent.lastRequest, {
        'app_version': AgentStub.appVersion,
        'user_context': {'name_is_placeholder': false, 'locale': 'de'},
      });
      // The round runs as the signed-in user (ADR 0010).
      expect(
        agent.lastHeaders['authorization'],
        'Bearer ${SupabaseStub.accessToken}',
      );

      await robot.settle();

      expect(robot.thinking, findsNothing);
      expect(find.text(tester.strings.questionNumber(1)), findsOneWidget);
      expect(robot.questionText, SessionRobot.rate.question);
      expect(robot.answerInput, findsOneWidget);
    });

    testWidgets('tells the agent who the user is on every round', (
      tester,
    ) async {
      const pebble = UserContext(
        displayName: 'Pebble',
        nameIsPlaceholder: true,
      );
      const maya = UserContext(displayName: 'Maya');
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          awaiting(toolCallId: 'c2', question: SessionRobot.best),
        ]);
      final robot = SessionRobot(tester, agent)..userContext.context = pebble;
      await robot.launch();
      await robot.settle();

      expect(agent.lastRequest['user_context'], {
        'display_name': 'Pebble',
        'name_is_placeholder': true,
        'locale': 'de',
      });

      // Renamed mid-session: the agent keeps nothing, so the next round
      // carries whatever the app knows by then.
      robot.userContext.context = maya;
      await robot.answerRating(7);

      expect(agent.lastRequest['user_context'], {
        'display_name': 'Maya',
        'name_is_placeholder': false,
        'locale': 'de',
      });
      expect(robot.userContext.asked, 2);
    });

    testWidgets('tells the agent the language the screen is in (#228)', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          awaiting(toolCallId: 'c2', question: SessionRobot.best),
        ]);
      final robot = SessionRobot(tester, agent, locale: const Locale('en'))
        ..userContext.context = const UserContext(displayName: 'Maya');
      await robot.launch();
      await robot.settle();

      expect(
        (agent.lastRequest['user_context']! as Map<String, dynamic>)['locale'],
        'en',
      );

      // Every round, so the companion never falls back to English mid-way.
      await robot.answerRating(7);

      expect(agent.lastRequest['user_context'], {
        'display_name': 'Maya',
        'name_is_placeholder': false,
        'locale': 'en',
      });
    });

    testWidgets('walks a whole session and shows the entry', (tester) async {
      const secondTranscript = <Object?>['round', 'round'];
      const secondSignature = 'sig-2';
      const rating = 7;
      const gratefulFor = ['my wife', 'Flutter'];
      const bestThing = 'Shipping the session screen.';
      const summary = 'A 7 kind of day, grateful for two things.';
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          awaiting(
            toolCallId: 'c2',
            question: SessionRobot.grateful,
            transcript: secondTranscript,
            signature: secondSignature,
          ),
          awaiting(toolCallId: 'c3', question: SessionRobot.best),
          completed(
            summary: summary,
            answers: {
              SessionRobot.rate.questionId: const Answer.rating(rating),
              SessionRobot.grateful.questionId: const Answer.textList(
                gratefulFor,
              ),
              SessionRobot.best.questionId: const Answer.longtext(bestThing),
            },
          ),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(rating);

      expect(robot.lastAnsweredToolCall, 'c1');
      expect(robot.lastPostedValue, rating);
      expect(agent.lastRequest['transcript'], AgentStub.transcript);
      expect(agent.lastRequest['signature'], AgentStub.signature);
      expect(find.text(tester.strings.questionNumber(2)), findsOneWidget);
      expect(robot.questionText, SessionRobot.grateful.question);

      await robot.answerTextList(gratefulFor);

      expect(robot.lastAnsweredToolCall, 'c2');
      expect(robot.lastPostedValue, gratefulFor);
      expect(agent.lastRequest['transcript'], secondTranscript);
      expect(agent.lastRequest['signature'], secondSignature);
      expect(find.text(tester.strings.questionNumber(3)), findsOneWidget);

      await robot.answerLongtext(bestThing);

      expect(robot.lastPostedValue, bestThing);
      expect(robot.summary, findsOneWidget);
      expect(find.text(summary), findsOneWidget);
      expect(find.text(SessionRobot.rate.question), findsOneWidget);
      expect(find.text('$rating / 10'), findsOneWidget);
      expect(
        find.text(gratefulFor.map((v) => '• $v').join('\n')),
        findsOneWidget,
      );
      expect(find.text(bestThing), findsOneWidget);
    });

    testWidgets('posts wire values, never Dart objects', (tester) async {
      // Colors are the one type whose Dart value is not its JSON value; the
      // request body must be encodable, and the agent must see #RRGGBB.
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.colors),
          awaiting(toolCallId: 'c2', question: SessionRobot.rate),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerColor(Colors.teal);

      expect(robot.lastPostedValue, ['#009688']);
      expect(robot.questionText, SessionRobot.rate.question);
    });

    testWidgets('a new question never inherits the previous draft', (
      tester,
    ) async {
      const draft = 'The best.';
      final worst = SessionRobot.best.copyWith(
        questionId: 'q-worst',
        question: 'And the worst?',
      );
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.best),
          awaiting(toolCallId: 'c2', question: worst),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerLongtext(draft);

      expect(robot.questionText, worst.question);
      expect(find.text(draft), findsNothing);
      expect(isSubmitEnabled(tester, LongtextInput.submitKey), isFalse);
    });

    testWidgets('an answer too long for the agent is never sent, and the '
        'shortened draft goes through', (tester) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.best),
          awaiting(toolCallId: 'c2', question: SessionRobot.rate),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.writeLongtext('a' * 4095);
      await robot.submitLongtext();

      expect(agent.requests, hasLength(1));
      expect(robot.questionText, SessionRobot.best.question);
      expect(find.text(tester.strings.answerLengthOver(1)), findsOneWidget);

      await robot.writeLongtext('a' * 4094);
      await robot.submitLongtext();

      expect(robot.lastPostedValue, 'a' * 4094);
      expect(robot.questionText, SessionRobot.rate.question);
    });

    testWidgets('words a refusal itself and retries the same round', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          refused(400, AgentErrorCode.answerMismatch),
          awaiting(toolCallId: 'c2', question: SessionRobot.grateful),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(5);

      expect(find.text(tester.strings.refusedMessage), findsOneWidget);
      expect(find.text(AgentErrorCode.answerMismatch.wire), findsNothing);
      expect(robot.retry, findsOneWidget);

      await robot.tapRetry();

      expect(agent.requests, hasLength(3));
      expect(agent.requests[2], agent.requests[1]);
      expect(robot.questionText, SessionRobot.grateful.question);
    });

    testWidgets('a network failure gets a generic message', (tester) async {
      final agent = AgentStub()..script([unreachable()]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      expect(find.text(tester.strings.unreachableMessage), findsOneWidget);
      expect(robot.retry, findsOneWidget);
    });

    testWidgets('a refused model says the companion is unavailable', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([refused(502, AgentErrorCode.modelUnavailable)]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      expect(find.text(tester.strings.modelUnavailableMessage), findsOneWidget);
      // Neither the server's wording nor the connection story the user would
      // otherwise act on: retrying now cannot work, and their entry is safe.
      expect(find.text(AgentErrorCode.modelUnavailable.wire), findsNothing);
      expect(find.text(tester.strings.unreachableMessage), findsNothing);
      // The round never completed, so the same round is still the retry.
      expect(
        find.descendant(
          of: robot.retry,
          matching: find.text(tester.strings.tryAgainButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a refused model mid-session keeps the entry and retries', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          refused(502, AgentErrorCode.modelUnavailable),
          awaiting(toolCallId: 'c2', question: SessionRobot.grateful),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      await robot.answerRating(5);

      expect(find.text(tester.strings.modelUnavailableMessage), findsOneWidget);

      // The failed round left nothing behind: the retry resends it verbatim,
      // and the session carries on from the answer the user already gave.
      await robot.tapRetry();

      expect(agent.requests, hasLength(3));
      expect(agent.requests[2], agent.requests[1]);
      expect(robot.questionText, SessionRobot.grateful.question);
    });

    testWidgets('a lapsed sign-in is renewed and the round goes through', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          refused(401, AgentErrorCode.unauthorized),
          awaiting(toolCallId: 'c1', question: SessionRobot.rate),
        ]);
      final supabase = SupabaseStub()..script(password: [sessionGranted()]);
      final robot = SessionRobot(tester, agent, supabase: supabase);
      await robot.launch();
      await robot.settle();

      final renewal = supabase.to('POST /auth/v1/token').single;
      expect(renewal.query['grant_type'], 'refresh_token');
      expect(agent.requests, hasLength(2));
      expect(robot.questionText, SessionRobot.rate.question);
      expect(robot.analytics.events, isNot(contains(event('session_failed'))));
    });

    testWidgets("a server error gets our own words, never the server's", (
      tester,
    ) async {
      const serverMessage = 'boom';
      final agent = AgentStub()..script([raw(serverMessage, 500)]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      expect(find.text(tester.strings.refusedMessage), findsOneWidget);
      expect(find.text(serverMessage), findsNothing);
      expect(find.text(tester.strings.modelUnavailableMessage), findsNothing);
      expect(robot.retry, findsOneWidget);
    });

    testWidgets('a hung round times out into the generic failure', (
      tester,
    ) async {
      final agent = AgentStub()
        ..script([
          delayed(
            awaiting(toolCallId: 'c1', question: SessionRobot.rate),
            AgentClient.defaultTimeout + const Duration(seconds: 1),
          ),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      expect(find.text(tester.strings.unreachableMessage), findsOneWidget);
      expect(robot.retry, findsOneWidget);

      // Let the stub's late response fire; the client already gave up on it.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders every answer type in the entry', (tester) async {
      const colors = [Color(0xFFFF8800), Color(0xFF00AAFF)];
      const emoji = ['😊', '🙏'];
      final agent = AgentStub()
        ..script([
          completed(
            summary: 'Colorful.',
            answers: const {
              'q-color': Answer.color(colors),
              'q-emoji': Answer.emoji(emoji),
            },
          ),
        ]);
      final robot = SessionRobot(tester, agent);
      await robot.launch();
      await robot.settle();

      // Questions the agent never asked in this (scripted) session fall back
      // to their id.
      expect(find.text('q-color'), findsOneWidget);
      expect(find.text(emoji.join(' ')), findsOneWidget);
      expect(find.byType(AnswerText), findsNWidgets(2));
      expect(find.bySemanticsLabel('#FF8800 #00AAFF'), findsOneWidget);
    });

    group('analytics', () {
      testWidgets('narrates the session with ids, types and counts only', (
        tester,
      ) async {
        final agent = AgentStub()
          ..script([
            awaiting(toolCallId: 'c1', question: SessionRobot.rate),
            awaiting(toolCallId: 'c2', question: SessionRobot.best),
            completed(
              summary: 'Done.',
              answers: const {
                'q-rate': Answer.rating(7),
                'q-best': Answer.longtext('Shipping.'),
              },
            ),
          ]);
        final robot = SessionRobot(tester, agent);
        await robot.launch();
        await robot.settle();
        await robot.answerRating(7);
        await robot.answerLongtext('Shipping.');

        expect(robot.analytics.events, [
          event('session_started'),
          event('question_asked', {
            'question_id': 'q-rate',
            'answer_type': 'rating',
            'index': 0,
          }),
          event('answer_submitted', {
            'question_id': 'q-rate',
            'answer_type': 'rating',
          }),
          event('question_asked', {
            'question_id': 'q-best',
            'answer_type': 'longtext',
            'index': 1,
          }),
          event('answer_submitted', {
            'question_id': 'q-best',
            'answer_type': 'longtext',
          }),
          event('session_completed', {'answers': 2}),
        ]);
      });

      testWidgets('never lets journal content leave the device', (
        tester,
      ) async {
        // Needles in every place content can appear: question text, the
        // typed answer, the agent's summary and the recorded answers — and
        // in every failure that quotes what it choked on: a body that is
        // not JSON, a Postgres error naming the failing row.
        const needle = 'NEEDLE';
        final agent = AgentStub()
          ..script([
            raw('<html>$needle</html>', 200),
            awaiting(
              toolCallId: 'c1',
              question: SessionRobot.best.copyWith(
                question: 'What was the $needle-best thing?',
              ),
            ),
            completed(
              summary: 'A $needle day.',
              answers: const {'q-best': Answer.longtext('$needle answer')},
            ),
          ]);
        final supabase = SupabaseStub()
          ..rest('POST /rest/v1/sessions', [
            restRefused(message: 'Failing row contains ($needle answer)'),
          ])
          ..rest('POST /rest/v1/rpc/complete_session', [
            restRefused(message: 'Failing row contains (A $needle day.)'),
          ]);
        final robot = SessionRobot(tester, agent, supabase: supabase);
        await robot.launch();
        await robot.settle();
        await robot.tapRetry();
        await robot.answerLongtext('$needle answer');
        await robot.tapRetry();

        expect(robot.summary, findsOneWidget);
        // session_started, session_failed, session_retried, question_asked,
        // session_save_failed, answer_submitted, entry_save_failed,
        // session_retried, session_completed: the whole story, none of it
        // content.
        expect(robot.analytics.events, hasLength(9));
        expect(robot.analytics.exceptions, [
          captured(withheld(FormatException), {'step': 'session_round'}),
          captured(
            withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
            {'step': 'session_save'},
          ),
          captured(
            withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
            {'step': 'entry_save', 'session_id': SupabaseStub.sessionId},
          ),
        ]);
        final outgoing = robot.analytics.outgoingStrings.toList();
        expect(outgoing, isNotEmpty);
        for (final leaving in outgoing) {
          expect(leaving, isNot(contains(needle)));
        }
      });

      testWidgets('reports failures with the status code and retries', (
        tester,
      ) async {
        final agent = AgentStub()
          ..script([
            raw('rate limited', 429),
            unreachable(),
            awaiting(toolCallId: 'c1', question: SessionRobot.rate),
          ]);
        final robot = SessionRobot(tester, agent);
        await robot.launch();
        await robot.settle();
        await robot.tapRetry();
        await robot.tapRetry();

        expect(robot.analytics.events, [
          event('session_started'),
          event('session_failed', {'status_code': 429}),
          event('session_retried'),
          event('session_failed'),
          event('session_retried'),
          event('question_asked', {
            'question_id': 'q-rate',
            'answer_type': 'rating',
            'index': 0,
          }),
        ]);
        // The counting events say how often; the exceptions say why: the
        // server's refusal with its status, then the transport error.
        expect(robot.analytics.exceptions, [
          captured(
            isA<AgentException>()
                .having((error) => error.statusCode, 'statusCode', 429)
                .having(
                  (error) => error.message,
                  'message',
                  'unexpected response',
                ),
            {'step': 'session_round', 'status_code': 429},
          ),
          captured(
            isA<http.ClientException>().having(
              (error) => error.message,
              'message',
              'Connection refused',
            ),
            {'step': 'session_round'},
          ),
        ]);
      });

      testWidgets('reports a refused model under its own status code', (
        tester,
      ) async {
        final agent = AgentStub()
          ..script([refused(502, AgentErrorCode.modelUnavailable)]);
        final robot = SessionRobot(tester, agent);
        await robot.launch();
        await robot.settle();

        // Replacing the copy the user reads changes nothing we count: the
        // status still travels, so a refused model is still one alarm.
        expect(robot.analytics.events, [
          event('session_started'),
          event('session_failed', {'status_code': 502}),
        ]);
        expect(robot.analytics.exceptions, [
          captured(
            isA<AgentException>()
                .having((error) => error.statusCode, 'statusCode', 502)
                .having(
                  (error) => error.message,
                  'message',
                  AgentErrorCode.modelUnavailable.wire,
                ),
            {'step': 'session_round', 'status_code': 502},
          ),
        ]);
      });

      testWidgets('reports a hung round as the timeout it hit', (tester) async {
        final agent = AgentStub()
          ..script([
            delayed(
              awaiting(toolCallId: 'c1', question: SessionRobot.rate),
              AgentClient.defaultTimeout + const Duration(seconds: 1),
            ),
          ]);
        final robot = SessionRobot(tester, agent);
        await robot.launch();
        await robot.settle();

        expect(robot.analytics.exceptions, [
          captured(isA<TimeoutException>(), {'step': 'session_round'}),
        ]);

        await tester.pump(const Duration(seconds: 2));
      });

      testWidgets('still reports a round that fails after the session was '
          'left', (tester) async {
        // The bloc is closed while the round is in flight; the failure that
        // lands afterwards has nowhere to be shown, but it did happen.
        final agent = AgentStub()..script([delayed(unreachable())]);
        final robot = SessionRobot(tester, agent);
        await robot.launch();

        expect(robot.thinking, findsOneWidget);

        // Leaving the page closes its bloc while the round is in flight.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();

        expect(robot.analytics.exceptions, isEmpty);

        // Nothing animates on the journal, so run the clock past the round.
        await tester.pump(const Duration(seconds: 2));

        expect(robot.analytics.exceptions, [
          captured(isA<http.ClientException>(), {'step': 'session_round'}),
        ]);
        expect(robot.analytics.events.last, event('session_failed'));
        expect(tester.takeException(), isNull);
      });
    });

    group('resuming a stored session', () {
      const pending = PendingQuestion(toolCallId: 'c1', question: rateQuestion);

      /// A journal holding one unfinished session; the page reads it back
      /// itself, since a route carries no more than the wish to resume.
      SupabaseStub storing({PendingQuestion? pending}) =>
          SupabaseStub()..rest('GET /rest/v1/sessions', [
            rows([
              sessionRow(questions: [rateQuestion], pending: pending),
            ]),
          ]);
      final finished = completed(
        summary: 'Done.',
        answers: const {'q-rate': Answer.rating(7)},
      );

      testWidgets('puts the pending question back without a server round', (
        tester,
      ) async {
        final agent = AgentStub()..script([finished]);
        final robot = SessionRobot(
          tester,
          agent,
          supabase: storing(pending: pending),
          resume: SupabaseStub.sessionId,
        );
        await robot.launch();
        await robot.settle();

        expect(robot.questionText, rateQuestion.question);
        expect(find.text(tester.strings.questionNumber(1)), findsOneWidget);
        expect(agent.requests, isEmpty);
        expect(robot.analytics.events, [event('session_resumed')]);

        await robot.answerRating(7);

        // The stored transcript and signature are what the round echoes.
        expect(agent.lastRequest['transcript'], ['stored']);
        expect(agent.lastRequest['signature'], 'stored-sig');
        expect(robot.lastAnsweredToolCall, 'c1');
        expect(robot.summary, findsOneWidget);
      });

      testWidgets('a session saved without its pending question is finished '
          'by the agent', (tester) async {
        final agent = AgentStub()..script([finished]);
        final robot = SessionRobot(
          tester,
          agent,
          supabase: storing(),
          resume: SupabaseStub.sessionId,
        );
        await robot.launch();
        await robot.settle();

        expect(agent.requests, hasLength(1));
        expect(agent.lastRequest['transcript'], ['stored']);
        expect(agent.lastRequest, isNot(contains('answer')));
        expect(robot.summary, findsOneWidget);
      });

      testWidgets('starts afresh when nothing is stored any more', (
        tester,
      ) async {
        // The journal offered to continue, but the session was discarded
        // elsewhere in the meantime: the server is asked, not the offer.
        final agent = AgentStub()
          ..script([awaiting(toolCallId: 'c1', question: SessionRobot.rate)]);
        final robot = SessionRobot(tester, agent, resume: 's-gone');
        await robot.launch();
        await robot.settle();

        expect(agent.requests, hasLength(1));
        expect(agent.lastRequest, isNot(contains('transcript')));
        expect(robot.questionText, SessionRobot.rate.question);
        expect(robot.analytics.events.first, event('session_started'));
      });

      testWidgets('a stored session the agent no longer accepts starts over '
          'instead of retrying', (tester) async {
        final agent = AgentStub()
          ..script([
            refused(401, AgentErrorCode.invalidSignature),
            awaiting(toolCallId: 'c9', question: SessionRobot.grateful),
          ]);
        final robot = SessionRobot(
          tester,
          agent,
          supabase: storing(pending: pending),
          resume: SupabaseStub.sessionId,
        );
        await robot.launch();
        await robot.settle();
        await robot.answerRating(7);

        expect(find.text(tester.strings.cannotContinueMessage), findsOneWidget);
        expect(find.textContaining('signature'), findsNothing);
        // Resending the same transcript can never succeed.
        expect(robot.retry, findsNothing);
        expect(
          find.descendant(
            of: robot.startOver,
            matching: find.text(tester.strings.startOverButton),
          ),
          findsOneWidget,
        );

        await robot.tapStartOver();

        // A fresh session: no transcript, and its first save replaces the
        // stored one the agent refused.
        expect(agent.lastRequest, isNot(contains('transcript')));
        final replaced = robot.supabaseStub.to('DELETE /rest/v1/sessions');
        expect(replaced.single.query['status'], 'eq.in_progress');
        expect(robot.supabaseStub.to('POST /rest/v1/sessions'), hasLength(1));
        expect(robot.questionText, SessionRobot.grateful.question);
        expect(find.text(tester.strings.questionNumber(1)), findsOneWidget);
      });

      testWidgets('says so when the stored session cannot be read, and '
          'retries', (tester) async {
        final agent = AgentStub()..script([finished]);
        final supabase = SupabaseStub()
          ..rest('GET /rest/v1/sessions', [
            restRefused(),
            rows([
              sessionRow(questions: [rateQuestion], pending: pending),
            ]),
          ]);
        final robot = SessionRobot(
          tester,
          agent,
          supabase: supabase,
          resume: SupabaseStub.sessionId,
        );
        await robot.launch();
        await robot.settle();

        expect(
          find.text(tester.strings.sessionReadFailedMessage),
          findsOneWidget,
        );
        expect(agent.requests, isEmpty);
        expect(robot.analytics.exceptions, hasLength(1));

        await robot.tapRetry();

        expect(robot.questionText, rateQuestion.question);
        expect(agent.requests, isEmpty);
      });
    });

    group('meets accessibility guidelines', () {
      testWidgets('while asking', (tester) async {
        final agent = AgentStub()
          ..script([awaiting(toolCallId: 'c1', question: SessionRobot.rate)]);

        final robot = SessionRobot(tester, agent);
        await tester.expectMeetsAccessibilityGuidelines(
          robot.app,
          prepare: (tester) => robot.settle(),
        );
      });

      testWidgets('on the entry', (tester) async {
        final agent = AgentStub()
          ..script([
            completed(
              summary: 'Done.',
              answers: const {'q-rate': Answer.rating(9)},
            ),
          ]);

        final robot = SessionRobot(tester, agent);
        await tester.expectMeetsAccessibilityGuidelines(
          robot.app,
          prepare: (tester) => robot.settle(),
        );
      });

      testWidgets('on failure', (tester) async {
        final agent = AgentStub()..script([raw('boom', 500)]);

        final robot = SessionRobot(tester, agent);
        await tester.expectMeetsAccessibilityGuidelines(
          robot.app,
          prepare: (tester) => robot.settle(),
        );
      });

      testWidgets('when the session cannot continue', (tester) async {
        final agent = AgentStub()
          ..script([refused(401, AgentErrorCode.invalidSignature)]);

        final robot = SessionRobot(tester, agent);
        await tester.expectMeetsAccessibilityGuidelines(
          robot.app,
          prepare: (tester) => robot.settle(),
        );
      });
    });
  });
}
