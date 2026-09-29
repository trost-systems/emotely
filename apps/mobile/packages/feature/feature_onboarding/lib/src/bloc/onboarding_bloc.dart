import 'dart:async';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/src/flow.dart';
import 'package:feature_onboarding/src/onboarding_store.dart';
import 'package:feature_onboarding/src/progress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:profile_repository/profile_repository.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Walks the user through the steps of [OnboardingFlow] (#204, ADR 0019).
///
/// Before sign-up, each move is kept on the device ([OnboardingStore]) the
/// moment it is made, so a restart resumes at the step reached; once every
/// step before sign-up is done, the router takes the user on to sign-up,
/// and this bloc shows nothing more. After a sign-in it runs once more: it
/// saves the name the device holds to the new account, or, for an account
/// that came in without one, asks for it — and then says where to go next.
///
/// Every step shown and left is reported through [OnboardingAnalytics],
/// which is never handed the name.
///
/// A skip names the user with one of the placeholder names the skip
/// carries, the screen's own words in the user's language. The one picked is
/// data from then on, the user's name like a typed one, and stays as picked
/// whatever language the phone speaks later.
class OnboardingBloc({
  required final OnboardingStore _store,
  required final ProfileRepository _profiles,
  required final OnboardingAnalytics _analytics,
  required final ErrorReporter _errors,
  final OnboardingFlow _flow = onboardingFlow,
  Random? random,
}) extends Bloc<OnboardingEvent, OnboardingState> {
  this : super(const OnboardingState.loading()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingNameChanged>(_onNameChanged);
    on<OnboardingContinued>(_onContinued);
    on<OnboardingSkipped>(_onSkipped);
    on<OnboardingBack>(_onBack);
    on<OnboardingRetried>((_, emit) => _finish(emit));
  }

  final Random _random = random ?? Random();

  var _phase = OnboardingPhase.beforeSignUp;

  /// How long the step on screen has been there.
  final _onScreen = Stopwatch();

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    _phase = event.phase;
    switch (_phase) {
      case OnboardingPhase.beforeSignUp:
        _show(emit);
      case OnboardingPhase.afterSignIn:
        await _finish(emit);
    }
  }

  Future<void> _onNameChanged(
    OnboardingNameChanged event,
    Emitter<OnboardingState> emit,
  ) async {
    if (state case final OnboardingShowing showing) {
      final progress = showing.progress.copyWith(draft: event.text);
      emit(
        showing.copyWith(progress: progress, problem: _problemWith(event.text)),
      );
      await _store.save(progress);
    }
  }

  Future<void> _onContinued(
    OnboardingContinued event,
    Emitter<OnboardingState> emit,
  ) async {
    final step = _stepOnScreen(event.step);
    if (step == null) {
      return;
    }
    final progress = _store.progress;
    if (step is NameStep && _problemWith(progress.draft) != null) {
      return;
    }
    _left(step, OnboardingStepAction.continued);
    await _forward(
      emit,
      step,
      step is NameStep ? progress.copyWith(placeholder: null) : progress,
    );
  }

  Future<void> _onSkipped(
    OnboardingSkipped event,
    Emitter<OnboardingState> emit,
  ) async {
    final step = _stepOnScreen(event.step);
    if (step is! NameStep) {
      return;
    }
    _left(step, OnboardingStepAction.skipped);
    final placeholder =
        event.placeholderNames[_random.nextInt(event.placeholderNames.length)];
    await _forward(
      emit,
      step,
      _store.progress.copyWith(placeholder: placeholder),
    );
  }

  Future<void> _onBack(
    OnboardingBack event,
    Emitter<OnboardingState> emit,
  ) async {
    final step = _stepOnScreen(event.step);
    final previous = step == null ? null : _flow.before(step);
    if (step == null || previous == null) {
      return;
    }
    _left(step, OnboardingStepAction.back);
    // Back from the greeting is back to the name: "Actually, I'll tell
    // you" takes the placeholder back with it.
    final progress = _store.progress;
    await _store.save(
      progress.copyWith(
        completed: {...progress.completed}..remove(previous.id),
        placeholder: null,
      ),
    );
    _show(emit);
  }

  /// Marks [step] done with [progress] and moves on: to the next step,
  /// or, once the phase is done, to what follows it.
  Future<void> _forward(
    Emitter<OnboardingState> emit,
    OnboardingStep step,
    OnboardingProgress progress,
  ) async {
    await _store.save(
      progress.copyWith(completed: {...progress.completed, step.id}),
    );
    switch (_phase) {
      case OnboardingPhase.beforeSignUp:
        _show(emit);
      case OnboardingPhase.afterSignIn:
        await _finish(emit);
    }
  }

  /// The step reached in this phase, on screen; or, before sign-up once
  /// every step is done, nothing: the router takes the user to sign-up.
  void _show(Emitter<OnboardingState> emit) {
    final progress = _store.progress;
    final step = _flow.current(_phase, progress);
    if (step == null) {
      emit(const OnboardingState.loading());
      return;
    }
    if (step is WelcomeStep && !progress.started) {
      unawaited(_store.save(progress.copyWith(started: true)));
      unawaited(_analytics.started(stepCount: _flow.of(_phase).length));
    }
    final counted = [
      for (final step in _flow.of(_phase))
        if (step.showsProgress) step,
    ];
    emit(
      OnboardingState.showing(
        step: step,
        progress: _store.progress,
        position: counted.indexOf(step),
        dots: counted.length,
        canGoBack: _flow.before(step) != null,
        problem: step is NameStep ? _problemWith(progress.draft) : null,
      ),
    );
    unawaited(_analytics.stepViewed(_flow.view(step)));
    _onScreen
      ..reset()
      ..start();
  }

  /// After a sign-in: the name this device holds goes to the account —
  /// the one typed before sign-up, or the one asked for just now — unless
  /// the account already has one it must not replace ([_replaces]), and the
  /// user goes on. Without one, an account that already has a name goes
  /// straight on, and one without is asked for it once. The device's name
  /// is forgotten either way.
  Future<void> _finish(Emitter<OnboardingState> emit) async {
    emit(const OnboardingState.loading());
    final progress = _store.progress;
    final next = _flow.readyForAccount(progress)
        ? OnboardingNext.session
        : _flow.current(OnboardingPhase.afterSignIn, progress) == null
        ? OnboardingNext.journal
        : null;
    // A name that does not pass the profile's rules was never let through
    // the field; one that fails them anyway (a store from an older build)
    // is asked for again rather than refused by the server.
    final name = switch (DisplayName.check(progress.displayName)) {
      DisplayNameAccepted(:final name) => name,
      DisplayNameRefused() => null,
    };
    if (next == null || name == null) {
      await _nameOrOn(emit);
      return;
    }
    emit(const OnboardingState.saving());
    final Profile? existing;
    try {
      existing = await _profiles.profile();
    } on Exception catch (error, stackTrace) {
      // Not knowing what the account holds must not overwrite it: the
      // user retries rather than the device's name winning blind.
      unawaited(_errors.profileLoadFailed(error, stackTrace));
      emit(const OnboardingState.saveFailed());
      return;
    }
    final replaces = _replaces(existing, progress);
    if (replaces && !await _saved(name, progress, emit)) {
      return;
    }
    unawaited(
      _analytics.completed(
        next: next,
        nameSource: replaces ? progress.nameSource : NameSource.existing,
      ),
    );
    await _store.clear();
    emit(OnboardingState.finished(next));
  }

  /// Whether the name the device holds in [progress] may replace what the
  /// account holds (#204): anything replaces no profile at all, a typed
  /// name replaces a placeholder, and nothing replaces a real name — a
  /// returning user who signs into their account from a fresh install
  /// keeps the name they gave it.
  static bool _replaces(Profile? existing, OnboardingProgress progress) =>
      existing == null ||
      (existing.nameIsPlaceholder && progress.nameSource == NameSource.typed);

  /// Saves [name] from [progress] to the account; on a refusal, reports
  /// it, offers a retry, and says it did not.
  Future<bool> _saved(
    DisplayName name,
    OnboardingProgress progress,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      await _profiles.saveDisplayName(
        name,
        isPlaceholder: progress.placeholder != null,
      );
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.profileSaveFailed(error, stackTrace));
      emit(const OnboardingState.saveFailed());
      return false;
    }
    unawaited(_analytics.displayNameChanged(NameChangeSource.onboarding));
    return true;
  }

  /// An account signed into without a usable name on this device: asked
  /// for its name if it has none. Not knowing counts as having one — the
  /// name is a nicety, and the user should not wait on it.
  Future<void> _nameOrOn(Emitter<OnboardingState> emit) async {
    bool named;
    try {
      named = await _profiles.profile() != null;
    } on Exception catch (error, stackTrace) {
      unawaited(_errors.profileLoadFailed(error, stackTrace));
      named = true;
    }
    if (!named) {
      _show(emit);
      return;
    }
    await _store.clear();
    emit(const OnboardingState.finished(OnboardingNext.journal));
  }

  /// What the profile would refuse about [raw], if anything.
  static DisplayNameProblem? _problemWith(String raw) =>
      switch (DisplayName.check(raw)) {
        DisplayNameAccepted() => null,
        DisplayNameRefused(:final problem) => problem,
      };

  /// The step on screen, if it is [id]; a move made on a step that has
  /// since been left does nothing.
  OnboardingStep? _stepOnScreen(OnboardingStepId id) => switch (state) {
    OnboardingShowing(:final step) when step.id == id => step,
    _ => null,
  };

  void _left(OnboardingStep step, OnboardingStepAction action) => unawaited(
    _analytics.stepCompleted(
      _flow.view(step),
      action: action,
      duration: _onScreen.elapsed,
    ),
  );
}
