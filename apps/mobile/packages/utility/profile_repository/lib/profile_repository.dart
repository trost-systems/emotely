/// The signed-in user's profile: the name they asked to be called, checked
/// by the same rules as the `profiles` table, and how they signed in. Read
/// and written straight from Supabase under the user's own rights
/// (ADR 0010); nothing here can reach another user's row.
library;

export 'src/display_name.dart';
export 'src/profile.dart';
export 'src/profile_repository.dart';
export 'src/register.dart';
export 'src/sign_in_identity.dart';
