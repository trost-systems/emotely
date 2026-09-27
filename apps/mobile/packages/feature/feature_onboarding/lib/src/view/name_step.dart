import 'package:feature_onboarding/src/view/onboarding_text.dart';
import 'package:feature_onboarding/src/view/step_frame.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile_repository/profile_repository.dart';

/// "What should I call you?": one field, optional. Continue takes what is
/// typed once the profile would take it; skipping leaves the name for
/// later, and the companion picks a placeholder meanwhile.
class const NameStepView({
  required final String draft,
  required final DisplayNameProblem? problem,
  required final ValueChanged<String> onChanged,
  required final VoidCallback onContinue,
  required final VoidCallback onSkip,
  final VoidCallback? onBack,
  final int? position,
  final int? dots,
  super.key,
}) extends StatefulWidget {
  static const fieldKey = Key('onboarding.name.field');
  static const continueKey = Key('onboarding.name.continue');
  static const skipKey = Key('onboarding.name.skip');

  @override
  State<NameStepView> createState() => _NameStepViewState();
}

class _NameStepViewState() extends State<NameStepView> {
  late final _controller = TextEditingController(text: widget.draft);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _acceptable => widget.problem == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StepFrame(
      onBack: widget.onBack,
      position: widget.position,
      dots: widget.dots,
      actions: [
        PrimaryAction(
          key: NameStepView.continueKey,
          label: continueLabel,
          onPressed: _acceptable ? widget.onContinue : null,
        ),
        SecondaryAction(
          key: NameStepView.skipKey,
          label: skipLabel,
          onPressed: widget.onSkip,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 28,
        children: [
          const StepHeading(title: nameTitle, body: nameBody),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              TextField(
                key: NameStepView.fieldKey,
                controller: _controller,
                autofillHints: const [AutofillHints.givenName],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  labelText: nameLabel,
                  hintText: nameHint,
                  border: const OutlineInputBorder(),
                  errorText: _describe(widget.problem),
                  errorMaxLines: 3,
                ),
                onChanged: widget.onChanged,
                onSubmitted: (_) => _acceptable ? widget.onContinue() : null,
              ),
              const _NameUse(),
            ],
          ),
        ],
      ),
    );
  }

  /// An empty field needs no telling: Continue is simply not there yet.
  static String? _describe(DisplayNameProblem? problem) => switch (problem) {
    DisplayNameProblem.tooLong => nameTooLong,
    DisplayNameProblem.controlCharacter ||
    DisplayNameProblem.layoutCharacter => nameInvisibleCharacter,
    DisplayNameProblem.empty || null => null,
  };
}

/// What the name is for, with a lock: only for greeting.
class const _NameUse() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.lock_outline, size: 16, color: muted),
          ),
          Expanded(
            child: Text(
              nameUse,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
