part of 'onboarding_bloc.dart';

/// What the onboarding screen can tell [OnboardingBloc].
///
/// The moves name the step they were made on, so a double tap that lands
/// twice on one step moves once rather than past the next step unseen.
///
/// No generated `toString`: a name change carries the name being typed,
/// and a `BlocObserver` printing an event must never print it (ADR 0005).
@Freezed(toStringOverride: false)
sealed class OnboardingEvent with _$OnboardingEvent {
  /// Show the step reached in [phase]: before sign-up, or once more after a
  /// sign-in, which first saves any name the device holds.
  const factory started(OnboardingPhase phase) = OnboardingStarted;

  /// The name field now holds [text].
  const factory nameChanged(String text) = OnboardingNameChanged;

  /// Forward from [step], having done what it asked.
  const factory continued(OnboardingStepId step) = OnboardingContinued;

  /// Forward from [step] without doing it: the name, left for later. The
  /// user is named with one of [placeholderNames], the screen's own words in
  /// the user's language; the one picked is data from then on.
  const factory skipped(
    OnboardingStepId step, {
    required List<String> placeholderNames,
  }) = OnboardingSkipped;

  /// Back from [step] to the one before.
  const factory back(OnboardingStepId step) = OnboardingBack;

  /// Try saving the name again.
  const factory retried() = OnboardingRetried;
}
