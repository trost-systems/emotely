import 'package:contract/contract.dart';
import 'package:feature_session/src/widgets/color_input.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testing/testing.dart';

import '../session_strings.dart';

void main() {
  group(ColorInput, () {
    Future<Submitted> pumpTestWidget(WidgetTester tester) async {
      final submitted = Submitted();
      await tester.pumpApp(
        ColorInput(onSubmit: submitted.call),
        localizations: sessionLocalizations,
      );
      return submitted;
    }

    final dialog = find.byType(AlertDialog);

    Future<void> openSlot(WidgetTester tester, int index) async {
      await tester.tap(find.byKey(ColorInput.slotKey(index)));
      await tester.pumpAndSettle();
    }

    /// Taps [color] on the picker's Material swatch page.
    Future<void> choose(WidgetTester tester, Color color) async {
      await tester.tap(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is ColorIndicator &&
                  widget.color.toARGB32() == color.toARGB32(),
            )
            .first,
      );
      await tester.pump();
    }

    Future<void> tapInDialog(WidgetTester tester, Key key) async {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, int slot, Color color) async {
      await openSlot(tester, slot);
      await choose(tester, color);
      await tapInDialog(tester, ColorInput.selectKey);
    }

    testWidgets('starts with one empty slot and submit disabled', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      expect(find.byKey(ColorInput.slotKey(0)), findsOneWidget);
      expect(find.byKey(ColorInput.slotKey(1)), findsNothing);
      expect(
        find.bySemanticsLabel(tester.strings.colorPickLabel),
        findsOneWidget,
      );
      expect(isSubmitEnabled(tester, ColorInput.submitKey), isFalse);
    });

    testWidgets('picking a color fills the slot and opens the next', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      await pick(tester, 0, Colors.red);

      expect(dialog, findsNothing);
      expect(find.byKey(ColorInput.slotKey(1)), findsOneWidget);
      expect(find.bySemanticsLabel('#F44336'), findsOneWidget);
      expect(isSubmitEnabled(tester, ColorInput.submitKey), isTrue);
    });

    testWidgets('canceling the picker leaves the slot empty', (tester) async {
      await pumpTestWidget(tester);
      await openSlot(tester, 0);
      await choose(tester, Colors.red);

      await tapInDialog(tester, ColorInput.cancelKey);

      expect(dialog, findsNothing);
      expect(find.byKey(ColorInput.slotKey(1)), findsNothing);
      expect(isSubmitEnabled(tester, ColorInput.submitKey), isFalse);
    });

    testWidgets('a filled slot can be given another color', (tester) async {
      final submitted = await pumpTestWidget(tester);
      await pick(tester, 0, Colors.red);

      await pick(tester, 0, Colors.green);

      expect(find.bySemanticsLabel('#4CAF50'), findsOneWidget);
      expect(find.bySemanticsLabel('#F44336'), findsNothing);
      await tapSubmit(tester, ColorInput.submitKey);
      // The picker hands back plain colors, not the swatch it took them from.
      expect(submitted.single, const Answer.color([Color(0xFF4CAF50)]));
    });

    testWidgets('a filled slot can be cleared, and the empty one is not', (
      tester,
    ) async {
      await pumpTestWidget(tester);
      await pick(tester, 0, Colors.red);
      await pick(tester, 1, Colors.green);

      await openSlot(tester, 0);
      await tapInDialog(tester, ColorInput.clearKey);

      expect(find.bySemanticsLabel('#F44336'), findsNothing);
      expect(find.bySemanticsLabel('#4CAF50'), findsOneWidget);
      expect(find.byKey(ColorInput.slotKey(2)), findsNothing);

      await openSlot(tester, 1);

      expect(find.byKey(ColorInput.clearKey), findsNothing);
    });

    testWidgets('submits the colors in slot order', (tester) async {
      final submitted = await pumpTestWidget(tester);
      await pick(tester, 0, Colors.red);
      await pick(tester, 1, Colors.green);

      await tapSubmit(tester, ColorInput.submitKey);

      expect(
        submitted.single,
        const Answer.color([Color(0xFFF44336), Color(0xFF4CAF50)]),
      );
    });

    testWidgets('the picker words its own title, pages and buttons', (
      tester,
    ) async {
      await pumpTestWidget(tester);
      await pick(tester, 0, Colors.red);
      await openSlot(tester, 0);

      final strings = tester.strings;
      for (final text in [
        strings.colorPickLabel,
        strings.colorSwatchesTab,
        strings.colorWheelTab,
        strings.colorCancelButton,
        strings.colorClearButton,
        strings.colorSelectButton,
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(
          const ColorInput(onSubmit: ignoreAnswer),
          localizations: sessionLocalizations,
        ),
        prepare: (tester) => pick(tester, 0, Colors.red),
      );
    });
  });
}
