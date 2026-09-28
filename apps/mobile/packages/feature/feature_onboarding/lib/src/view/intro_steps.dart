import 'package:feature_onboarding/src/l10n/onboarding_localizations.dart';
import 'package:feature_onboarding/src/view/art.dart';
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
  Widget build(BuildContext context) {
    final strings = OnboardingLocalizations.of(context);
    return StepFrame(
      position: position,
      dots: dots,
      actions: [
        PrimaryAction(
          key: getStartedKey,
          label: strings.getStartedButton,
          onPressed: onGetStarted,
        ),
        SecondaryAction(
          key: haveAccountKey,
          label: strings.haveAccountButton,
          onPressed: onHaveAccount,
        ),
      ],
      child: Column(
        spacing: 36,
        children: [
          const SunriseArt(),
          StepHeading(
            title: strings.welcomeTitle,
            body: strings.welcomeBody,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final strings = OnboardingLocalizations.of(context);
    return StepFrame(
      onBack: onBack,
      position: position,
      dots: dots,
      actions: [
        PrimaryAction(
          key: continueKey,
          label: strings.continueButton,
          onPressed: onContinue,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: [
          StepHeading(title: strings.valueTitle),
          _Promise(
            icon: Icons.chat_bubble_outline,
            title: strings.guidedPromiseTitle,
            body: strings.guidedPromiseBody,
          ),
          _Promise(
            icon: Icons.palette_outlined,
            title: strings.answerPromiseTitle,
            body: strings.answerPromiseBody,
          ),
          _Promise(
            icon: Icons.menu_book_outlined,
            title: strings.journalPromiseTitle,
            body: strings.journalPromiseBody,
          ),
        ],
      ),
    );
  }
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
