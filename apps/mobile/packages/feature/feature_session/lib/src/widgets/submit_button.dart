import 'package:material_ui/material_ui.dart';

/// The one way an answer leaves its widget: disabled until the widget holds
/// a valid answer, so the agent never receives an empty one.
///
/// [buttonKey] names the button itself, not the full-width row that aligns
/// it: a driver that knows only the key (a test, the verification CLI) taps
/// the centre of what the key names, and the row's centre is empty space.
class const SubmitButton({
  required final VoidCallback? onPressed,
  required final Key buttonKey,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      child: const Text('Submit'),
    ),
  );
}
