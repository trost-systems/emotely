import 'package:contract/contract.dart';
import 'package:feature_session/src/widgets/answer_length.dart';
import 'package:feature_session/src/widgets/submit_button.dart';
import 'package:material_ui/material_ui.dart';

/// Several short items, one field each, as the legacy app had it; submits
/// [Answer.textList].
///
/// There is always one empty field at the end: writing in it opens the
/// next, so a list grows as it is written and never needs an "add". A
/// field emptied and then left closes again, so the list never keeps a
/// hole the user walked away from.
class const TextListInput({
  required final ValueChanged<Answer> onSubmit,
  super.key,
}) extends StatefulWidget {
  static const submitKey = Key('text_list_input.submit');

  /// Key of the [index]th field.
  static Key fieldKey(int index) => Key('text_list_input.field.$index');

  @override
  State<TextListInput> createState() => _TextListInputState();
}

class _TextListInputState() extends State<TextListInput> {
  final _fields = <_Field>[];

  List<String> get _items => [
    for (final field in _fields)
      if (field.text.isNotEmpty) field.text,
  ];

  Answer get _answer => Answer.textList(_items);

  bool get _submittable => _items.isNotEmpty && _answer.fits;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _open() {
    final field = _Field();
    field.focus.addListener(() => _left(field));
    _fields.add(field);
  }

  /// The last field has been written in: open the next one.
  void _changed(_Field field) {
    setState(() {
      if (field == _fields.last && field.text.isNotEmpty) {
        _open();
      }
    });
  }

  /// A field lost focus: if it is empty and not the last, close it. The
  /// controller and node are disposed once the frame that drops them has
  /// been built, not inside the notification that is still using them.
  void _left(_Field field) {
    if (field.focus.hasFocus ||
        field.text.isNotEmpty ||
        field == _fields.last) {
      return;
    }
    setState(() => _fields.remove(field));
    WidgetsBinding.instance.addPostFrameCallback((_) => field.dispose());
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      for (final (index, field) in _fields.indexed)
        TextField(
          key: TextListInput.fieldKey(index),
          controller: field.controller,
          focusNode: field.focus,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Write one thing…'),
          onChanged: (_) => _changed(field),
          onSubmitted: (_) => _fields[index + 1].focus.requestFocus(),
        ),
      AnswerLength(answer: _answer),
      SubmitButton(
        buttonKey: TextListInput.submitKey,
        onPressed: _submittable ? () => widget.onSubmit(_answer) : null,
      ),
    ],
  );
}

/// One item's controller and focus node, which live and die together.
class _Field() {
  final controller = TextEditingController();
  final focus = FocusNode();

  String get text => controller.text.trim();

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
