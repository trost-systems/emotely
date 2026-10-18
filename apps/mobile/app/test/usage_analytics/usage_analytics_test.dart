import 'package:analytics/analytics.dart';
import 'package:emotely/app/shell.dart';
import 'package:emotely/config/view/config_gate.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
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
      String? owner,
      SupabaseStub? supabase,
      ConfigStub? config,
    }) async {
      final analytics = AnalyticsSpy(stored: stored, owner: owner);
      await tester.pumpWidget(
        appUnderTest(
          agent: AgentStub(),
          supabase:
              supabase ??
              (SupabaseStub()..script(password: [sessionGranted()])),
          analytics: analytics,
          config: config,
        ),
      );
      await tester.pumpAndSettle();
      return analytics;
    }

    testWidgets('are asked about first, over Welcome, with nothing set up', (
      tester,
    ) async {
      final analytics = await launch(tester);

      expect(sheet(), findsOneWidget);
      expect(find.byType(WelcomeStepView), findsOneWidget);
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

      // Set up and reset once, at the allow, and never again before the
      // sign-in: the anonymous events before it are the same person's, and
      // PostHog merges them into the account on identify.
      expect(analytics.lifecycle, ['setup', 'reset']);
      expect(analytics.identified, [SupabaseStub.userId]);
      expect(analytics.events, [
        event('usage_analytics_allowed'),
        event('onboarding_started', {
          'flow_version': onboardingFlowVersion,
          'variant': 'control',
          'step_count': 4,
        }),
        event('onboarding_step_viewed', {
          'flow_version': onboardingFlowVersion,
          'variant': 'control',
          'step_id': 'welcome',
          'step_index': 0,
          'phase': 'before_sign_up',
        }),
        event('signed_in', {'method': 'password'}),
        event('journal_viewed', {'entries': 0, 'open_session': false}),
      ]);
    });

    testWidgets('an allow before sign-in is recorded against the account', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(password: [sessionGranted()])
        ..rest(usageAnalyticsRead, [rpcReturned(false)])
        ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
      await launch(tester, supabase: supabase);

      await tester.tap(find.byKey(UsageAnalyticsSheet.allowKey));
      await tester.pumpAndSettle();

      // Nobody to record it for yet: the choice lives on the device.
      expect(supabase.to(usageAnalyticsRead), isEmpty);

      await signInThroughTheScreen(tester);

      const recorded = {
        'version': usageAnalyticsVersion,
        'purpose': 'usage_analytics',
      };
      expect(supabase.bodies('/rest/v1/rpc/record_consent'), [recorded]);
    });

    testWidgets('a refusal after a consent is recorded as a withdrawal', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(password: [sessionGranted()])
        ..rest(usageAnalyticsRead, [rpcReturned(true)])
        ..rest(usageAnalyticsWithdraw, [rpcReturned(null)]);
      await launch(tester, supabase: supabase);

      await tester.tap(find.byKey(UsageAnalyticsSheet.denyKey));
      await tester.pumpAndSettle();
      await signInThroughTheScreen(tester);

      expect(supabase.bodies('/rest/v1/rpc/withdraw_consent'), [
        {'version': usageAnalyticsVersion, 'purpose': 'usage_analytics'},
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
      await tester.tap(find.byKey(MoreView.profileKey));
      await tester.pumpAndSettle();
      final before = analytics.events.length;
      await tester.tap(find.byKey(ProfileView.signOutKey));
      await tester.pumpAndSettle();

      // The choice was the person's: PostHog forgets them and switches off,
      // and whoever signs in next is asked, over Welcome. Welcome's own
      // events wait for that answer; none goes out as the last person.
      expect(find.byType(WelcomeStepView), findsOneWidget);
      expect(sheet(), findsOneWidget);
      expect(analytics.events.sublist(before), [event('signed_out')]);
      expect(analytics.lifecycle, ['setup', 'flush', 'reset', 'disable']);
    });

    testWidgets('are asked about again when a session ends on its own, and '
        'the last answer is never recorded for the next person', (
      tester,
    ) async {
      const next = '00000000-0000-0000-0000-00000000000b';
      final supabase = SupabaseStub()
        ..script(
          logout: [signedOut()],
          password: [sessionGranted(sub: next)],
        )
        // The first person's consent stands; the next one has none.
        ..rest(usageAnalyticsRead, [rpcReturned(true), rpcReturned(false)]);
      await supabase.signedIn();
      final analytics = await launch(
        tester,
        stored: AnalyticsChoice.allowed,
        supabase: supabase,
      );
      final before = analytics.events.length;

      // Nobody tapped anything: an expiry, a revoked refresh token or an
      // account deleted elsewhere end the session through the SDK alike.
      await supabase.supabase.auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeStepView), findsOneWidget);
      expect(sheet(), findsOneWidget);
      expect(analytics.events.sublist(before), isEmpty);
      expect(analytics.lifecycle, ['setup', 'flush', 'reset', 'disable']);

      await tester.tap(find.byKey(UsageAnalyticsSheet.denyKey));
      await tester.pumpAndSettle();
      expect(analytics.lifecycle.last, 'close');
      await signInThroughTheScreen(tester);

      expect(find.byType(JournalPage), findsOneWidget);
      expect(supabase.to(usageAnalyticsGrant), isEmpty);
      expect(analytics.events.sublist(before), isEmpty);
    });

    group('remember whose they are (#216)', () {
      const alice = '00000000-0000-0000-0000-00000000000c';

      testWidgets('are asked about again when a session ended while the app '
          'was closed, and the answer left behind is never recorded', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(password: [sessionGranted()])
          ..rest(usageAnalyticsRead, [rpcReturned(false)]);
        // The last person allowed, and their session died while the app was
        // closed: the app starts signed out, with their answer on the phone.
        final analytics = await launch(
          tester,
          owner: alice,
          supabase: supabase,
        );

        expect(find.byType(WelcomeStepView), findsOneWidget);
        expect(sheet(), findsOneWidget);
        expect(analytics.lifecycle, isEmpty);
        expect(analytics.outgoingStrings, isEmpty);

        await tester.tap(find.byKey(UsageAnalyticsSheet.denyKey));
        await tester.pumpAndSettle();
        await signInThroughTheScreen(tester);

        expect(find.byType(JournalPage), findsOneWidget);
        expect(supabase.to(usageAnalyticsGrant), isEmpty);
        expect(analytics.lifecycle, isEmpty);
        expect(analytics.outgoingStrings, isEmpty);
      });

      testWidgets('are asked about again, before anything is sent, when the '
          'app starts signed in as someone else', (tester) async {
        final supabase = SupabaseStub();
        await supabase.signedIn();
        final analytics = await launch(
          tester,
          owner: alice,
          supabase: supabase,
        );

        expect(sheet(), findsOneWidget);
        // The restored session's identify and the journal's first event
        // queued behind the check, and found the gate shut.
        expect(analytics.lifecycle, isEmpty);
        expect(analytics.outgoingStrings, isEmpty);
        expect(supabase.to(usageAnalyticsRead), isEmpty);
      });

      testWidgets('are asked about again where an earlier build kept the '
          'answer without whose it was', (tester) async {
        final supabase = SupabaseStub();
        await supabase.signedIn();
        final analytics = AnalyticsSpy(stored: null);
        await analytics.preferences.setString(
          AnalyticsChoiceStore.key,
          AnalyticsChoice.allowed.name,
        );
        await tester.pumpWidget(
          appUnderTest(
            agent: AgentStub(),
            supabase: supabase,
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        expect(sheet(), findsOneWidget);
        expect(analytics.lifecycle, isEmpty);
        expect(analytics.outgoingStrings, isEmpty);
        expect(supabase.to(usageAnalyticsRead), isEmpty);
      });

      testWidgets('an answer given before sign-up becomes the account’s', (
        tester,
      ) async {
        final supabase = SupabaseStub()
          ..script(password: [sessionGranted()])
          ..rest(usageAnalyticsRead, [rpcReturned(false)])
          ..rest(usageAnalyticsGrant, [rpcReturned(null)]);
        final analytics = await launch(tester, supabase: supabase);

        await tester.tap(find.byKey(UsageAnalyticsSheet.allowKey));
        await tester.pumpAndSettle();
        await signInThroughTheScreen(tester);

        expect(
          await AnalyticsChoiceStore(preferences: analytics.preferences).read(),
          (choice: AnalyticsChoice.allowed, account: SupabaseStub.userId),
        );
      });
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
