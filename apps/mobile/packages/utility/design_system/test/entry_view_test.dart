import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:design_system/design_system.dart';
import 'package:design_system/src/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

void main() {
  const questions = {
    'q-rate': AskQuestion(
      questionId: 'q-rate',
      question: 'How would you rate your day?',
      answerType: AnswerType.rating,
    ),
    'q-colors': AskQuestion(
      questionId: 'q-colors',
      question: 'Which colors were your day?',
      answerType: AnswerType.color,
    ),
    'q-mood': AskQuestion(
      questionId: 'q-mood',
      question: 'Which emoji fit?',
      answerType: AnswerType.emoji,
    ),
    'q-best': AskQuestion(
      questionId: 'q-best',
      question: 'What was the best thing today?',
      answerType: AnswerType.longtext,
    ),
    'q-grateful': AskQuestion(
      questionId: 'q-grateful',
      question: 'What are you grateful for?',
      answerType: AnswerType.textList,
    ),
  };
  const entry = JournalEntry(
    summary: 'A good day, all told.',
    answers: {
      'q-rate': Answer.rating(8),
      'q-colors': Answer.color([Color(0xFFFF8800), Color(0xFF0088FF)]),
      'q-mood': Answer.emoji(['😊', '🌤️']),
      'q-best': Answer.longtext('Shipping the thing.'),
      'q-grateful': Answer.textList(['coffee', 'quiet']),
      'q-unknown': Answer.longtext('an answer without its question'),
    },
  );

  group(EntryView, () {
    // The component words its own heading, the same on every screen that
    // shows an entry (ADR 0020).
    testWidgets('heads the entry in its own words', (tester) async {
      await tester.pumpApp(const EntryView(entry: entry, questions: questions));

      final strings = tester.element(find.byType(EntryView)).l10n;
      expect(find.text(strings.entryViewTitle), findsOneWidget);
    });

    testWidgets('shows the summary, then every question with its answer', (
      tester,
    ) async {
      await tester.pumpApp(const EntryView(entry: entry, questions: questions));

      expect(
        tester.widget<Text>(find.byKey(EntryView.summaryKey)).data,
        'A good day, all told.',
      );
      for (final question in questions.values) {
        expect(find.text(question.question), findsOneWidget);
      }
      expect(find.byType(AnswerText), findsNWidgets(6));
    });

    testWidgets('renders every answer type in its own shape', (tester) async {
      await tester.pumpApp(const EntryView(entry: entry, questions: questions));

      expect(find.text('8 / $ratingMax'), findsOneWidget);
      expect(find.text('😊 🌤️'), findsOneWidget);
      expect(find.text('Shipping the thing.'), findsOneWidget);
      expect(find.text('• coffee\n• quiet'), findsOneWidget);
      expect(
        tester.widget<ColorText>(find.byType(ColorText)).text,
        '#FF8800 #0088FF',
      );
    });

    testWidgets('falls back to the question id when the question is gone', (
      tester,
    ) async {
      await tester.pumpApp(const EntryView(entry: entry, questions: questions));

      expect(find.text('q-unknown'), findsOneWidget);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appWrapper(const EntryView(entry: entry, questions: questions)),
      );
    });
  });
}
