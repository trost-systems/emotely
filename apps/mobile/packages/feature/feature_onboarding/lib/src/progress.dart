import 'package:analytics/analytics.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'progress.freezed.dart';

/// How far this device got through onboarding before an account existed:
/// the steps left forward, what was typed into the name field, and the
/// placeholder picked on a skip (#204, ADR 0019). Kept on the device, which
/// is technically necessary storage for a flow the user is walking; it
/// moves to the profile once the account exists and is cleared then.
///
/// No generated `toString`: the draft is the name the user typed, and a
/// `BlocObserver` or an error log printing a state must never print it
/// (ADR 0005).
@Freezed(toStringOverride: false)
abstract class OnboardingProgress with _$OnboardingProgress {
  /// Progress with [completed] steps left forward; [draft] as typed into
  /// the name field; [placeholder] once the name was skipped; [started]
  /// once `onboarding_started` went out for this run of the flow.
  const factory({
    @Default(<OnboardingStepId>{}) Set<OnboardingStepId> completed,
    @Default('') String draft,
    String? placeholder,
    @Default(false) bool started,
  }) = _OnboardingProgress;
}

/// What the flow makes of the progress.
extension OnboardingProgressX on OnboardingProgress {
  /// The name the user will be greeted by: the placeholder after a skip,
  /// what they typed otherwise.
  String get displayName => placeholder ?? draft.trim();

  /// Where that name came from.
  NameSource get nameSource =>
      placeholder == null ? NameSource.typed : NameSource.placeholder;
}
