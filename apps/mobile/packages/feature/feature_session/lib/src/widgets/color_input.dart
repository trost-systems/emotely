import 'dart:async';

import 'package:contract/contract.dart';
import 'package:feature_session/src/widgets/submit_button.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:material_ui/material_ui.dart';

/// A row of color circles, as the legacy app had it; submits [Answer.color]
/// in slot order.
///
/// There is always one empty slot at the end: tapping it opens the picker
/// and a chosen color fills it, so the row grows as colors are picked.
/// Tapping a filled slot reopens the picker on that color, to change it
/// or clear it.
class const ColorInput({
  required final ValueChanged<Answer> onSubmit,
  super.key,
}) extends StatefulWidget {
  static const submitKey = Key('color_input.submit');
  static const selectKey = Key('color_input.select');
  static const clearKey = Key('color_input.clear');
  static const cancelKey = Key('color_input.cancel');

  /// Key of the [index]th slot; the last one is always empty.
  static Key slotKey(int index) => Key('color_input.slot.$index');

  /// What the empty slot, and the picker, are called.
  static const pickLabel = 'Pick a color';

  @override
  State<ColorInput> createState() => _ColorInputState();
}

class _ColorInputState() extends State<ColorInput> {
  static const _converter = HexColorConverter();
  final _colors = <Color>[];

  Future<void> _open(int index) async {
    final current = index < _colors.length ? _colors[index] : null;
    final pick = await showDialog<_ColorPick>(
      context: context,
      builder: (_) => _ColorPickerDialog(current: current),
    );
    setState(() {
      switch (pick) {
        case null:
          break;
        case _Cleared():
          _colors.removeAt(index);
        case _Selected(:final color) when current == null:
          _colors.add(color);
        case _Selected(:final color):
          _colors[index] = color;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (index, color) in _colors.indexed)
            _Slot(
              key: ColorInput.slotKey(index),
              color: color,
              label: _converter.toJson(color),
              onTap: () => unawaited(_open(index)),
            ),
          _Slot(
            key: ColorInput.slotKey(_colors.length),
            color: null,
            label: ColorInput.pickLabel,
            onTap: () => unawaited(_open(_colors.length)),
          ),
        ],
      ),
      SubmitButton(
        buttonKey: ColorInput.submitKey,
        onPressed: _colors.isEmpty
            ? null
            : () => widget.onSubmit(Answer.color(List.of(_colors))),
      ),
    ],
  );
}

/// One circle: a picked color, or the outlined "+" that picks the next.
class const _Slot({
  required final Color? color,
  required final String label,
  required final VoidCallback onTap,
  super.key,
}) extends StatelessWidget {
  static const _size = 48.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: _size,
          height: _size,
          decoration: ShapeDecoration(
            color: color,
            shape: CircleBorder(
              side: color == null
                  ? BorderSide(color: scheme.outline, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: color == null
              ? ExcludeSemantics(
                  child: Icon(Icons.add, color: scheme.onSurface),
                )
              : null,
        ),
      ),
    );
  }
}

/// What the picker dialog came back with; dismissing it returns nothing.
sealed class const _ColorPick();

class const _Selected(final Color color) extends _ColorPick;

class const _Cleared() extends _ColorPick;

/// The legacy app's picker: a hue wheel and the Material swatches, with
/// Select, Cancel and — for a slot that already has a color — Clear.
class const _ColorPickerDialog({required final Color? current})
    extends StatefulWidget {
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState() extends State<_ColorPickerDialog> {
  /// A Material orange rather than the brand seed: the picker opens on the
  /// page that holds its color, and a swatch color opens the swatches, a
  /// free color the wheel — swatches first is the quicker start.
  late Color _picked = widget.current ?? Colors.orange;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(ColorInput.pickLabel),
    content: SingleChildScrollView(
      child: ColorPicker(
        color: _picked,
        onColorChanged: (color) => setState(() => _picked = color),
        pickersEnabled: const {
          ColorPickerType.accent: false,
          ColorPickerType.wheel: true,
        },
        padding: EdgeInsets.zero,
        width: 36,
        height: 36,
        borderRadius: 18,
        wheelDiameter: 180,
      ),
    ),
    actions: [
      TextButton(
        key: ColorInput.cancelKey,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      if (widget.current != null)
        TextButton(
          key: ColorInput.clearKey,
          onPressed: () => Navigator.of(context).pop(const _Cleared()),
          child: const Text('Clear'),
        ),
      FilledButton(
        key: ColorInput.selectKey,
        onPressed: () => Navigator.of(context).pop(_Selected(_picked)),
        child: const Text('Select'),
      ),
    ],
  );
}
