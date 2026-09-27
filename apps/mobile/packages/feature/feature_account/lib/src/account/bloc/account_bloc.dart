import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'account_bloc.freezed.dart';
part 'account_event.dart';
part 'account_state.dart';

/// The one thing the account screen does: delete the account (App Store
/// guideline 5.1.1). `delete_account` removes the auth user on the server
/// and, by cascade, every session and entry; what is left is to forget the
/// user on this device, which ends the signed-in state through Supabase's
/// own auth stream.
class AccountBloc({
  required final SupabaseClient _supabase,
  required final AuthAnalytics _analytics,
  required final ErrorReporter _errors,
  required final BuildInfo _build,
}) extends Bloc<AccountEvent, AccountState> {
  this : super(const AccountState.idle()) {
    on<AccountDeletionRequested>(_onDeletionRequested);
    on<AccountFeedbackRequested>(_onFeedbackRequested);
  }

  /// Hands the platform's mail app a message addressed to us, prefilled
  /// with the build the user is running. Emits nothing: the screen does not
  /// change, and whether a mail app exists is not this screen's to answer.
  Future<void> _onFeedbackRequested(
    AccountFeedbackRequested event,
    Emitter<AccountState> emit,
  ) async {
    try {
      await openFeedbackMail(_build);
    } on Exception catch (error, stackTrace) {
      // No mail app is set up, or the platform refused. Nothing to say on
      // screen, but worth knowing about: it makes the beta's one feedback
      // channel a dead end for whoever hit it.
      unawaited(_errors.feedbackMailFailed(error, stackTrace));
    }
  }

  Future<void> _onDeletionRequested(
    AccountDeletionRequested event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountState.deleting());
    try {
      await _supabase.rpc<Object?>('delete_account');
    } on Exception catch (error, stackTrace) {
      // Still attributed to the user: PostHog only forgets them below.
      unawaited(_errors.accountDeletionFailed(error, stackTrace));
      emit(const AccountState.failure());
      return;
    }
    // Before the session ends: once the auth stream reports that, the app
    // is on Welcome, and nothing it sends may go out under this person's
    // id or consent (#204).
    await _analytics.accountDeleted();
    // The user no longer exists, so only the local session can be ended:
    // the SDK's default `SignOutScope.local` is the right one, since a
    // global sign-out would only be refused (403) and every other device's
    // refresh fails on its own now. The SDK still tells the server and
    // shrugs off that refusal (401/403/404); anything else is caught here,
    // because the local session is gone either way.
    try {
      await _supabase.auth.signOut();
    } on Exception {
      // Already signed out locally, which is all that matters here.
    }
    emit(const AccountState.deleted());
  }

  static const failureMessage =
      'Could not delete your account. Check your connection and try again.';
}
