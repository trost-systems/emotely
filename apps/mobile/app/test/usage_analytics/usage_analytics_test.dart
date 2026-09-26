import 'package:analytics/analytics.dart';
import 'package:emotely/app/shell.dart';
import 'package:emotely/config/view/config_gate.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

/// Usage analytics through the whole app (#204): nothing reaches PostHog —
/// not even `setup` — until the user allowed it on the first-launch sheet,
/// and the question comes back when they sign out.
void main() {
  group('usage analytics', () {
    Finder sheet() => find.byKey(UsageAnalyticsSheet.sheetKey);

    Future<AnalyticsSpy> launch(
      WidgetTester tester, {
      AnalyticsChoice? stored,
      SupabaseStub? supabase,
      ConfigStub? config,
    }) async {
      final analytics = AnalyticsSpy(stored: stored);
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase:
              supabase ??
              (SupabaseStub()
                ..script(otp: [codeSent()], verify: [sessionGranted()])),
          analytics: analytics,
          config: config,
        ),
      );
      await tester.pumpAndSettle();
      return analytics;
    }

    testWidgets('are asked about first, over sign-in, with nothing set up', (
      tester,
    ) async {
      final analytics = await launch(tester);

      expect(sheet(), findsOneWidget);
      expect(find.byType(SignInPage), findsOneWidget);
      expect(analytics.lifecycle, isEmpty);
      expect(analytics.outgoingStrings, isEmpty);
    });

    testWidgets('once refused, a whole sign-in tells PostHog nothing', (
      tester,
    ) async {
      final analytics = await launch(tester);

      await tester.tap(find.byKey(UsageAnalyticsSheet.denyKey));
      await tester.pumpAndSettle();
      await signInThroughTheScreen(tester);

      expect(find.byType(JournalPage), findsOneWidget);
      expect(sheet(), findsNothing);
      expect(analytics.lifecycle, isEmpty);
      expect(analytics.outgoingStrings, isEmpty);
    });

    testWidgets('once allowed, PostHog is set up and the sign-in counted', (
      tester,
    ) async {
      final analytics = await launch(tester);

      await tester.tap(find.byKey(UsageAnalyticsSheet.allowKey));
      await tester.pumpAndSettle();
      await signInThroughTheScreen(tester);

      expect(analytics.lifecycle, ['setup', 'reset']);
      expect(analytics.identified, [SupabaseStub.userId]);
      expect(analytics.events, [
        event('sign_in_code_requested'),
        event('signed_in', {'method': 'code'}),
        event('journal_viewed', {'entries': 0, 'open_session': false}),
      ]);
    });

    testWidgets('wait behind the force-update screen', (tester) async {
      final analytics = await launch(
        tester,
        config: ConfigStub()..serves(minAppVersion: '9.0.0'),
      );

      expect(find.byKey(ConfigGate.updateRequiredKey), findsOneWidget);
      expect(sheet(), findsNothing);
      expect(analytics.lifecycle, isEmpty);
    });

    testWidgets('allowed later in Privacy settings, name the signed-in user', (
      tester,
    ) async {
      final supabase = SupabaseStub();
      await supabase.signedIn();
      final analytics = await launch(
        tester,
        stored: AnalyticsChoice.denied,
        supabase: supabase,
      );

      expect(analytics.identities, isEmpty);

      await tester.tap(find.byKey(AppShell.moreTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MoreView.privacySettingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PrivacySettingsPage.usageAnalyticsKey));
      await tester.pumpAndSettle();

      // The restored session's identify waited on the device, and PostHog
      // hears it the moment it may.
      expect(analytics.identified, [SupabaseStub.userId]);
      expect(analytics.lifecycle, ['setup', 'reset']);
    });

    testWidgets('are asked about again after signing out', (tester) async {
      final supabase = SupabaseStub()..script(logout: [signedOut()]);
      await supabase.signedIn();
      final analytics = await launch(
        tester,
        stored: AnalyticsChoice.allowed,
        supabase: supabase,
      );

      expect(sheet(), findsNothing);

      await tester.tap(find.byKey(AppShell.moreTabKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(MoreView.signOutKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MoreView.signOutKey));
      await tester.pumpAndSettle();

      // The choice was the person's: PostHog forgets them and switches off,
      // and whoever signs in next is asked.
      expect(find.byType(SignInPage), findsOneWidget);
      expect(sheet(), findsOneWidget);
      expect(analytics.events.last, event('signed_out'));
      expect(analytics.lifecycle, ['setup', 'reset', 'disable', 'close']);
    });

    testWidgets('the sheet meets accessibility guidelines', (tester) async {
      await tester.expectMeetsAccessibilityGuidelines(
        appUnderTest(
          agent: AgentStub(),
          supabase: SupabaseStub(),
          analytics: AnalyticsSpy(stored: null),
        ),
      );

      expect(sheet(), findsOneWidget);
    });
  });
}
