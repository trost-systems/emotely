import 'package:design_system/src/sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testing/testing.dart';

void main() {
  group('showSheet', () {
    const openKey = Key('sheet_test.open');
    const contentKey = Key('sheet_test.content');
    final content = find.byKey(contentKey);

    /// A button that opens [sheet] and keeps what the sheet returned.
    Widget opener(List<String?> returned, Widget sheet) => Builder(
      builder: (context) => TextButton(
        key: openKey,
        onPressed: () async {
          returned.add(
            await showSheet<String>(context: context, builder: (_) => sheet),
          );
        },
        child: const Text('open'),
      ),
    );

    Future<List<String?>> pumpTestWidget(
      WidgetTester tester, {
      Widget sheet = const SizedBox(key: contentKey, height: 200),
    }) async {
      final returned = <String?>[];
      await tester.pumpApp(opener(returned, sheet));
      await tester.tap(find.byKey(openKey));
      await tester.pumpAndSettle();
      return returned;
    }

    void showKeyboard(WidgetTester tester, double height) {
      tester.view.viewInsets = FakeViewPadding(
        bottom: height * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
    }

    testWidgets('sits on the bottom edge, as tall as its content', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      // On the 800x600 test screen.
      expect(tester.getRect(content).bottom, 600);
      expect(tester.getRect(content).height, 200);
    });

    testWidgets('rises above the keyboard, keeping its height', (tester) async {
      await pumpTestWidget(tester);

      showKeyboard(tester, 300);
      await tester.pumpAndSettle();

      expect(tester.getRect(content).bottom, 300);
      expect(tester.getRect(content).height, 200);
    });

    testWidgets('goes back down when the keyboard closes', (tester) async {
      await pumpTestWidget(tester);
      showKeyboard(tester, 300);
      await tester.pumpAndSettle();

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();

      expect(tester.getRect(content).bottom, 600);
    });

    testWidgets('its content sees the keyboard as already avoided', (
      tester,
    ) async {
      await pumpTestWidget(
        tester,
        sheet: Builder(
          builder: (context) => SizedBox(
            key: contentKey,
            // Would grow by the keyboard if the inset still reached here.
            height: 100 + MediaQuery.viewInsetsOf(context).bottom,
          ),
        ),
      );

      showKeyboard(tester, 300);
      await tester.pumpAndSettle();

      expect(tester.getRect(content).height, 100);
    });

    testWidgets('a tall sheet stops below the status bar', (tester) async {
      tester.view.padding = FakeViewPadding(
        top: 40 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await pumpTestWidget(
        tester,
        sheet: const SizedBox(key: contentKey, height: 1000),
      );

      expect(tester.getRect(content).top, 40);
    });

    testWidgets('returns what the sheet closes with', (tester) async {
      final returned = await pumpTestWidget(
        tester,
        sheet: Builder(
          builder: (context) => TextButton(
            key: contentKey,
            onPressed: () => Navigator.of(context).pop('picked'),
            child: const Text('pick'),
          ),
        ),
      );

      await tester.tap(content);
      await tester.pumpAndSettle();

      expect(returned, ['picked']);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(opener([], const SizedBox(key: contentKey, height: 200))),
        prepare: (tester) async {
          await tester.tap(find.byKey(openKey));
          await tester.pumpAndSettle();
        },
      );
    });
  });
}
