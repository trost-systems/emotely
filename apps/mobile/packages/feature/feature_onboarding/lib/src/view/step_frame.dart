import 'package:feature_onboarding/src/l10n/onboarding_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The frame every step sits in: a bar with the way back and the dots,
/// the step's own content, and its buttons at the bottom.
///
/// The whole of it scrolls once it no longer fits — a small phone, or a
/// large text size — and fills the screen with the buttons at the bottom
/// while it does fit.
class const StepFrame({
  required final Widget child,
  required final List<Widget> actions,
  final VoidCallback? onBack,
  final int? position,
  final int? dots,
  super.key,
}) extends StatelessWidget {
  static const backKey = Key('onboarding.back');

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(onBack: onBack, position: position, dots: dots),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [child],
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The way back on the left, the dots in the middle; either may be absent.
class const _TopBar({
  required final VoidCallback? onBack,
  required final int? position,
  required final int? dots,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        SizedBox(
          width: 48,
          child: onBack == null
              ? null
              : IconButton(
                  key: StepFrame.backKey,
                  tooltip: OnboardingLocalizations.of(context).backTooltip,
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left),
                ),
        ),
        Expanded(
          child: switch ((position, dots)) {
            (final position?, final dots?) when position >= 0 => _Dots(
              position: position,
              dots: dots,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        const SizedBox(width: 48),
      ],
    ),
  );
}

/// Where the user is in the flow: one wide dot among narrow ones, read out
/// as "Step 2 of 3" in the user's language.
class const _Dots({required final int position, required final int dots})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: OnboardingLocalizations.of(context)
          .stepProgress(position + 1, dots),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            for (var dot = 0; dot < dots; dot++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: dot == position ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: dot == position
                      ? colors.primary
                      : colors.outlineVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The step's main button: full width, tall enough to hit.
class const PrimaryAction({
  required final String label,
  required final VoidCallback? onPressed,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    child: Text(label, textAlign: TextAlign.center),
  );
}

/// The quieter way on, under the main button.
class const SecondaryAction({
  required final String label,
  required final VoidCallback onPressed,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}

/// A step's heading and the line under it.
class const StepHeading({
  required final String title,
  final String? body,
  final TextAlign textAlign = TextAlign.start,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: textAlign,
            // Never italic: the greeting names the user, and a slanted name
            // reads as a quotation (#204).
            style: theme.textTheme.headlineMedium?.copyWith(
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
        if (body case final body?)
          Text(
            body,
            textAlign: textAlign,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
