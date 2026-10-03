import 'package:contract/contract.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

    testWidgets('the picker searches in the language the app speaks', (
      tester,
    ) async {
      // Any locale but the picker's own default English: the subject is
      // that the app's locale reaches the picker, not the words.
      const german = Locale('de');
      await tester.pumpApp(
        const EmojiInput(onSubmit: ignoreAnswer),
        localizations: sessionLocalizations,
      );
      await pick(tester, 0, '😊');
      await openSlot(tester, 0);

      final strings = tester.strings;
      expect(find.bySemanticsLabel(strings.emojiClearLabel), findsOneWidget);
      // Its search matches the emoji names in that language, so the hint's
      // example words find something; the pages it only shows on demand
      // are worded by the session too.
      final config = tester.widget<EmojiPicker>(picker).config;
      expect(config.locale, german);
      expect(
        (config.emojiViewConfig.noRecents as Text).data,
        strings.emojiNoRecents,
      );
    });

    /// The picker's search, opened from the sheet of the first slot.
    final search = find.bySubtype<SearchView>();

    Future<void> openSearch(WidgetTester tester) async {
      await openSlot(tester, 0);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'search finds an emoji by a word in the app language, to pick',
      (tester) async {
        final submitted = await pumpTestWidget(tester);
        await openSearch(tester);

        expect(
          find.descendant(
            of: search,
            matching: find.text(tester.strings.emojiSearchHint),
          ),
          findsOneWidget,
        );

        // German, as the app pumps: only the German name of 🦋 matches it,
        // the English "butterfly" would not.
        await tester.enterText(find.byType(EditableText), 'Schmetterling');
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: search, matching: find.text('🦋')),
        );
        await tester.pumpAndSettle();

        expect(picker, findsNothing);
        await tapSubmit(tester, EmojiInput.submitKey);
        expect(submitted.single, const Answer.emoji(['🦋']));
      },
      // The picker taps its emoji through Material buttons on Android and
      // Cupertino ones on iOS; search holds on both.
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets(
      'search results stay above the keyboard, to pick without closing it',
      (tester) async {
        addTearDown(tester.view.reset);
        final submitted = await pumpTestWidget(tester);
        await openSearch(tester);

        // The keyboard search opens takes the lower half of the 800x600
        // test screen.
        tester.view.viewInsets = FakeViewPadding(
          bottom: 300 * tester.view.devicePixelRatio,
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'Schmetterling');
        await tester.pumpAndSettle();

        final result = find.descendant(of: search, matching: find.text('🦋'));
        expect(tester.getRect(search).bottom, lessThanOrEqualTo(300));
        expect(tester.getRect(result).bottom, lessThanOrEqualTo(300));
        // Still typing: the keyboard has not been closed to reach it.
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(result);
        await tester.pumpAndSettle();

        expect(picker, findsNothing);
        await tapSubmit(tester, EmojiInput.submitKey);
        expect(submitted.single, const Answer.emoji(['🦋']));
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('without a keyboard the sheet sits at the bottom, as before', (
      tester,
    ) async {
      await pumpTestWidget(tester);
      await openSlot(tester, 0);

      // The picker's own height (256), Material 3's widest sheet (640),
      // centered on the bottom edge of the 800x600 test screen.
      expect(tester.getRect(picker), const Rect.fromLTWH(80, 344, 640, 256));
    });

    testWidgets('leaving search shows every emoji again', (tester) async {
      await pumpTestWidget(tester);
      await openSearch(tester);

      await tester.tap(find.byTooltip(tester.strings.emojiSearchBackTooltip));
      await tester.pumpAndSettle();

      expect(search, findsNothing);
      expect(find.text('😊'), findsOneWidget);
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

    testWidgets('search meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(
          const EmojiInput(onSubmit: ignoreAnswer),
          localizations: sessionLocalizations,
        ),
        prepare: (tester) async {
          await openSearch(tester);
          await tester.enterText(find.byType(EditableText), 'Schmetterling');
        },
      );
    });
  });
}
