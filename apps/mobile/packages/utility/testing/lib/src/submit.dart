import 'package:contract/contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Whether the submit button [key] names is enabled. The key sits on the
/// button itself, never on the full-width row that aligns it.
bool isSubmitEnabled(WidgetTester tester, Key key) =>
    tester.widget<FilledButton>(find.byKey(key)).onPressed != null;

/// Taps the submit button [key] names and pumps one frame.
Future<void> tapSubmit(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
}

/// Collects what an answer widget submits.
class Submitted() {
  final answers = <Answer>[];

  void call(Answer answer) => answers.add(answer);

  Answer get single => answers.single;
}

/// An `onSubmit` for accessibility pumps that only need a valid widget.
void ignoreAnswer(Answer _) {}
