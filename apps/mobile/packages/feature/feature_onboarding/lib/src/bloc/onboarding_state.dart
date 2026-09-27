part of 'onboarding_bloc.dart';

/// What the onboarding screen shows.
///
/// No generated `toString`: a step on screen carries the progress, and
/// with it the name the user typed (ADR 0005).
@Freezed(toStringOverride: false)
sealed class OnboardingState with _$OnboardingState {
  /// Nothing to show: the account is being looked at, or the router is
  /// about to take the user on to sign-up or past onboarding.
  const factory loading() = OnboardingLoading;

  /// The name is being saved to the new account.
  const factory saving() = OnboardingSaving;

  /// [step] is on screen with the [progress] so far. The step is dot
  /// [position] of [dots] when it shows progress at all, and [canGoBack]
  /// when there is a step before it. [problem] is what
  /// is wrong with the typed name, if anything.
  const factory showing({
    required OnboardingStep step,
    required OnboardingProgress progress,
    required int position,
    required int dots,
    required bool canGoBack,
    DisplayNameProblem? problem,
  }) = OnboardingShowing;

  /// The name could not be saved to the new account; the screen offers a
  /// retry.
  const factory saveFailed() = OnboardingSaveFailed;

  /// Onboarding is over for the signed-in user, who goes on to [next].
  const factory finished(OnboardingNext next) = OnboardingFinished;
}
