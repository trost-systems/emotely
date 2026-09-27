import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Consent to usage analytics (#204): the answer to "May I count how you use
/// the app?", which the device holds and PostHog obeys ([PostHogGate]), and
/// which the consent record keeps as evidence once someone is signed in.
///
/// The one place the app changes that answer, so the first-launch sheet and
/// the Privacy settings screen cannot drift apart.
///
/// **The device decides; the server remembers.** The question comes before
/// there is an account, so the choice lives on the device and PostHog
/// follows it there and then. Once someone is signed in — on a sign-in, a
/// restored session, or a change made while signed in — the choice is
/// appended to the consent record (ADR 0014) as purpose `usage_analytics`
/// against [_version], but only where it differs from the latest event the
/// server holds: an allow is recorded where no consent stands, a refusal is
/// recorded as a withdrawal only where one does. A refusal that was never a
/// consent records nothing, as for the journal.
///
/// **The choice belongs to a person, not the phone.** When the session of
/// the person who is signed in ends — however it ends: a sign-out, an
/// expiry, a revoked refresh token, an account deleted elsewhere, another
/// account taking its place — the device forgets the choice, PostHog
/// switches off, and the question is asked again of whoever comes next.
/// The forget is queued on the gate the moment the session stream says so,
/// before anything that reacts to the sign-out (the router, the onboarding
/// events waiting for an answer) and before the next sign-in's write reads
/// the choice, so one person's answer can never be recorded on another
/// person's consent record.
///
/// A write that fails changes nothing on the device and is reported; the
/// next sign-in, or the next change, tries again.
class UsageAnalyticsConsent({
  required final PostHogGate _gate,
  required final SupabaseClient _supabase,
  required final String _version,
  required final ErrorReporter _errors,
}) {
  this {
    _sessions = _supabase.auth.onAuthStateChange.listen(
      _onAuthChange,
      // A failed background refresh is reported here and changes nothing
      // about who is signed in, so there is nothing to record.
      onError: (Object _, StackTrace _) {},
    );
  }

  late final StreamSubscription<AuthState> _sessions;

  /// Who the session last said is signed in, so the session saying so twice
  /// (a sign-in, then the restored session) asks the server once.
  String? _signedIn;

  /// The write in flight, or the last one; writes queue behind each other so
  /// two never race to append the same event.
  var _recording = Future<void>.value();

  /// The answer as it stands; `null` while nobody on this device has been
  /// asked yet.
  AnalyticsChoice? get choice => _gate.choice;

  /// Every change of [choice] from here on, from wherever it was made.
  Stream<AnalyticsChoice?> get changes => _gate.changes;

  /// Completes once every change asked for so far has been applied.
  Future<void> get settled => _gate.settled;

  /// Completes once every server write asked for so far has been attempted.
  Future<void> get recorded => _recording;

  /// The user allowed: PostHog is set up, and the account, if any, records
  /// it.
  Future<void> allow() async {
    await _gate.allow();
    await _record();
  }

  /// The user said no, or withdrew: PostHog is switched off, and a consent
  /// standing on the account, if any, is withdrawn.
  Future<void> deny() async {
    await _gate.deny();
    await _record();
  }

  /// Stops following the session. The app never needs to: the consent lives
  /// as long as the process, like the Supabase client it listens to. A unit
  /// test closes it; the container does not, because a widget test's
  /// teardown that awaits the cancel never completes.
  Future<void> close() => _sessions.cancel();

  void _onAuthChange(AuthState change) {
    final user = change.session?.user.id;
    if (user != _signedIn) {
      // Queued before the write below, which waits for it: whatever the
      // last person answered is gone before anyone else's record is asked.
      if (_signedIn != null) {
        unawaited(_gate.forget());
      }
      _signedIn = user;
      if (user != null) {
        unawaited(_record());
      }
    }
  }

  Future<void> _record() => _recording = _recording.then((_) => _write());

  Future<void> _write() async {
    await _gate.settled;
    final user = _supabase.auth.currentUser?.id;
    final choice = _gate.choice;
    if (user == null || choice == null) {
      return;
    }
    final params = {'version': _version, 'purpose': 'usage_analytics'};
    try {
      final stands = await _supabase.rpc<bool>(
        'consent_stands',
        params: params,
      );
      final function = switch (choice) {
        AnalyticsChoice.allowed when !stands => 'record_consent',
        AnalyticsChoice.denied when stands => 'withdraw_consent',
        _ => null,
      };
      if (function != null) {
        await _supabase.rpc<void>(function, params: params);
      }
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.usageAnalyticsRecordFailed(error, stackTrace));
    }
  }
}
