import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

/// The user's profile as the app shows it: what they asked to be called.
///
/// No generated `toString`: [displayName] is personal data, and a
/// `BlocObserver`, an assertion or an error log printing a state that
/// holds it must never print the name (ADR 0005).
@Freezed(toStringOverride: false)
abstract class Profile with _$Profile {
  /// A profile named [displayName]; [nameIsPlaceholder] when the app chose
  /// the name on Skip rather than the user typing it.
  const factory({
    required String displayName,
    required bool nameIsPlaceholder,
  }) = _Profile;
}
