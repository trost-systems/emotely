import 'package:feature_onboarding/src/l10n/l10n.dart';
import 'package:feature_onboarding/src/view/art.dart';
import 'package:feature_onboarding/src/view/step_frame.dart';
import 'package:material_ui/material_ui.dart';

/// The last step before sign-up: "Nice to meet you, {name}." for a typed
/// name, and one button on to the first reflection.
class const HelloStepView({
  required final String name,
  required final VoidCallback onStart,
  super.key,
}) extends StatelessWidget {
  static const startKey = Key('onboarding.hello.start');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.l10n;
    return StepFrame(
      actions: [
        PrimaryAction(
          key: startKey,
          label: strings.startReflectionButton,
          onPressed: onStart,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 28,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: colors.primaryContainer,
              child: Text(
                name.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: colors.onPrimaryContainer),
              ),
            ),
          ),
          StepHeading(title: strings.helloTitle(name), body: strings.helloBody),
        ],
      ),
    );
  }
}

/// The same step after a skip: the placeholder announced, playfully, with a
/// way back to the field.
class const SkippedStepView({
  required final String placeholder,
  required final VoidCallback onStart,
  required final VoidCallback onTellYou,
  super.key,
}) extends StatelessWidget {
  static const startKey = Key('onboarding.skipped.start');
  static const tellYouKey = Key('onboarding.skipped.tell_you');

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return StepFrame(
      actions: [
        PrimaryAction(
          key: startKey,
          label: strings.startReflectionButton,
          onPressed: onStart,
        ),
        SecondaryAction(
          key: tellYouKey,
          label: strings.tellYouButton,
          onPressed: onTellYou,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 28,
        children: [
          const PebbleArt(),
          StepHeading(
            title: strings.skippedTitle,
            body: strings.skippedBody(placeholder),
          ),
        ],
      ),
    );
  }
}
