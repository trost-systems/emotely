part of 'profile_bloc.dart';

/// What the Profile screen and the More tab's card can tell [ProfileBloc].
///
/// No generated `toString`: a submitted name is personal data, and a
/// `BlocObserver` or an error log printing an event must never print it
/// (ADR 0005).
@Freezed(toStringOverride: false)
sealed class ProfileEvent with _$ProfileEvent {
  /// Read the profile, or read it again.
  const factory loaded() = ProfileLoaded;

  /// The name field was left, or its done key pressed, holding [raw].
  const factory nameSubmitted(String raw) = ProfileNameSubmitted;
}
