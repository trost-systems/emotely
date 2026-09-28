import 'dart:async';

import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

part 'config_bloc.freezed.dart';
part 'config_event.dart';
part 'config_state.dart';

/// The startup gate: reads the server's config once and decides whether this
/// build may run at all (#49).
///
/// It sits above everything else, including sign-in, because a build the
/// server no longer serves must be told so before it tries to do anything —
/// and because the store link the user needs comes from this same call.
class ConfigBloc({
  required final ConfigClient _client,
  required final String _appVersion,
  required final SessionAnalytics _analytics,
  required final ErrorReporter _errors,
}) extends Bloc<ConfigEvent, ConfigState> {
  this : super(const ConfigState.unknown()) {
    on<ConfigLoaded>(_onLoaded);
    on<ConfigUpdateRequested>(_onUpdateRequested);
  }

  Future<void> _onLoaded(ConfigLoaded event, Emitter<ConfigState> emit) async {
    // The gate shows the checking screen while this runs, so there is no
    // retry button on screen to press twice: one read is in flight at a time
    // by construction, and no re-entrancy guard is needed here.
    emit(const ConfigState.unknown());
    final StartupConfig config;
    try {
      config = await _client.fetch();
    } on ConfigException catch (error, stackTrace) {
      unawaited(_errors.configLoadFailed(error, stackTrace));
      emit(
        ConfigState.failure(
          problem: error.unreachable
              ? ConfigProblem.unreachable
              : ConfigProblem.unreadable,
        ),
      );
      return;
    }
    final bool blocked;
    try {
      blocked = _isNewerThanThisBuild(config.minAppVersion);
    } on FormatException catch (error, stackTrace) {
      // A version neither side can parse is a misconfigured server, not an
      // out-of-date app: the update screen would send the user to a store
      // that cannot fix it. Fail shut, but as a failure with a retry, and
      // report it — nobody else will notice a bad constant on this path.
      unawaited(_errors.configLoadFailed(error, stackTrace));
      emit(const ConfigState.failure(problem: ConfigProblem.unreadable));
      return;
    }
    if (blocked) {
      unawaited(
        _analytics.updateRequired(
          minAppVersion: config.minAppVersion,
          appVersion: _appVersion,
        ),
      );
    }
    emit(
      blocked
          ? ConfigState.updateRequired(
              minAppVersion: config.minAppVersion,
              storeUrl: config.storeUrl,
            )
          : const ConfigState.ready(),
    );
  }

  /// Opens the store the server named. The screen stays blocking whether or
  /// not the store opens — there is nothing else it could show — but a
  /// failure here strands the user on their only way out, so it is reported
  /// rather than swallowed.
  Future<void> _onUpdateRequested(
    ConfigUpdateRequested event,
    Emitter<ConfigState> emit,
  ) async {
    if (state case ConfigUpdateRequired(:final storeUrl)) {
      try {
        await launchUrl(
          Uri.parse(storeUrl),
          mode: LaunchMode.externalApplication,
        );
      } on Exception catch (error, stackTrace) {
        unawaited(_errors.storeLaunchFailed(error, stackTrace));
      }
    }
  }

  /// Whether the server's minimum is newer than this build.
  ///
  /// Throws [FormatException] if either version is unparseable; the caller
  /// treats that as a failed read rather than guessing which way it falls.
  bool _isNewerThanThisBuild(String minAppVersion) =>
      Version.parse(minAppVersion) > Version.parse(_appVersion);
}

/// Why the config could not be had, as far as the user can act on it. The
/// screen words each in the user's language (ADR 0020); what exactly went
/// wrong goes to error tracking, not onto the screen.
enum ConfigProblem() {
  /// No answer at all: offline, a timeout, a name that did not resolve. The
  /// user can check their connection.
  unreachable,

  /// An answer the app cannot use: an error status, a body it cannot read,
  /// a minimum version neither side can parse. Nothing the user did, and
  /// not the force-update wording either: a retry is the only honest
  /// action on offer.
  unreadable,
}
