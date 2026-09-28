import 'package:contract/contract.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:feature_session/src/l10n/session_localizations.dart';
import 'package:feature_session/src/widgets/emoji_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:testing/testing.dart';

import '../session_strings.dart';

void main() {
  group(EmojiInput, () {
    setUp(() {
      // The picker keeps its recents here; seeded so it loads without a
      // platform channel.
      SharedPreferences.setMockInitialValues({});
    });

    Future<Submitted> pumpTestWidget(WidgetTester tester) async {
      final submitted = Submitted();
      await tester.pumpApp(
        EmojiInput(onSubmit: submitted.call),
        localizations: sessionLocalizations,
      );
      return submitted;
    }

    final picker = find.byType(EmojiPicker);
    final clear = find.byKey(EmojiInput.clearKey);

    Future<void> openSlot(WidgetTester tester, int index) async {
      await tester.tap(find.byKey(EmojiInput.slotKey(index)));
      await tester.pumpAndSettle();
    }

    /// Taps [emoji] on the picker's opening page; only its first rows are
    /// laid out, so the tests stay among the first smileys.
    Future<void> choose(WidgetTester tester, String emoji) async {
      await tester.tap(find.text(emoji));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, int slot, String emoji) async {
      await openSlot(tester, slot);
      await choose(tester, emoji);
    }

    testWidgets('starts with one empty slot and submit disabled', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      expect(find.byKey(EmojiInput.slotKey(0)), findsOneWidget);
      expect(find.byKey(EmojiInput.slotKey(1)), findsNothing);
      expect(
        find.bySemanticsLabel(tester.strings.emojiPickLabel),
        findsOneWidget,
      );
      expect(isSubmitEnabled(tester, EmojiInput.submitKey), isFalse);
    });

    testWidgets('picking an emoji fills the slot and opens the next', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      await openSlot(tester, 0);

      expect(picker, findsOneWidget);
      // Nothing to clear yet, so nothing offers to.
      expect(clear, findsNothing);

      await choose(tester, '😊');

      expect(picker, findsNothing);
      expect(find.bySemanticsLabel('😊'), findsOneWidget);
      expect(find.byKey(EmojiInput.slotKey(1)), findsOneWidget);
      expect(isSubmitEnabled(tester, EmojiInput.submitKey), isTrue);
    });

    testWidgets('dismissing the picker leaves the slot empty', (tester) async {
      await pumpTestWidget(tester);
      await openSlot(tester, 0);

      // Outside the sheet.
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(picker, findsNothing);
      expect(find.byKey(EmojiInput.slotKey(1)), findsNothing);
    });

    testWidgets('a filled slot can be given another emoji', (tester) async {
      final submitted = await pumpTestWidget(tester);
      await pick(tester, 0, '😊');

      await pick(tester, 0, '😂');

      expect(find.bySemanticsLabel('😂'), findsOneWidget);
      expect(find.bySemanticsLabel('😊'), findsNothing);
      await tapSubmit(tester, EmojiInput.submitKey);
      expect(submitted.single, const Answer.emoji(['😂']));
    });

    testWidgets('a filled slot can be cleared', (tester) async {
      await pumpTestWidget(tester);
      await pick(tester, 0, '😊');
      await pick(tester, 1, '😂');

      await openSlot(tester, 0);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('😊'), findsNothing);
      expect(find.bySemanticsLabel('😂'), findsOneWidget);
      expect(find.byKey(EmojiInput.slotKey(2)), findsNothing);
    });

    testWidgets('submits the emoji in slot order', (tester) async {
      final submitted = await pumpTestWidget(tester);
      await pick(tester, 0, '😂');
      await pick(tester, 1, '😊');

      await tapSubmit(tester, EmojiInput.submitKey);

      expect(submitted.single, const Answer.emoji(['😂', '😊']));
    });

    testWidgets('the slots and the picker speak German', (tester) async {
      const german = Locale('de');
      final strings = lookupSessionLocalizations(german);
      await tester.pumpApp(
        const EmojiInput(onSubmit: ignoreAnswer),
        localizations: sessionLocalizations,
        locale: german,
      );

      expect(find.bySemanticsLabel(strings.emojiPickLabel), findsOneWidget);
      expect(find.text(strings.submitButton), findsOneWidget);

      await pick(tester, 0, '😊');
      await openSlot(tester, 0);

      expect(find.bySemanticsLabel(strings.emojiClearLabel), findsOneWidget);
      // Its search matches the German emoji names, so the German hint's
      // words find something; the pages it only shows on demand speak
      // German too.
      final config = tester.widget<EmojiPicker>(picker).config;
      expect(config.locale, german);
      expect(config.searchViewConfig.hintText, strings.emojiSearchHint);
      expect(
        (config.emojiViewConfig.noRecents as Text).data,
        strings.emojiNoRecents,
      );
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(
          const EmojiInput(onSubmit: ignoreAnswer),
          localizations: sessionLocalizations,
        ),
        prepare: (tester) => pick(tester, 0, '😀'),
      );
    });
  });
}
