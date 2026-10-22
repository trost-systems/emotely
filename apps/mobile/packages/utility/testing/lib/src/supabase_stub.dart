import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:testing/src/consent_rounds.dart';
import 'package:testing/src/mocks.mocks.dart';

/// One scripted Supabase Auth response.
typedef AuthRound = Future<http.Response> Function();

/// Supabase, scripted at the http seam like the agent: canned responses per
/// auth endpoint, every request recorded. The [SupabaseClient] it hands out
/// is the real SDK, so session handling, token exposure and auth events are
/// the production code paths.
class SupabaseStub() {
  this {
    // Auth posts through the client's verb methods ...
    when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer(
          (invocation) => _serve(
            'POST',
            invocation.positionalArguments.first as Uri,
            invocation.namedArguments[#body],
          ),
        );
    // `updateUser` (an email change) puts through the same seam.
    when(client.put(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer(
          (invocation) => _serve(
            'PUT',
            invocation.positionalArguments.first as Uri,
            invocation.namedArguments[#body],
          ),
        );
    // ... while the data API (postgrest) builds a request and sends it.
    when(client.send(any)).thenAnswer((invocation) async {
      final request = invocation.positionalArguments.first as http.BaseRequest;
      final response = await _serve(
        request.method,
        request.url,
        request is http.Request ? request.body : null,
      );
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    });
    // Every sign-in through the screen may keep the app's language on the
    // account (the sign-in mail's language), so a test that is not about
    // it needs no round for it: GoTrue merges `data` into the signed-in
    // user's metadata and answers with the user as it now stands.
    always(updateUserEndpoint, () async {
      final user = supabase.auth.currentUser!;
      final data = (requests.last.body! as Map<String, dynamic>)['data'];
      return _json({
        ...user.toJson(),
        'user_metadata': {...user.userMetadata, ...?data as Map?},
      }, 200);
    });
  }

  /// `updateUser`: an email change, or the account's metadata.
  static const updateUserEndpoint = 'PUT /auth/v1/user';

  Future<http.Response> _serve(String method, Uri uri, Object? raw) {
    final request = RecordedRequest(
      method: method,
      path: uri.path,
      query: uri.queryParameters,
      // A parameterless RPC is posted as the JSON literal `null`.
      body: raw is String && raw.isNotEmpty ? jsonDecode(raw) as Object? : null,
    );
    requests.add(request);
    final key = request.endpoint;
    final queue = _rounds[key];
    if (queue != null && queue.isNotEmpty) {
      return queue.removeAt(0)();
    }
    final fallback = _defaults[key];
    if (fallback == null) {
      throw StateError('supabase stub: nothing scripted for $key');
    }
    return fallback();
  }

  final client = MockClient();

  /// Every request the SDK made: method, path, query and decoded body.
  final requests = <RecordedRequest>[];
  final _rounds = <String, List<AuthRound>>{};
  final _defaults = <String, AuthRound>{};

  static const url = 'https://project.supabase.test';
  static const publishableKey = 'sb_publishable_test';
  static const userId = '00000000-0000-0000-0000-00000000000a';
  static const email = 'alice@example.com';
  static const sessionId = '20000000-0000-0000-0000-000000000001';
  static const entryId = '30000000-0000-0000-0000-000000000001';

  /// The token the app must forward to the agent once signed in.
  static final accessToken = jwt(sub: userId);

  /// The real client, talking to this stub; no persistence, no refresh
  /// timer, no deep links.
  late final supabase = SupabaseClient(
    url,
    publishableKey,
    httpClient: client,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );

  /// Queues auth responses per endpoint, served first-in first-out.
  void script({
    List<AuthRound> otp = const [],
    List<AuthRound> verify = const [],
    List<AuthRound> password = const [],
    List<AuthRound> idToken = const [],
    List<AuthRound> logout = const [],
  }) {
    rest('POST /auth/v1/otp', otp);
    rest('POST /auth/v1/verify', verify);
    // The password grant posts to `/token?grant_type=password`; the query
    // is recorded on the request, not part of the key.
    rest('POST /auth/v1/token', password);
    // So does the ID-token grant (Google, Apple), as `grant_type=id_token`.
    rest('POST /auth/v1/token', idToken);
    rest('POST /auth/v1/logout', logout);
  }

  /// Queues responses for one `METHOD /path`, e.g. `POST /rest/v1/sessions`;
  /// scripted rounds are served before any [always] fallback.
  void rest(String endpoint, List<AuthRound> rounds) =>
      _rounds.putIfAbsent(endpoint, () => []).addAll(rounds);

  /// Answers every unscripted request to [endpoint] with [round].
  void always(String endpoint, AuthRound round) => _defaults[endpoint] = round;

  /// Answers [endpoint] with [round] only if the test has not already said
  /// what it should answer. Used by [journalWorks], which runs from
  /// `appUnderTest` — i.e. *after* the test has set its own stubs up — so a
  /// plain [always] there would silently overwrite them.
  void unless(String endpoint, AuthRound round) =>
      _defaults.putIfAbsent(endpoint, () => round);

  /// A journal that accepts everything: sessions are created as [sessionId],
  /// updated and closed without complaint. What most session tests want.
  ///
  /// Consent stands by default, so a test about sessions is about sessions.
  /// Every default here yields to whatever the test set first, so the tests
  /// that *are* about the gate (`test/consent/`) simply say so.
  void journalWorks({String sessionId = SupabaseStub.sessionId}) {
    unless('GET /rest/v1/entries', rows(const []));
    // The milestone count after an entry is filed; a test that cares about
    // `third_entry_written` scripts the number it wants instead.
    unless('HEAD /rest/v1/entries', rowsCounted(1));
    unless('GET /rest/v1/sessions', rows(const []));
    unless('DELETE /rest/v1/sessions', rowsChanged());
    unless('POST /rest/v1/sessions', rowCreated(sessionId));
    unless('PATCH /rest/v1/sessions', rowsChanged());
    unless('POST /rest/v1/rpc/complete_session', rpcReturned(entryId));
    unless('POST /rest/v1/rpc/consent_stands', rpcReturned(true));
    unless('POST /rest/v1/rpc/record_consent', rpcReturned(null));
    unless('POST /rest/v1/rpc/withdraw_consent', rpcReturned(null));
    // When consent was given is read only where it is shown, and is left
    // out when there is none to read.
    unless('GET /rest/v1/consent_events', rows(const []));
    // The usage-analytics record agrees with the device (allowed, the
    // spy's default), so signing in writes nothing unless a test says so.
    unless(usageAnalyticsRead, rpcReturned(true));
    unless(usageAnalyticsGrant, rpcReturned(null));
    unless(usageAnalyticsWithdraw, rpcReturned(null));
    // No profile yet, and a save that goes through: a test about the name
    // scripts the row it wants.
    unless('GET /rest/v1/profiles', rows(const []));
    unless('POST /rest/v1/profiles', rowsChanged());
  }

  /// Starts the client with a live session, as after a restored sign-in,
  /// for an account that signs in through [provider] (`email`, `google`,
  /// `apple`; none says nothing about it). [providers] are every way in
  /// linked to the account, [provider] alone unless given.
  Future<void> signedIn({
    String email = SupabaseStub.email,
    String? provider,
    List<String>? providers,
  }) => supabase.auth.recoverSession(
    jsonEncode(session(email: email, provider: provider, providers: providers)),
  );

  /// The requests the app made to `METHOD /path`, in order.
  List<RecordedRequest> to(String endpoint) => [
    for (final request in requests)
      if (request.endpoint == endpoint) request,
  ];

  /// The JSON object bodies the app posted to [path], in order.
  List<Map<String, dynamic>> bodies(String path) => [
    for (final request in requests)
      if (request.path == path && request.body is Map<String, dynamic>)
        request.body! as Map<String, dynamic>,
  ];

  /// A session as Supabase Auth returns it after a verified code; the
  /// account's [provider] is recorded in `app_metadata` the way Supabase
  /// records the provider an account was created with, [providers] every
  /// one linked to it since ([provider] alone unless given), and
  /// [userMetadata] is what the account keeps about itself
  /// (`user_metadata`).
  static Map<String, Object?> session({
    String sub = userId,
    String email = SupabaseStub.email,
    String? provider,
    List<String>? providers,
    Map<String, Object?> userMetadata = const {},
  }) => {
    'access_token': jwt(sub: sub),
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'refresh-$sub',
    'user': {
      'id': sub,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': email,
      'created_at': '2026-09-01T00:00:00Z',
      'app_metadata': <String, Object?>{
        'provider': ?provider,
        if (providers ?? [?provider] case final linked when linked.isNotEmpty)
          'providers': linked,
      },
      'user_metadata': userMetadata,
    },
  };

  /// A token shaped like Supabase's (the SDK reads `exp` from it, so it
  /// expires far in the future); the signature is never checked on the
  /// device. Deterministic per [sub], so tests can compare it.
  static String jwt({required String sub}) {
    final header = {'alg': 'ES256', 'typ': 'JWT'};
    final claims = {
      'sub': sub,
      'role': 'authenticated',
      'aud': 'authenticated',
      'exp': DateTime.utc(2099).millisecondsSinceEpoch ~/ 1000,
    };
    return [header, claims].map(_segment).followedBy(['signature']).join('.');
  }

  static String _segment(Map<String, Object> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
}

/// Supabase accepted the email and sent a code.
AuthRound codeSent() =>
    () async => _json(const {}, 200);

/// Supabase accepted the code (or a provider's token) and granted a session
/// for an account of [provider], with sign-in address [email] and
/// [userMetadata].
AuthRound sessionGranted({
  String sub = SupabaseStub.userId,
  String email = SupabaseStub.email,
  String? provider,
  Map<String, Object?> userMetadata = const {},
}) =>
    () async => _json(
      SupabaseStub.session(
        sub: sub,
        email: email,
        provider: provider,
        userMetadata: userMetadata,
      ),
      200,
    );

/// Supabase applied an `updateUser` and returns the user as it now stands,
/// e.g. after a confirmed email change; the SDK then emits `userUpdated`.
AuthRound userUpdated({String email = SupabaseStub.email}) =>
    () async => _json(
      SupabaseStub.session(email: email)['user']! as Map<String, Object?>,
      200,
    );

/// Supabase refused with its error envelope, e.g. `otp_expired`.
///
/// The envelope is the one GoTrue answers to the `2024-01-01` API version
/// the SDK pins on every request: `code` is the error code, `message` the
/// sentence. (The older shape carried the HTTP status as `code` and the
/// error code as `error_code`; the SDK no longer reads it.)
AuthRound authRefused({
  required int statusCode,
  required String errorCode,
  required String message,
}) =>
    () async => _json({'code': errorCode, 'message': message}, statusCode);

/// The session was ended server-side.
AuthRound signedOut() =>
    () async => http.Response('', 204);

/// Supabase is unreachable.
AuthRound authUnreachable() =>
    () async => throw http.ClientException('Connection refused');

/// [round], but only after [delay] — long enough to observe the in-flight
/// state before `pumpAndSettle` runs the clock forward.
AuthRound delayedAuth(
  AuthRound round, [
  Duration delay = const Duration(seconds: 1),
]) =>
    () => Future<http.Response>.delayed(delay, round);

http.Response _json(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );

/// Supabase accepted the request but granted no session.
AuthRound sessionWithheld() =>
    () async => _json(const {}, 200);

/// One request the SDK made, as the stub saw it.
class const RecordedRequest({
  required final String method,
  required final String path,
  required final Map<String, String> query,
  required final Object? body,
}) {
  /// What the request is scripted and looked up by: `METHOD /path`, and for a
  /// consent function called for a purpose other than the journal's, that
  /// purpose after a `#` — the consent record serves every purpose through
  /// one set of functions (#204), and a test about one must not eat the
  /// rounds scripted for the other.
  String get endpoint => switch (body) {
    {'purpose': final String purpose} when purpose != 'journal' =>
      '$method $path#$purpose',
    _ => '$method $path',
  };
}

/// The data API created a row with [id] (`insert(...).select('id').single()`).
AuthRound rowCreated(String id) =>
    () async => _json({'id': id}, 201);

/// The data API changed rows and returned nothing (`Prefer: return=minimal`).
AuthRound rowsChanged() =>
    () async => http.Response('', 204);

/// A database function returned [value].
AuthRound rpcReturned(Object? value) =>
    () async => http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      200,
      headers: const {'content-type': 'application/json'},
    );

/// The data API refused; postgrest raises it as a `PostgrestApiException`.
/// 4xx on purpose: postgrest retries 5xx on idempotent methods, which would
/// eat several scripted rounds for one failure.
AuthRound restRefused({int statusCode = 409, String message = 'refused'}) =>
    () async => _json({'code': 'XX000', 'message': message}, statusCode);

/// The data API answered a count-only select (`.count()`, a HEAD request)
/// with [total]. postgrest reads the total off `content-range`, never the
/// body, so the body stays empty exactly as the server sends it.
AuthRound rowsCounted(int total) =>
    () async => http.Response('', 200, headers: {'content-range': '*/$total'});

/// The data API answered a select with [rowsFound].
AuthRound rows(List<Map<String, Object?>> rowsFound) =>
    () async => http.Response.bytes(
      utf8.encode(jsonEncode(rowsFound)),
      200,
      headers: const {'content-type': 'application/json'},
    );
