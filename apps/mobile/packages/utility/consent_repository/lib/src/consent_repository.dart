import 'package:supabase_flutter/supabase_flutter.dart';

/// The app's side of the consent record: whether the signed-in user has
/// agreed to [version] of the notice, and the two writes that change that.
/// Read from the server, never from the device — a local flag would not
/// survive a reinstall and would not be the proof Art. 7 (1) asks the
/// controller for.
///
/// [version] names the wording the app currently asks consent for; the app
/// owns the wording and its version (it is user-facing copy), this package
/// only records agreement to it.
class const ConsentRepository({
  required final SupabaseClient supabase,
  required final String version,
}) {
  /// Whether consent to [version] stands right now.
  ///
  /// The server derives this from the latest event, so the app never walks
  /// the history itself. False covers three cases the screen does not need
  /// to tell apart: never asked, withdrawn, and consented to an older
  /// wording only. All three mean the same thing — ask before the next
  /// session.
  Future<bool> isGranted() =>
      supabase.rpc<bool>('consent_stands', params: {'version': version});

  /// Records consent to the current wording. Idempotent on the server, so a
  /// double tap or a retry writes one row.
  Future<void> grant() =>
      supabase.rpc<void>('record_consent', params: {'version': version});

  /// When consent to [version] was last given, or `null` if it never was.
  /// The user reads their own history directly (row-level security scopes
  /// it); only the latest grant of the journal's purpose counts, which is
  /// the one that stands whenever consent does.
  Future<DateTime?> grantedAt() async {
    final row = await supabase
        .from('consent_events')
        .select('recorded_at')
        .eq('purpose', 'journal')
        .eq('version', version)
        .eq('action', 'granted')
        // Latest first: `seq` is the order of the record (ADR 0014).
        .order('seq', ascending: false)
        .limit(1)
        .maybeSingle();
    return switch (row) {
      {'recorded_at': final String recordedAt} => DateTime.parse(recordedAt),
      _ => null,
    };
  }

  /// Takes it back (Art. 7 (3)). Idempotent, and harmless if no consent was
  /// ever recorded.
  Future<void> withdraw() =>
      supabase.rpc<void>('withdraw_consent', params: {'version': version});
}
