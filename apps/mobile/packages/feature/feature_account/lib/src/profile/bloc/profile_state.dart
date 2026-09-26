part of 'profile_bloc.dart';

/// Whether the profile has been read.
enum ProfileStatus() {
  loading,
  ready,
  loadFailed,
}

/// What the screen tells the user once, after they left the name field.
enum ProfileNotice() {
  /// The new name is saved.
  saved,

  /// The field was emptied; the name that stands is shown again.
  nameEmpty,

  /// The name holds something the profile does not take.
  nameRefused,

  /// The server did not take the name; the one that stands is shown again.
  saveFailed,
}

/// The profile as the screens show it.
///
/// No generated `toString`: [profile] holds the name and [identity] the
/// address, and a state printed by a `BlocObserver` or an error log must
/// print neither (ADR 0005).
@Freezed(toStringOverride: false)
abstract class ProfileState with _$ProfileState {
  const factory({
    @Default(ProfileStatus.loading) ProfileStatus status,

    /// The name as saved; none until the user has one.
    Profile? profile,

    /// Who is signed in and how; none only while nobody is.
    SignInIdentity? identity,

    /// A new name is on its way to the server.
    @Default(false) bool saving,

    /// The last thing to tell the user, and how many have been told, so
    /// the same notice twice in a row is still told twice.
    ProfileNotice? notice,
    @Default(0) int noticeCount,
  }) = _ProfileState;
}
