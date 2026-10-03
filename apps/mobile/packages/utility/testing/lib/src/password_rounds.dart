import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:testing/src/supabase_stub.dart';

/// Supabase created the account for [email] and mailed its confirmation
/// code (`POST /auth/v1/signup` with confirmations on): the user, and no
/// session until the code is typed in.
AuthRound accountCreated({String email = SupabaseStub.email}) =>
    () async => _json(
      SupabaseStub.session(email: email, provider: 'email')['user']!
          as Map<String, Object?>,
      200,
    );

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
