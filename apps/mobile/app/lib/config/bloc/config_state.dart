part of 'config_bloc.dart';

/// Whether this build may run, as far as the server is concerned.
@freezed
sealed class ConfigState with _$ConfigState {
  /// The answer is not in yet — the state the app launches in.
  const factory unknown() = ConfigUnknown;

  /// The server serves this build; the app may run. The config itself is
  /// not carried: everything it holds is either acted on here (the minimum)
  /// or only needed when blocked (the store link).
  const factory ready() = ConfigReady;

  /// This build is below [minAppVersion]; the user must update via [storeUrl].
  const factory updateRequired({
    required String minAppVersion,
    required String storeUrl,
  }) = ConfigUpdateRequired;

  /// The config could not be read, for the reason in [problem]; the screen
  /// offers a retry. Deliberately not "allowed": an unreachable server is
  /// not permission.
  const factory failure({required ConfigProblem problem}) = ConfigFailure;
}
