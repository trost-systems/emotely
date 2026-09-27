import 'package:feature_onboarding/src/view/art.dart';
import 'package:feature_onboarding/src/view/onboarding_text.dart';
import 'package:feature_onboarding/src/view/step_frame.dart';
import 'package:material_ui/material_ui.dart';

/// Welcome: what emotely is, in one line, and the two ways on — the flow,
/// or straight to sign-in for someone who has an account.
class const WelcomeStepView({
  required final VoidCallback onGetStarted,
  required final VoidCallback onHaveAccount,
  required final int position,
  required final int dots,
  super.key,
}) extends StatelessWidget {
  static const getStartedKey = Key('onboarding.welcome.get_started');
  static const haveAccountKey = Key('onboarding.welcome.have_account');

  @override
  Widget build(BuildContext context) => StepFrame(
    position: position,
    dots: dots,
    actions: [
      PrimaryAction(
        key: getStartedKey,
        label: getStartedLabel,
        onPressed: onGetStarted,
      ),
      SecondaryAction(
        key: haveAccountKey,
        label: haveAccountLabel,
        onPressed: onHaveAccount,
      ),
    ],
    child: const Column(
      spacing: 36,
      children: [
        SunriseArt(),
        StepHeading(
          title: welcomeTitle,
          body: welcomeBody,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// What a few minutes gets the user: three promises, each with its mark.
class const ValueStepView({
  required final VoidCallback onContinue,
  required final VoidCallback onBack,
  required final int position,
  required final int dots,
  super.key,
}) extends StatelessWidget {
  static const continueKey = Key('onboarding.value.continue');

  static const _icons = [
    Icons.chat_bubble_outline,
    Icons.palette_outlined,
    Icons.menu_book_outlined,
  ];

  @override
  Widget build(BuildContext context) => StepFrame(
    onBack: onBack,
    position: position,
    dots: dots,
    actions: [
      PrimaryAction(
        key: continueKey,
        label: continueLabel,
        onPressed: onContinue,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 32,
      children: [
        const StepHeading(title: valueTitle),
        for (final (index, promise) in promises.indexed)
          _Promise(
            icon: _icons[index],
            title: promise.title,
            body: promise.body,
          ),
      ],
    ),
  );
}

class const _Promise({
  required final IconData icon,
  required final String title,
  required final String body,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primaryContainer,
            child: Icon(icon, color: colors.onPrimaryContainer),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
