import 'package:analytics/src/post_hog_gate.dart';

/// A step of onboarding by its stable id: what `step_id` says in every
/// onboarding event, and what the device keeps to resume at the step
/// reached. Renaming a value's [wire] name breaks every funnel built on it,
/// so a changed step is a new value, never a renamed one (#204).
enum OnboardingStepId(final String wire) {
  /// "Welcome to emotely": get started, or sign in.
  welcome('welcome'),

  /// What a few minutes gets you: three promises.
  value('value'),

  /// "What should I call you?", before sign-up.
  name('name'),

  /// "Nice to meet you", or the placeholder announced after a skip.
  hello('hello'),

  /// The name step once more, after a sign-in into an account without one.
  accountName('account_name'),
}

/// When a step runs: on the device before any account exists, or once
/// after a sign-in.
enum OnboardingPhase(final String wire) {
  beforeSignUp('before_sign_up'),
  afterSignIn('after_sign_in'),
}

/// How the user left a step.
enum OnboardingStepAction(final String wire) {
  /// Forward, having done what the step asked.
  continued('continue'),

  /// Forward, without doing it (the name, left for later).
  skipped('skip'),

  /// Back to the step before.
  back('back'),
}

/// Where onboarding led once the account existed.
enum OnboardingNext() {
  /// Straight into the first session (a new account, at sign-up).
  session,

  /// To the journal (a sign-in that needed the name step once).
  journal,
}

/// Where the display name came from. Never the name itself (ADR 0005).
enum NameSource() {
  /// The user typed it.
  typed,

  /// The app picked it on "Skip for now".
  placeholder,

  /// The account already had a name, which the one on the device never
  /// replaces: a real name beats anything, and a placeholder replaces
  /// nothing (#204).
  existing,
}

/// Where the display name was changed.
enum NameChangeSource() {
  /// Saved to the new account at the end of onboarding.
  onboarding,

  /// Edited on the Profile screen.
  profile,
}

/// A step as it was shown: which one, where it sits in its [phase]
/// (0-based), and the phase.
class const OnboardingStepView({
  required final OnboardingStepId id,
  required final int index,
  required final OnboardingPhase phase,
});

/// Onboarding analytics, content-free by construction (ADR 0005): step ids,
/// positions, actions, durations and where the flow led — never a word the
/// user typed. The methods take enums, numbers and durations only, so the
/// name the user gives on the name step cannot be handed to them: there is
/// no parameter a string could go into (#204).
///
/// Every event carries the [flowVersion], so a funnel can tell one
/// sequence of steps from the next, and the experiment variant, which is
/// always [variant] until there are users enough to experiment on.
class const OnboardingAnalytics({
  required final PostHogGate gate,

  /// The version of the flow the app runs; the flow's package owns the
  /// constant, this one only reports it.
  required final int flowVersion,
}) {
  /// The only variant there is: no experiment runs yet.
  static const variant = 'control';

  /// A fresh onboarding of [stepCount] steps began on this device.
  Future<void> started({required int stepCount}) => _afterTheQuestion(
    'onboarding_started',
    {..._flow, 'step_count': stepCount},
  );

  /// [step] came on screen.
  Future<void> stepViewed(OnboardingStepView step) =>
      _afterTheQuestion('onboarding_step_viewed', {..._flow, ..._step(step)});

  /// The user left [step] by [action], [duration] after it came on screen.
  Future<void> stepCompleted(
    OnboardingStepView step, {
    required OnboardingStepAction action,
    required Duration duration,
  }) => gate.capture(
    eventName: 'onboarding_step_completed',
    properties: {
      ..._flow,
      ..._step(step),
      'action': action.wire,
      'duration_ms': duration.inMilliseconds,
    },
  );

  /// Onboarding is over: the account holds the name, from [nameSource], and
  /// the user goes on to [next].
  Future<void> completed({
    required OnboardingNext next,
    required NameSource nameSource,
  }) => gate.capture(
    eventName: 'onboarding_completed',
    properties: {..._flow, 'next': next.name, 'name_source': nameSource.name},
  );

  /// The profile's display name was saved from [source].
  Future<void> displayNameChanged(NameChangeSource source) => gate.capture(
    eventName: 'display_name_changed',
    properties: {..._flow, 'source': source.name},
  );

  Map<String, Object> get _flow => {
    'flow_version': flowVersion,
    'variant': variant,
  };

  static Map<String, Object> _step(OnboardingStepView step) => {
    'step_id': step.id.wire,
    'step_index': step.index,
    'phase': step.phase.wire,
  };

  /// Completes once the usage-analytics question has an answer, "Allow" or
  /// "Don't allow": soon after the call on a launch that already has one,
  /// else when the sheet over the first screens is answered. The views of
  /// those screens wait for it, and so does the clock of the step on
  /// screen, so a step's duration never counts the time under the sheet
  /// (#225).
  Future<void> get answered async {
    await gate.settled;
    if (gate.choice == null) {
      await gate.changes.firstWhere((choice) => choice != null);
    }
  }

  /// The first screens come up under the usage-analytics sheet, before
  /// anyone could have allowed anything; captured then, they would be
  /// dropped by the shut gate and the funnel would lose its top. So they
  /// wait for the [answered] question: sent once it is "Allow", dropped by
  /// the gate on "Don't allow".
  Future<void> _afterTheQuestion(
    String eventName,
    Map<String, Object> properties,
  ) async {
    await answered;
    await gate.capture(eventName: eventName, properties: properties);
  }
}
