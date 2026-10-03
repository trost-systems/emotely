import 'dart:convert';

import 'package:contract/contract.dart';
import 'package:http/http.dart' as http;
import 'package:testing/testing.dart';

/// Supabase, the agent and its config endpoint, in the process, over the
/// seeded journal: what the performance run talks to instead of the network.
///
/// It answers from memory at once, so the frames measure the app and not a
/// connection, and every request the app makes is recorded, so each path's
/// request count is exact. The journal is made up (ADR 0005: the run's
/// evidence is public).
class FakeBackend(
  /// The seeded journal, newest first, as the data API returns it.
  final List<Map<String, Object?>> entries,
) extends http.BaseClient {
  /// A journal of [count] made-up entries, one a day back from a fixed
  /// date, each with a rating and a text list, like a real session files.
  factory seeded({int count = 300}) => FakeBackend([
    for (var day = 0; day < count; day++)
      entryRow(
        id: '30000000-0000-0000-0000-${(day + 1).toString().padLeft(12, '0')}',
        summary:
            'Made-up day $day: a calm morning, a long walk and an early '
            'night. Nothing here is anyone’s journal.',
        createdAt: DateTime.utc(2026, 9, 20).subtract(Duration(days: day)),
        answers: {
          rateQuestion.questionId: Answer.rating(day % 10 + 1),
          gratefulQuestion.questionId: const Answer.textList([
            'made-up tea',
            'made-up friend',
          ]),
        },
        questions: const [rateQuestion, gratefulQuestion],
      ),
  ]);

  /// Where the agent's endpoints live; any host works, nothing leaves the
  /// process.
  static final Uri agentUrl = Uri.parse(
    'https://agent.perf.test/api/advance-session',
  );
  static final Uri configUrl = Uri.parse('https://agent.perf.test/api/config');
  static const supabaseUrl = 'https://project.perf.test';

  /// The newest entry: first in the list, and the one the run opens.
  String get firstId => entries.first['id']! as String;

  /// Every request the app made, as `service METHOD /path`, in order.
  final requests = <String>[];

  var _round = 0;

  /// Whether the user's consent stands, as `consent_stands` answers.
  var _consent = true;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final service = switch (request.url.path) {
      '/api/advance-session' => 'agent',
      '/api/config' => 'config',
      _ => 'supabase',
    };
    requests.add('$service ${request.method} ${request.url.path}');
    final (status, body) = _answer(request);
    final bytes = body == null ? <int>[] : utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      headers: {
        'content-type': 'application/json',
        if (request.method == 'HEAD') 'content-range': '*/${entries.length}',
      },
      request: request,
    );
  }

  (int, Object?) _answer(http.BaseRequest request) =>
      switch ((request.method, request.url.path)) {
        ('GET', '/api/config') => (
          200,
          {'min_app_version': '1.0.0', 'store_url': 'https://store.test'},
        ),
        ('POST', '/api/advance-session') => (200, _nextRound()),
        ('GET', '/rest/v1/entries') => (200, _entries(request.url)),
        ('HEAD', '/rest/v1/entries') => (200, null),
        ('GET', '/rest/v1/sessions') => (200, const <Object?>[]),
        ('POST', '/rest/v1/sessions') => (201, {'id': SupabaseStub.sessionId}),
        ('DELETE' || 'PATCH', '/rest/v1/sessions') => (204, null),
        // Both consents stand, the journal's and usage analytics' (#204),
        // until the survey's walk withdraws and gives them again.
        ('POST', '/rest/v1/rpc/consent_stands') => (200, _consent),
        // The name the journal greets by and a session hands the agent.
        ('GET', '/rest/v1/profiles') => (200, [profileRow(displayName: 'Sam')]),
        // Withdrawing and giving consent again, and signing out and asking
        // for a reset code: the survey's walk (survey_test.dart) reaches
        // every screen, and these are how it gets to the last two.
        ('GET', '/rest/v1/consent_events') => (200, const <Object?>[]),
        ('POST', '/rest/v1/rpc/withdraw_consent') => _consentNow(false),
        ('POST', '/rest/v1/rpc/record_consent') => _consentNow(true),
        ('POST', '/auth/v1/logout') => (204, null),
        ('POST', '/auth/v1/recover') => (200, const <String, Object?>{}),
        (final method, final path) => throw StateError(
          'fake backend: nothing answers $method $path',
        ),
      };

  /// Records whether consent stands, and answers as the functions do.
  (int, Object?) _consentNow(bool stands) {
    _consent = stands;
    return (204, null);
  }

  /// The whole journal, or the one entry a `id=eq.<id>` filter names.
  List<Map<String, Object?>> _entries(Uri url) {
    final id = url.queryParameters['id']?.replaceFirst('eq.', '');
    return id == null ? entries : [...entries.where((row) => row['id'] == id)];
  }

  /// The agent asks a rating question every round, a new one each time.
  Map<String, Object?> _nextRound() {
    _round++;
    return {
      'status': 'awaiting_answer',
      'transcript': [for (var i = 0; i < _round; i++) 'round'],
      'signature': 'sig-$_round',
      'prompt_id': 'session/v1',
      'pending': {
        'tool_call_id': 'call-$_round',
        'question': AskQuestion(
          questionId: 'q-rate-$_round',
          question: 'How would you rate made-up day $_round?',
          answerType: AnswerType.rating,
        ).toJson(),
      },
    };
  }
}
