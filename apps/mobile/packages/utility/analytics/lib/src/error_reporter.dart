import 'dart:async';

import 'package:agent_client/agent_client.dart';
import 'package:analytics/src/auth_analytics.dart';
import 'package:analytics/src/post_hog_gate.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handled failures, reported to PostHog error tracking (ADR 0004) with
/// their type, stack trace and the step that failed — the "why" behind the
/// counting events next to them (`session_failed`, `entry_save_failed`, …),
/// which only say how often.
///
/// Content-free by construction like the analytics (ADR 0005): the
/// properties are ids, status codes and the step, and an exception's message
/// only travels when its type is known to carry the agent's own words or a
/// transport error — see [contentFree]. Uncaught errors take the SDK's own
/// path, where `contentFreeExceptions` (error_tracking.dart) applies the
/// same rule on the wire. The version is stamped by the SDK
/// (`$app_version`).
class const ErrorReporter({required final PostHogGate gate}) {
  /// A session round failed against the agent; [statusCode] is absent when
  /// the server was unreachable.
  Future<void> sessionFailed(
    Exception error,
    StackTrace stackTrace, {
    int? statusCode,
  }) => _report(
    error,
    stackTrace,
    step: 'session_round',
    properties: {'status_code': ?statusCode},
  );

  /// A round could not be written to the journal row [sessionId] (absent
  /// when the row itself could not be created).
  Future<void> sessionSaveFailed(
    Exception error,
    StackTrace stackTrace, {
    String? sessionId,
  }) => _report(
    error,
    stackTrace,
    step: 'session_save',
    properties: {'session_id': ?sessionId},
  );

  /// The finished entry could not be filed for the session row [sessionId].
  Future<void> entrySaveFailed(
    Exception error,
    StackTrace stackTrace, {
    String? sessionId,
  }) => _report(
    error,
    stackTrace,
    step: 'entry_save',
    properties: {'session_id': ?sessionId},
  );

  /// Supabase refused to send a sign-in code.
  Future<void> codeRequestFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'sign_in_code_request');

  /// Supabase refused the code the user typed.
  Future<void> codeVerifyFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'sign_in_code_verify');

  /// Supabase refused a review account's password (never the password
  /// itself: an `AuthException` goes out with its message withheld).
  Future<void> passwordSignInFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'sign_in_password');

  /// Signing in with [provider] failed, on the platform's side or when
  /// Supabase checked its token (never the token itself: every such
  /// exception goes out with its message withheld).
  Future<void> providerSignInFailed(
    Exception error,
    StackTrace stackTrace, {
    required SignInMethod provider,
  }) => _report(
    error,
    stackTrace,
    step: 'sign_in_provider',
    properties: {'provider': provider.name},
  );

  /// The app's language could not be kept on the account after a sign-in.
  /// Costs the sign-in nothing; only the next sign-in mail comes in the
  /// language kept before (English if none), and the next sign-in tries
  /// again.
  Future<void> mailLanguageSaveFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'mail_language_save');

  /// The `delete_account` call failed.
  Future<void> accountDeletionFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'account_deletion');

  /// The startup config could not be read. The app blocks entirely on this,
  /// so it is the most user-visible failure there is: worth knowing about
  /// the moment it starts happening.
  Future<void> configLoadFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'config_load');

  /// The store could not be opened from the force-update screen. The user is
  /// stuck: the screen has no way past it and the one action it offers just
  /// failed, so this is worth knowing about even though nothing can retry it.
  Future<void> storeLaunchFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'store_launch');

  /// The mail app could not be opened from the account screen. Nothing is
  /// shown — the screen is unchanged and the user can write to us by other
  /// means — but during the beta this is the one channel every qualitative
  /// signal comes through, so a device where it dead-ends is worth knowing.
  Future<void> feedbackMailFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'feedback_mail');

  /// The journal could not be counted after an entry was filed, so the
  /// `third_entry_written` milestone (and the survey it triggers) was
  /// missed. Costs the user nothing — the entry is already in the journal
  /// and the screen never hears about it — but a milestone that silently
  /// stops firing is a bug that would otherwise look like nobody reaching
  /// three entries.
  Future<void> entryMilestoneFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'entry_milestone');

  /// Whether consent stands could not be read. The gate stays shut on this,
  /// so it is worth knowing how often it happens.
  Future<void> consentLoadFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'consent_load');

  /// A consent or a withdrawal could not be written. The more serious of the
  /// two: a session must not start on a consent the server never recorded,
  /// and a withdrawal that did not land leaves consent standing.
  Future<void> consentWriteFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'consent_write');

  /// The usage-analytics choice could not be recorded against the account
  /// (#204). The device still obeys the choice, so PostHog is on or off as
  /// asked; only the evidence lags, and the next sign-in tries again. Only
  /// ever reported while usage analytics are allowed, like everything else.
  Future<void> usageAnalyticsRecordFailed(
    Exception error,
    StackTrace stackTrace,
  ) => _report(error, stackTrace, step: 'usage_analytics_record');

  /// The profile could not be read. The screens fall back to asking for a
  /// name, so the user may type one they already gave.
  Future<void> profileLoadFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'profile_load');

  /// A new name could not be saved; the field went back to the last one
  /// that was. The refusal is withheld like every Postgres error, since it
  /// can quote the row and so the name (ADR 0005).
  Future<void> profileSaveFailed(Exception error, StackTrace stackTrace) =>
      _report(error, stackTrace, step: 'profile_save');

  Future<void> _report(
    Exception error,
    StackTrace stackTrace, {
    required String step,
    Map<String, Object> properties = const {},
  }) => gate.captureException(
    error: contentFree(error),
    stackTrace: stackTrace,
    properties: {'step': step, ...properties},
  );

  /// [error] as it may leave the device. PostHog records an exception's
  /// `toString()`, so only types whose text is the agent's own error
  /// message or a transport error naming a host go out as they are (the
  /// same set `forwardedTypes` lets through on the wire). Everything else
  /// may quote what it choked on — a Postgres error the failing row, a JSON
  /// error the body, GoTrue the address it validated or, for a 5xx, the
  /// whole response body — and goes out as a [WithheldException] instead.
  /// Every Supabase service shares one exception base, so one arm keeps the
  /// codes of a refusal from any of them (auth, data API, and whatever the
  /// app may call next) and one the code of a failure raised on the device.
  static Exception contentFree(Exception error) => switch (error) {
    // ConfigException carries a status code or a transport error, never a
    // journal or a user — it is written here, not by a server or a database,
    // and never from a parse error (which would embed the body it read).
    AgentException() ||
    ConfigException() ||
    http.ClientException() ||
    TimeoutException() => error,
    SupabaseApiException(:final errorCode, :final statusCode) =>
      WithheldException(
        error.runtimeType,
        code: errorCode,
        statusCode: statusCode,
      ),
    SupabaseException(:final errorCode) => WithheldException(
      error.runtimeType,
      code: errorCode,
    ),
    _ => WithheldException(error.runtimeType),
  };
}

/// An exception reported without its message: [type] says what failed,
/// [code] (a SQLSTATE, a GoTrue error code) and [statusCode] (the HTTP
/// status, when a service answered at all) which way; the text stays on the
/// device because it may quote the journal or the user (ADR 0005).
///
/// What a debugger gives up: for a `PostgrestApiException` the `message`,
/// `details` and `hint` — i.e. which constraint or policy objected, only
/// the SQLSTATE class survives; for an `AuthException` GoTrue's sentence.
/// The way back is to reproduce locally with the ids the report carries,
/// or to add a field to the allowlist in [ErrorReporter.contentFree] once
/// it is proven content-free for every value it can take.
@immutable
class const WithheldException(
  final Type type, {
  final String? code,
  final int? statusCode,
}) implements Exception {
  @override
  String toString() =>
      '${[type, ?statusCode, ?code].join(' ')} (message withheld, ADR 0005)';

  @override
  bool operator ==(Object other) =>
      other is WithheldException &&
      other.type == type &&
      other.code == code &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(type, code, statusCode);
}
