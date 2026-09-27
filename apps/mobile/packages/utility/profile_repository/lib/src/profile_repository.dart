// `SupabaseClient.table` and the typed builders behind it are marked
// @experimental in supabase 3.0.0-dev; the repositories use them on purpose,
// so the warning is silenced here rather than globally.
// ignore_for_file: experimental_member_use

import 'package:profile_repository/src/display_name.dart';
import 'package:profile_repository/src/profile.dart';
import 'package:profile_repository/src/sign_in_identity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_schema/supabase_schema.dart';

/// The signed-in user's profile, read and written straight from Supabase
/// under their own rights (ADR 0010): row-level security answers with the
/// caller's own row and refuses every other, so nothing here names a user.
///
/// It keeps nothing between calls. It is a singleton for the process, and
/// a profile held here would outlive the user who signed out (ADR 0015).
class const ProfileRepository({required final SupabaseClient supabase}) {
  /// The user's profile, or nothing when they have none yet: an account
  /// that came in without a name, until the name step writes one.
  Future<Profile?> profile() async {
    final row = await supabase.table(Profiles.table).select().maybeSingle();
    return row == null
        ? null
        : Profile(
            displayName: row.displayName,
            nameIsPlaceholder: row.nameIsPlaceholder,
          );
  }

  /// Names the user [name], creating their profile if there is none;
  /// [isPlaceholder] when the app chose it on Skip. Returns the profile as
  /// it now stands.
  ///
  /// An upsert on the user's key, which the server fills in: the app never
  /// sends its own id, and never the timestamps, which are the server's
  /// alone (the column grants refuse them).
  Future<Profile> saveDisplayName(
    DisplayName name, {
    bool isPlaceholder = false,
  }) async {
    await supabase
        .table(Profiles.table)
        .upsert(
          ProfilesInsert(
            displayName: name.value,
            nameIsPlaceholder: isPlaceholder,
          ),
          onConflict: [Profiles.userId],
        );
    return Profile(displayName: name.value, nameIsPlaceholder: isPlaceholder);
  }

  /// Who is signed in and how, from the session on this device; nothing
  /// while nobody is.
  SignInIdentity? signIn() => switch (supabase.auth.currentUser) {
    null => null,
    final user => SignInIdentity.ofUser(user),
  };
}
