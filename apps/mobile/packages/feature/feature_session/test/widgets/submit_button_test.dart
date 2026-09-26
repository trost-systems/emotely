import 'package:feature_session/src/widgets/submit_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testing/testing.dart';

void main() {
  group(SubmitButton, () {
    const key = Key('submit');

    testWidgets('carries its key on the button, so a tap on the key lands', (
      tester,
    ) async {
      var pressed = 0;
      // Full width, as every answer widget lays it out.
      await tester.pumpApp(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SubmitButton(buttonKey: key, onPressed: () => pressed++)],
        ),
      );

      // A driver that knows only the key taps the centre of what it names.
      await tester.tapAt(tester.getCenter(find.byKey(key)));

      expect(tester.widget(find.byKey(key)), isA<FilledButton>());
      expect(pressed, 1);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(const SubmitButton(buttonKey: key, onPressed: null)),
      );
    });
  });
}
