import 'package:contract/contract.dart';
import 'package:feature_session/src/l10n/session_localizations.dart';
import 'package:feature_session/src/widgets/rating_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:testing/testing.dart';

import '../session_strings.dart';
import '../slide_rating.dart';

void main() {
  group(RatingInput, () {
    Future<Submitted> pumpTestWidget(WidgetTester tester) async {
      final submitted = Submitted();
      await tester.pumpApp(
        RatingInput(onSubmit: submitted.call),
        localizations: sessionLocalizations,
      );
      return submitted;
    }

    String shownValue(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(RatingInput.valueKey)).data!;

    testWidgets('starts with no answer, and says so', (tester) async {
      await pumpTestWidget(tester);

      final slider = tester.widget<Slider>(find.byKey(RatingInput.sliderKey));
      expect(slider.value, 0);
      expect(slider.min, 0);
      expect(slider.max, RatingInput.max);
      // Whole numbers only: one stop per value, plus the "no answer" stop.
      expect(slider.divisions, RatingInput.max);
      expect(shownValue(tester), tester.strings.ratingNoAnswer);
      expect(isSubmitEnabled(tester, RatingInput.submitKey), isFalse);
    });

    testWidgets('sliding to a value shows it and enables submit', (
      tester,
    ) async {
      await pumpTestWidget(tester);

      await slideRatingTo(tester, 7);

      expect(shownValue(tester), '7');
      expect(isSubmitEnabled(tester, RatingInput.submitKey), isTrue);
    });

    testWidgets('sliding back to the start is no answer again', (tester) async {
      await pumpTestWidget(tester);
      await slideRatingTo(tester, 4);

      await slideRatingTo(tester, 0);

      expect(shownValue(tester), tester.strings.ratingNoAnswer);
      expect(isSubmitEnabled(tester, RatingInput.submitKey), isFalse);
    });

    testWidgets('speaks German, to the eye and to a screen reader', (
      tester,
    ) async {
      const german = Locale('de');
      final strings = lookupSessionLocalizations(german);
      await tester.pumpApp(
        const RatingInput(onSubmit: ignoreAnswer),
        localizations: sessionLocalizations,
        locale: german,
      );

      expect(shownValue(tester), strings.ratingNoAnswer);
      expect(find.semantics.byValue(strings.ratingNoAnswer), findsOne);
      expect(find.text(strings.submitButton), findsOneWidget);
    });

    testWidgets('submits the value the slider rests on', (tester) async {
      final submitted = await pumpTestWidget(tester);
      await slideRatingTo(tester, 7);
      await slideRatingTo(tester, 3);

      await tapSubmit(tester, RatingInput.submitKey);

      expect(submitted.single, const Answer.rating(3));
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(
          const RatingInput(onSubmit: ignoreAnswer),
          localizations: sessionLocalizations,
        ),
        prepare: (tester) => slideRatingTo(tester, 8),
      );
    });
  });
}
