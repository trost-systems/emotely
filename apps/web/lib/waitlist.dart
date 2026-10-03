/// The one thing the site writes: an address into `public.waitlist`
/// (ADR 0011). Talks to the Supabase Data API directly with the publishable
/// key; the table's trigger owns validation, de-duplication and rate limits,
/// so this side only maps HTTP statuses to what the form should say.
library;

import 'dart:convert';

import 'package:emotely_web/site_locale.dart';
import 'package:http/http.dart' as http;

/// What happened to a sign-up, as far as the form needs to know.
enum JoinOutcome() {
  /// Stored (or already there — the API does not tell, on purpose).
  joined,

  /// Rate-limited (HTTP 429): try again later.
  tooMany,

  /// The address failed the table's checks (HTTP 400).
  rejected,

  /// Anything else, including no network: worth a retry.
  failed,
}

/// The cheap client-side check that keeps obvious typos from a round trip.
/// The table applies the same shape server-side.
bool looksLikeEmail(String value) => _emailShape.hasMatch(value);

final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Adds [email] to the waitlist through [client], with the [locale] of the
/// page it was typed on: the confirmation mail is written in that language.
Future<JoinOutcome> joinWaitlist(
  http.Client client, {
  required String email,
  required Uri supabaseUrl,
  required String publishableKey,
  String source = 'landing',
  SiteLocale locale = .en,
}) async {
  final row = {'email': email, 'source': source, 'locale': locale.code};
  final http.Response response;
  try {
    response = await _insert(client, row, supabaseUrl, publishableKey);
    // The site and the database deploy separately (Vercel, CI's
    // supabase-deploy), in no fixed order. Until the migration that adds
    // `locale` is live, PostgREST refuses the unknown key with 400 PGRST204;
    // the sign-up then goes through without it, in English, rather than
    // telling the reader their address was refused.
    if (_lacksColumn(response, 'locale')) {
      return _outcomeOf(
        await _insert(
          client,
          {...row}..remove('locale'),
          supabaseUrl,
          publishableKey,
        ),
      );
    }
  } on http.ClientException {
    return JoinOutcome.failed;
  }
  return _outcomeOf(response);
}

Future<http.Response> _insert(
  http.Client client,
  Map<String, String> row,
  Uri supabaseUrl,
  String publishableKey,
) => client.post(
  supabaseUrl.resolve('/rest/v1/waitlist'),
  headers: {
    'apikey': publishableKey,
    'authorization': 'Bearer $publishableKey',
    'content-type': 'application/json',
    // No select privilege on the table, so nothing could come back anyway.
    'prefer': 'return=minimal',
  },
  body: jsonEncode(row),
);

/// Whether PostgREST refused the request because its schema has no
/// [column] on the table: 400 with code PGRST204, naming the column.
bool _lacksColumn(http.Response response, String column) =>
    response.statusCode == 400 &&
    switch (_decoded(response.body)) {
      {'code': 'PGRST204', 'message': final String message} => message.contains(
        "'$column'",
      ),
      _ => false,
    };

/// [body] as JSON, or null when it is not JSON at all.
Object? _decoded(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

JoinOutcome _outcomeOf(http.Response response) => switch (response.statusCode) {
  201 => JoinOutcome.joined,
  429 => JoinOutcome.tooMany,
  400 => JoinOutcome.rejected,
  _ => JoinOutcome.failed,
};

/// What the confirm link led to.
enum ConfirmOutcome() {
  /// The address is confirmed, from this click.
  confirmed,

  /// The token matched no waiting row: already used, a week old, or made up.
  unknown,

  /// Anything else, including no network: worth a retry.
  failed,
}

/// Redeems the [token] from a confirmation mail through [client]: the
/// anon-callable RPC `confirm_waitlist` (ADR 0011) answers `true` exactly
/// once per row.
Future<ConfirmOutcome> confirmWaitlist(
  http.Client client, {
  required String token,
  required Uri supabaseUrl,
  required String publishableKey,
}) async {
  final http.Response response;
  try {
    response = await client.post(
      supabaseUrl.resolve('/rest/v1/rpc/confirm_waitlist'),
      headers: {
        'apikey': publishableKey,
        'authorization': 'Bearer $publishableKey',
        'content-type': 'application/json',
      },
      body: jsonEncode({'token': token}),
    );
  } on http.ClientException {
    return ConfirmOutcome.failed;
  }
  return switch (response.statusCode) {
    200 when response.body.trim() == 'true' => ConfirmOutcome.confirmed,
    // `false`, or a token Postgres would not even parse as a uuid.
    200 || 400 => ConfirmOutcome.unknown,
    _ => ConfirmOutcome.failed,
  };
}
