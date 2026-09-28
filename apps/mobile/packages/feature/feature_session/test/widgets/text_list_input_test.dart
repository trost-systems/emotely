import 'package:contract/contract.dart';
import 'package:feature_session/src/l10n/session_localizations.dart';
import 'package:feature_session/src/widgets/text_list_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testing/testing.dart';

import '../session_strings.dart';

void main() {
  group(TextListInput, () {
    Future<Submitted> pumpTestWidget(WidgetTester tester) async {
      final submitted = Submitted();
      await tester.pumpApp(
        TextListInput(onSubmit: submitted.call),
        localizations: sessionLocalizations,
      );
      return submitted;
    }

    Future<void> type(WidgetTester tester, int index, String text) async {
      await tester.enterText(find.byKey(TextListInput.fieldKey(index)), text);
      await tester.pump();
    }

    final fields = find.byType(TextField);

    testWidgets('starts with one empty field and submit disabled', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      expect(fields, findsOneWidget);
      expect(isSubmitEnabled(tester, TextListInput.submitKey), isFalse);
    });

    testWidgets('writing in the last field opens another one below it', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      await type(tester, 0, 'my wife');

      expect(fields, findsNWidgets(2));
      expect(isSubmitEnabled(tester, TextListInput.submitKey), isTrue);

      await type(tester, 1, 'Flutter');

      expect(fields, findsNWidgets(3));
    });

    testWidgets('submits every filled field, trimmed, in order', (
      tester,
    ) async {
      final submitted = await pumpTestWidget(tester);
      await type(tester, 0, ' my wife ');
      await type(tester, 1, 'Flutter');

      await tapSubmit(tester, TextListInput.submitKey);

      expect(submitted.single, const Answer.textList(['my wife', 'Flutter']));
    });

    testWidgets('a field emptied and left behind closes', (tester) async {
      await pumpTestWidget(tester);
      await type(tester, 0, 'my wife');
      await type(tester, 1, 'Flutter');

      await type(tester, 0, '');
      // Still open while the caret is in it: emptying is not yet leaving.
      expect(fields, findsNWidgets(3));

      await tester.tap(find.byKey(TextListInput.fieldKey(2)));
      await tester.pump();

      expect(fields, findsNWidgets(2));
      expect(
        tester
            .widget<TextField>(find.byKey(TextListInput.fieldKey(0)))
            .controller
            ?.text,
        'Flutter',
      );
    });

    testWidgets('the keyboard action moves on to the next field', (
      tester,
    ) async {
      await pumpTestWidget(tester);
      await type(tester, 0, 'my wife');

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(TextListInput.fieldKey(1)))
            .focusNode
            ?.hasFocus,
        isTrue,
      );
    });

    testWidgets('the limit is on the whole list, punctuation included', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      // ["…","…"]: two items of 2045 letters, four quotes, a comma and two
      // brackets come to 4097, one past the limit.
      await type(tester, 0, 'a' * 2045);
      await type(tester, 1, 'a' * 2045);

      expect(isSubmitEnabled(tester, TextListInput.submitKey), isFalse);
      expect(find.text(tester.strings.answerLengthOver(1)), findsOneWidget);

      await type(tester, 1, 'a' * 2044);

      expect(isSubmitEnabled(tester, TextListInput.submitKey), isTrue);
      expect(find.text(tester.strings.answerLengthLeft(0)), findsOneWidget);
    });

    testWidgets('speaks German', (tester) async {
      const german = Locale('de');
      final strings = lookupSessionLocalizations(german);
      await tester.pumpApp(
        const TextListInput(onSubmit: ignoreAnswer),
        localizations: sessionLocalizations,
        locale: german,
      );

      expect(find.text(strings.textListHint), findsOneWidget);

      // ["…"]: 4090 letters, two quotes and two brackets, two short.
      await type(tester, 0, 'a' * 4090);

      expect(find.text(strings.answerLengthLeft(2)), findsOneWidget);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(
          const TextListInput(onSubmit: ignoreAnswer),
          localizations: sessionLocalizations,
        ),
        prepare: (tester) => type(tester, 0, 'my wife'),
      );
    });
  });
}
