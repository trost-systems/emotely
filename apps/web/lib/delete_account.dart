/// Deleting an account from the web, for people who no longer have the app
/// (Google Play's account-deletion policy asks for exactly this link).
///
/// It proves mailbox ownership the way the app does — a six-digit code sent
/// to the address — and then calls the same `public.delete_account()` the
/// app calls, with the user's own access token. Nothing here is privileged:
/// the publishable key only gets GoTrue to send a code, and the deletion
/// runs under row-level security as the user it deletes (ADR 0010), so a
/// stolen page or a forged request can delete nothing but its own mailbox.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// What happened to a request for a deletion code.
enum CodeRequestOutcome() {
  /// A code is on its way — or the address has no account, which is
  /// reported identically on purpose (see [requestDeletionCode]).
  sent,

  /// Rate-limited (HTTP 429): too many codes for now.
  tooMany,

  /// Anything else, including no network: worth a retry.
  failed,
}

/// What happened to a deletion.
enum DeletionOutcome() {
  /// The account and everything hanging off it are gone.
  deleted,

  /// The code was wrong, already used, or older than its ten minutes.
  badCode,

  /// Anything else, including no network: worth a retry.
  failed,
}

/// The shape of the code the sign-in mail carries: six digits, nothing else.
bool looksLikeCode(String value) => _codeShape.hasMatch(value);

final _codeShape = RegExp(r'^\d{6}$');

/// Drops every kind of space a code picks up on its way out of a mail app
/// and through a clipboard — "12 34 56", a stray newline, the non-breaking
/// space some clients insert — so a correct code is not refused for how it
/// was pasted. Anything else is left alone for [looksLikeCode] to judge.
String normalizeCode(String value) => value.replaceAll(_spaces, '');

final _spaces = RegExp(r'\s+', unicode: true);

/// Asks GoTrue to mail a one-time code to [email], **without creating an
/// account** for an address that has none (`create_user: false`): someone
/// asking to be deleted must never be signed up as a side effect.
///
/// That flag makes GoTrue answer `422 otp_disabled` for an unknown address
/// and `200` for a known one. Both are reported as [CodeRequestOutcome.sent]
/// and the page says "if that address has an account, the code is on its
/// way", so the page never relays the distinction to its reader or its
/// analytics.
///
/// The page is not what opens that oracle either: a scripted caller reads
/// the 422-vs-200 (or the send latency) straight from GoTrue. What closes
/// it, and keeps a script from spending the project's hourly mail quota,
/// is the human check (#94): GoTrue refuses the request with `400
/// captcha_failed` unless [captchaToken], a single-use Cloudflare Turnstile
/// token, verifies with Cloudflare first, so every probe costs a solved
/// check. That refusal is [CodeRequestOutcome.failed]; a retry asks
/// Turnstile for a fresh token, since a spent one never verifies twice.
Future<CodeRequestOutcome> requestDeletionCode(
  http.Client client, {
  required String email,
  required Uri supabaseUrl,
  required String publishableKey,
  required String captchaToken,
}) async {
  final http.Response response;
  try {
    response = await client.post(
      supabaseUrl.resolve('/auth/v1/otp'),
      headers: {
        'apikey': publishableKey,
        'authorization': 'Bearer $publishableKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'create_user': false,
        'gotrue_meta_security': {'captcha_token': captchaToken},
      }),
    );
  } on http.ClientException {
    return CodeRequestOutcome.failed;
  }
  return switch (response.statusCode) {
    200 => CodeRequestOutcome.sent,
    // An unknown address: answered exactly like a sent code, deliberately.
    422 => CodeRequestOutcome.sent,
    429 => CodeRequestOutcome.tooMany,
    _ => CodeRequestOutcome.failed,
  };
}

/// Redeems [code] for [email] and deletes that account.
///
/// Two calls, in this order: `verify` trades the code for an access token,
/// and `delete_account` runs as its bearer. The code is bound to the
/// address server-side, so a code from one mailbox cannot delete another
/// account — the worst a mismatched pair does is fail to verify. The token
/// is used once, here, and never stored: no session survives the call, and
/// there is nothing left to sign in with afterwards.
Future<DeletionOutcome> deleteAccountWithCode(
  http.Client client, {
  required String email,
  required String code,
  required Uri supabaseUrl,
  required String publishableKey,
}) async {
  try {
    final verified = await client.post(
      supabaseUrl.resolve('/auth/v1/verify'),
      headers: {
        'apikey': publishableKey,
        'authorization': 'Bearer $publishableKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({'email': email, 'token': code, 'type': 'email'}),
    );
    if (verified.statusCode != 200) {
      // 403 otp_expired is the wrong/old code; 400 is a malformed pair.
      return switch (verified.statusCode) {
        400 || 401 || 403 || 422 => DeletionOutcome.badCode,
        _ => DeletionOutcome.failed,
      };
    }
    final accessToken = _accessToken(verified.body);
    if (accessToken == null) {
      return DeletionOutcome.failed;
    }

    final deleted = await client.post(
      supabaseUrl.resolve('/rest/v1/rpc/delete_account'),
      headers: {
        'apikey': publishableKey,
        // The user's own token: the function is `security definer` but
        // deletes `auth.uid()`, so this header is what scopes it.
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: '{}',
    );
    // `delete_account()` answers true only when a row really went, so a
    // 2xx alone is not enough to promise the reader their account is gone.
    if (deleted.statusCode == 200 && deleted.body.trim() == 'true') {
      // The cascade took the session with the user; nothing to give back.
      return DeletionOutcome.deleted;
    }
    // Verify minted a session (access and refresh token) that nothing
    // deleted. Hand it back rather than leave it alive for its refresh
    // window — best effort, and the outcome is a failure either way.
    await _logout(client, accessToken, supabaseUrl, publishableKey);
    return DeletionOutcome.failed;
  } on http.ClientException {
    return DeletionOutcome.failed;
  }
}

/// Ends the session [accessToken] belongs to, ignoring whatever comes back:
/// this runs on a path that already failed, and a session that outlives the
/// page is the only thing worth avoiding here.
Future<void> _logout(
  http.Client client,
  String accessToken,
  Uri supabaseUrl,
  String publishableKey,
) async {
  try {
    await client.post(
      supabaseUrl.resolve('/auth/v1/logout'),
      headers: {
        'apikey': publishableKey,
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
    );
  } on http.ClientException {
    // Offline: the token expires on its own, and there is nothing to retry.
  }
}

/// The `access_token` out of a verify response, or null if the body is not
/// the JSON object we expect.
String? _accessToken(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded case {'access_token': final String token} when token.isNotEmpty) {
    return token;
  }
  return null;
}
