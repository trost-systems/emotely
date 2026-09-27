import 'package:testing/src/supabase_stub.dart';

/// The `profiles` endpoint of the data API.
const profilesPath = '/rest/v1/profiles';

/// Reading the profile (`GET`) and saving it (`POST`, an upsert).
const profileRead = 'GET $profilesPath';
const profileSave = 'POST $profilesPath';

/// A `profiles` row as Supabase returns it.
Map<String, Object?> profileRow({
  required String displayName,
  bool nameIsPlaceholder = false,
}) => {
  'user_id': SupabaseStub.userId,
  'display_name': displayName,
  'name_is_placeholder': nameIsPlaceholder,
  'created_at': '2026-09-26T20:00:00+00:00',
  'updated_at': '2026-09-26T20:00:00+00:00',
};
