import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/src/progress.dart';

/// One step of onboarding: a stable [id] that analytics and the device
/// store name it by, the [phase] it runs in, and when it counts as done
/// (#204, ADR 0019). A new kind of step is a new subtype; the order is data,
/// in an [OnboardingFlow].
sealed class const OnboardingStep() {
  OnboardingStepId get id;

  OnboardingPhase get phase;

  /// Whether the dots at the top count this step. The greeting after the
  /// name is the flow's end, not one more thing asked of the user.
  bool get showsProgress => true;

  /// A step is done once the user left it forward, by continuing or by
  /// skipping, and stays done until they come back to it.
  bool isDone(OnboardingProgress progress) => progress.completed.contains(id);
}

/// "Welcome to emotely": get started, or sign in to an account.
final class const WelcomeStep() extends OnboardingStep {
  @override
  OnboardingStepId get id => OnboardingStepId.welcome;

  @override
  OnboardingPhase get phase => OnboardingPhase.beforeSignUp;
}

/// Three promises: what a few minutes gets the user.
final class const ValueStep() extends OnboardingStep {
  @override
  OnboardingStepId get id => OnboardingStepId.value;

  @override
  OnboardingPhase get phase => OnboardingPhase.beforeSignUp;
}

/// "What should I call you?": one optional field. Before sign-up it keeps
/// the answer on the device; after a sign-in into an account without a
/// name it asks once more and saves straight to the profile.
final class const NameStep({
  @override required final OnboardingStepId id,
  @override required final OnboardingPhase phase,
}) extends OnboardingStep {
  /// The name step of a new user, before the account exists.
  static const beforeSignUp = NameStep(
    id: OnboardingStepId.name,
    phase: OnboardingPhase.beforeSignUp,
  );

  /// The name step for an account that came in without a name.
  static const afterSignIn = NameStep(
    id: OnboardingStepId.accountName,
    phase: OnboardingPhase.afterSignIn,
  );

  @override
  bool get showsProgress => phase == OnboardingPhase.beforeSignUp;
}

/// "Nice to meet you, {name}." — or, after a skip, the placeholder
/// announced: the last step before sign-up.
final class const HelloStep() extends OnboardingStep {
  @override
  OnboardingStepId get id => OnboardingStepId.hello;

  @override
  OnboardingPhase get phase => OnboardingPhase.beforeSignUp;

  @override
  bool get showsProgress => false;
}

/// One particular sequence of steps, named by its [version]: every
/// onboarding event carries it, and progress kept under another version
/// is started over rather than resumed.
class const OnboardingFlow({
  required final int version,
  required final List<OnboardingStep> steps,
});

/// The version of [onboardingFlow], for the app to hand to analytics.
const onboardingFlowVersion = 1;

/// The flow this build runs.
const onboardingFlow = OnboardingFlow(
  version: onboardingFlowVersion,
  steps: [
    WelcomeStep(),
    ValueStep(),
    NameStep.beforeSignUp,
    HelloStep(),
    NameStep.afterSignIn,
  ],
);

/// What the bloc and the router ask of a flow.
extension OnboardingFlowX on OnboardingFlow {
  /// The steps of [phase], in order.
  List<OnboardingStep> of(OnboardingPhase phase) => [
    for (final step in steps)
      if (step.phase == phase) step,
  ];

  /// The first step of [phase] not done yet, or none once all are.
  OnboardingStep? current(OnboardingPhase phase, OnboardingProgress progress) {
    for (final step in of(phase)) {
      if (!step.isDone(progress)) {
        return step;
      }
    }
    return null;
  }

  /// The step before [step] in its phase, if any.
  OnboardingStep? before(OnboardingStep step) {
    final phase = of(step.phase);
    final index = phase.indexOf(step);
    return index > 0 ? phase[index - 1] : null;
  }

  /// Whether every step before sign-up is done: the account is all that is
  /// left to ask for.
  bool readyForAccount(OnboardingProgress progress) =>
      current(OnboardingPhase.beforeSignUp, progress) == null;

  /// [step] as analytics reports it: its place in its phase.
  OnboardingStepView view(OnboardingStep step) => OnboardingStepView(
    id: step.id,
    index: of(step.phase).indexOf(step),
    phase: step.phase,
  );
}
