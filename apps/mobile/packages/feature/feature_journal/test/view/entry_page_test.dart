import 'package:contract/contract.dart';
import 'package:design_system/design_system.dart'
    show DesignSystemLocalizations, EntryView;
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_journal/src/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

void main() {
  group(EntryPage, () {
    const entries = 'GET /rest/v1/entries';
    final written = DateTime.utc(2026, 9, 7, 20);
    // The day its session started on, the day before it was filed.
    final aboutDay = DateTime(2026, 9, 6);
    final analytics = AnalyticsSpy();

    /// The entry as the journal stores it: one rated question.
    Map<String, Object?> theEntry() => entryRow(
      id: 'e-1',
      summary: 'A seven kind of day.',
      createdAt: written,
      journalDay: aboutDay,
      answers: {rateQuestion.questionId: const Answer.rating(7)},
      questions: [rateQuestion],
    );

    /// The entry page as the app would show it, composed the way the app
    /// composes it over a scripted Supabase. Reading this composes the
    /// container, so read it once per test.
    Widget pageWith(SupabaseStub supabase) {
      registerUtilitiesUnderTest(
        GetIt.I,
        agent: AgentStub(),
        supabase: supabase,
        analytics: analytics,
      );
      registerJournal(GetIt.I);
      return pageUnderTest(
        const EntryPage(entryId: 'e-1'),
        localizations: const [JournalLocalizations.delegate],
      );
    }

    Future<void> launch(WidgetTester tester, SupabaseStub supabase) async {
      await supabase.signedIn();
      await tester.pumpWidget(pageWith(supabase));
      await tester.pumpAndSettle();
    }

    /// The journal's strings as the page on screen reads them.
    JournalLocalizations strings(WidgetTester tester) =>
        tester.element(find.byType(EntryPageView)).l10n;

    testWidgets('reads the entry back the way the session showed it', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..rest(entries, [
          rows([theEntry()]),
        ]);
      await launch(tester, supabase);

      final material = MaterialLocalizations.of(
        tester.element(find.byType(EntryPageView)),
      );
      expect(supabase.to(entries).single.query['id'], 'eq.e-1');
      expect(find.text(material.formatShortDate(aboutDay)), findsOneWidget);
      expect(find.text(material.formatShortDate(written)), findsNothing);
      expect(
        find.text(
          DesignSystemLocalizations.of(tester.element(find.byType(EntryView)))
              .entryViewTitle,
        ),
        findsOneWidget,
      );
      expect(find.byKey(EntryView.summaryKey), findsOneWidget);
      expect(find.text('A seven kind of day.'), findsOneWidget);
      expect(find.text(rateQuestion.question), findsOneWidget);
      expect(find.text('7 / $ratingMax'), findsOneWidget);
    });

    testWidgets('says so when the entry cannot be read, and retries', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..rest(entries, [
          restRefused(),
          rows([theEntry()]),
        ]);
      await launch(tester, supabase);

      expect(find.text(strings(tester).entryScreenTitle), findsOneWidget);
      expect(find.text(strings(tester).entryFailureMessage), findsOneWidget);
      expect(find.text(strings(tester).entryRetryButton), findsOneWidget);
      expect(find.byKey(EntryView.summaryKey), findsNothing);

      await tester.tap(find.byKey(EntryPage.retryKey));
      await tester.pumpAndSettle();

      expect(find.text('A seven kind of day.'), findsOneWidget);
    });

    testWidgets('an entry the journal no longer holds cannot be shown', (
      tester,
    ) async {
      final supabase = SupabaseStub()..rest(entries, [rows(const [])]);
      await launch(tester, supabase);

      expect(find.text(strings(tester).entryFailureMessage), findsOneWidget);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      final supabase = SupabaseStub()
        ..rest(entries, [
          rows([theEntry()]),
        ]);
      await supabase.signedIn();

      await tester.expectMeetsAccessibilityGuidelines(pageWith(supabase));
    });
  });
}
