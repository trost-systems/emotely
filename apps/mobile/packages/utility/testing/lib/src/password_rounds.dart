import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:testing/src/supabase_stub.dart';

/// Supabase created the account for [email] and mailed its confirmation
/// code (`POST /auth/v1/signup` with confirmations on): the user, and no
/// session until the code is typed in. A new account has its email
/// identity, which [accountHidden] lacks.
AuthRound accountCreated({String email = SupabaseStub.email}) =>
    () async => _json({
      ...SupabaseStub.session(email: email, provider: 'email')['user']!
          as Map<String, Object?>,
      'identities': [
        {
          'id': SupabaseStub.userId,
          'identity_id': '40000000-0000-0000-0000-000000000001',
          'user_id': SupabaseStub.userId,
          'identity_data': {'email': email, 'sub': SupabaseStub.userId},
          'provider': 'email',
        },
      ],
    }, 200);

/// Supabase's answer to a sign-up for [email] when a confirmed account has
/// it and confirmations are on: 200 and a made-up user, so the reply does
/// not tell whether the address is registered — a fresh id, no role, no
/// identities, and no session. No mail goes out. GoTrue's `sanitizeUser`
/// (`internal/api/signup.go`).
AuthRound accountHidden({String email = SupabaseStub.email}) =>
    () async => _json({
      'id': '50000000-0000-0000-0000-000000000001',
      'aud': 'authenticated',
      'role': '',
      'email': email,
      'phone': '',
      'confirmation_sent_at': '2026-09-01T00:00:00Z',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
      'app_metadata': {
        'provider': 'email',
        'providers': ['email'],
      },
      'user_metadata': const <String, Object?>{},
      'identities': const <Object?>[],
      'is_anonymous': false,
    }, 200);

/// Supabase refused a new password as too weak, the way GoTrue answers it:
/// `weak_password`, with the reasons beside the message.
AuthRound passwordTooWeak() =>
    () async => _json(const {
      'code': 'weak_password',
      'message': 'Password should be at least 10 characters.',
      'weak_password': {
        'reasons': ['length'],
      },
    }, 422);

http.Response _json(Map<String, Object?> body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
