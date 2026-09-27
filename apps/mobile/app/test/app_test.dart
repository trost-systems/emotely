import 'package:contract/contract.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/shell.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/helpers.dart';

void main() {
  group(EmotelyApp, () {
    testWidgets('opens on sign-in when nobody is signed in', (tester) async {
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: SupabaseStub(),
          analytics: AnalyticsSpy(),
        ),
      );
      // The startup gate reads the config before anything renders (#49).
      await tester.pumpAndSettle();

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(JournalPage), findsNothing);
    });

    testWidgets('opens straight into the journal for a restored sign-in', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      await supabase.signedIn();
      final analytics = AnalyticsSpy();

      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage), findsOneWidget);
      expect(find.text('Your journal'), findsOneWidget);
      // The restored user is known to PostHog before anything else happens.
      expect(analytics.identified, [SupabaseStub.userId]);
    });
    testWidgets('opens an entry from the journal and reads it back', (
      tester,
    ) async {
      // The entry route carries the id alone; the screen reads the entry
      // back, so the same read serves the journal's list and the screen.
      final supabase = SupabaseStub()
        ..always(
          'GET /rest/v1/entries',
          rows([
            entryRow(
              id: 'e-1',
              summary: 'A seven kind of day.',
              createdAt: DateTime.utc(2026, 9, 7, 20),
              answers: {rateQuestion.questionId: const Answer.rating(7)},
              questions: [rateQuestion],
            ),
          ]),
        );
      await supabase.signedIn();

      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: AnalyticsSpy(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(JournalView.entryKey('e-1')));
      await tester.pumpAndSettle();

      expect(find.byType(EntryPage), findsOneWidget);
      expect(find.text(rateQuestion.question), findsOneWidget);
      expect(find.text('7 / $ratingMax'), findsOneWidget);
      expect(supabase.to('GET /rest/v1/entries').last.query['id'], 'eq.e-1');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage), findsOneWidget);
      expect(find.byType(EntryPage), findsNothing);
    });

    testWidgets('keeps the journal tab and the More tab side by side', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      await supabase.signedIn();
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: AnalyticsSpy(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage), findsOneWidget);
      expect(find.byType(MorePage), findsNothing);

      await tester.tap(find.byKey(AppShell.moreTabKey));
      await tester.pumpAndSettle();

      expect(find.byType(MorePage), findsOneWidget);
      expect(find.byType(JournalPage), findsNothing);

      await tester.tap(find.byKey(AppShell.journalTabKey));
      await tester.pumpAndSettle();

      expect(find.byType(JournalPage), findsOneWidget);
      expect(find.byType(MorePage), findsNothing);
    });

    testWidgets('signs out from the Profile screen and returns to sign-in', (
      tester,
    ) async {
      // The Profile screen, under More, asks the app to sign out; the app
      // tells the auth bloc, and the router lands on sign-in.
      final supabase = SupabaseStub()..script(logout: [signedOut()]);
      await supabase.signedIn();
      final analytics = AnalyticsSpy();

      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase: supabase,
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppShell.moreTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MoreView.profileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ProfileView.signOutKey));
      await tester.pumpAndSettle();

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(JournalPage), findsNothing);
      expect(analytics.events.last, event('signed_out'));
    });
  });
}
