import 'dart:async';

import 'package:contract/contract.dart';
import 'package:feature_session/src/widgets/submit_button.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A 1–10 rating on a slider, as the legacy app had it; submits
/// [Answer.rating].
///
/// The slider starts one stop left of 1, at "no answer", so that landing on
/// a value is always the user's act and never the widget's default. Sliding
/// back to that stop withdraws the answer.
class const RatingInput({
  required final ValueChanged<Answer> onSubmit,
  super.key,
}) extends StatefulWidget {
  static const sliderKey = Key('rating_input.slider');
  static const valueKey = Key('rating_input.value');
  static const submitKey = Key('rating_input.submit');

  /// Lowest and highest selectable values, as in the contract.
  static const min = ratingMin;
  static const max = ratingMax;

  /// What the value line reads while the slider rests on no answer.
  static const noAnswerLabel = 'No answer';

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState() extends State<RatingInput> {
  /// The value the slider rests on; null while it rests on "no answer".
  int? _value;

  void _slid(double position) {
    // Legacy feel: a tick under the finger at every stop.
    unawaited(HapticFeedback.selectionClick());
    final stop = position.round();
    setState(() => _value = stop < RatingInput.min ? null : stop);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          value?.toString() ?? RatingInput.noAnswerLabel,
          key: RatingInput.valueKey,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        Slider(
          key: RatingInput.sliderKey,
          value: (value ?? 0).toDouble(),
          max: RatingInput.max.toDouble(),
          // One stop per value, plus the "no answer" stop at 0.
          divisions: RatingInput.max,
          label: value?.toString() ?? RatingInput.noAnswerLabel,
          semanticFormatterCallback: (position) => position.round() == 0
              ? RatingInput.noAnswerLabel
              : position.round().toString(),
          onChanged: _slid,
        ),
        SubmitButton(
          buttonKey: RatingInput.submitKey,
          onPressed: switch (value) {
            null => null,
            final value => () => widget.onSubmit(Answer.rating(value)),
          },
        ),
      ],
    );
  }
}
