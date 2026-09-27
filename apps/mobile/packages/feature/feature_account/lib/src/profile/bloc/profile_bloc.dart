import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:profile_repository/profile_repository.dart';

part 'profile_bloc.freezed.dart';
part 'profile_event.dart';
part 'profile_state.dart';

/// The user's profile as the Profile screen and the More tab's card show
/// it: the name they asked to be called, read from the server, and who is
/// signed in, read from the session on this device.
///
/// A new name is checked by the same rules as the table
/// ([DisplayName.check]) before anything is sent, so a refusal is known on
/// the device and the field goes back to the name that stands. A name the
/// user types is never a placeholder, whatever it replaces.
class ProfileBloc({
  required final ProfileRepository _repository,
  required final ErrorReporter _errors,
  required final OnboardingAnalytics _analytics,
}) extends Bloc<ProfileEvent, ProfileState> {
  this : super(const ProfileState()) {
    on<ProfileLoaded>(_onLoaded);
    on<ProfileNameSubmitted>(_onNameSubmitted);
  }

  /// Reads the profile. Only the first read, and one after a failure, shows
  /// progress: a card read again on coming back keeps what it showed until
  /// the answer is in.
  Future<void> _onLoaded(
    ProfileLoaded event,
    Emitter<ProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        identity: _repository.signIn(),
        status: state.status == ProfileStatus.loadFailed
            ? ProfileStatus.loading
            : state.status,
      ),
    );
    try {
      final profile = await _repository.profile();
      emit(state.copyWith(status: ProfileStatus.ready, profile: profile));
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.profileLoadFailed(error, stackTrace));
      emit(state.copyWith(status: ProfileStatus.loadFailed));
    }
  }

  /// The name field was left (its done key leaves it too). A second leave
  /// while the first name is still on its way finds the save in flight and
  /// does nothing; one after it finds the name already saved.
  Future<void> _onNameSubmitted(
    ProfileNameSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    if (state.saving) {
      return;
    }
    switch (DisplayName.check(event.raw)) {
      case DisplayNameAccepted(:final name):
        if (name.value != state.profile?.displayName) {
          await _save(name, emit);
        }
      // Nothing was saved and nothing is lost: an empty field over no
      // name is simply no name yet.
      case DisplayNameRefused(problem: DisplayNameProblem.empty)
          when state.profile == null:
        return;
      case DisplayNameRefused(:final problem):
        _notify(emit, _refusal(problem));
    }
  }

  Future<void> _save(DisplayName name, Emitter<ProfileState> emit) async {
    emit(state.copyWith(saving: true));
    try {
      final profile = await _repository.saveDisplayName(name);
      emit(state.copyWith(saving: false, profile: profile));
      _notify(emit, ProfileNotice.saved);
      unawaited(_analytics.displayNameChanged(NameChangeSource.profile));
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.profileSaveFailed(error, stackTrace));
      emit(state.copyWith(saving: false));
      _notify(emit, ProfileNotice.saveFailed);
    }
  }

  /// Tells the screen [notice] once, even when it is the same as the last.
  void _notify(Emitter<ProfileState> emit, ProfileNotice notice) =>
      emit(state.copyWith(notice: notice, noticeCount: state.noticeCount + 1));

  static ProfileNotice _refusal(DisplayNameProblem problem) =>
      switch (problem) {
        DisplayNameProblem.empty => ProfileNotice.nameEmpty,
        // The field stops at the limit, so only a name pasted with a tab,
        // a line separator or the like gets here; all say the name cannot
        // be used.
        DisplayNameProblem.tooLong ||
        DisplayNameProblem.controlCharacter ||
        DisplayNameProblem.layoutCharacter => ProfileNotice.nameRefused,
      };
}
