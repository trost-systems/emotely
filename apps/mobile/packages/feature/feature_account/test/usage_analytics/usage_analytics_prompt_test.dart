import 'package:analytics/analytics.dart';
import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

/// Drives the first-launch sheet the way the app mounts it: above the
/// navigator, over whatever screen is underneath, with the utilities and
/// this feature registered over a spied PostHog and the device's stored
/// choice.
class _PromptRobot(final WidgetTester tester, {final AnalyticsChoice? stored}) {
  late final analytics = AnalyticsSpy(stored: stored);

  static const underneathKey = Key('underneath');

  Finder get sheet => find.byKey(UsageAnalyticsSheet.sheetKey);
  Finder get allow => find.byKey(UsageAnalyticsSheet.allowKey);
  Finder get deny => find.byKey(UsageAnalyticsSheet.denyKey);
  Finder get notice => find.byKey(UsageAnalyticsSheet.noticeKey);
  Finder get underneath => find.byKey(underneathKey);

  /// Reading this composes the container, so read it once per test.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: SupabaseStub(),
      analytics: analytics,
    );
    registerAccount(GetIt.I);
    return featureUnderTest(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                key: underneathKey,
                onPressed: () {},
                child: const Text('Sign in'),
              ),
            ),
          ),
        ),
      ],
      initialLocation: '/',
      above: (context, child) => UsageAnalyticsPrompt(child: child),
    );
  }

  Future<void> launch() async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  group(UsageAnalyticsPrompt, () {
    testWidgets('asks on first launch, over the screen underneath', (
      tester,
    ) async {
      final robot = _PromptRobot(tester);
      await robot.launch();

      expect(robot.sheet, findsOneWidget);
      for (final text in [
        usageAnalyticsTitle,
        usageAnalyticsBody,
        usageAnalyticsCounted,
        usageAnalyticsNever,
        usageAnalyticsChangeHint,
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      // Nothing is set up while the question stands.
      expect(robot.analytics.lifecycle, isEmpty);

      // The screen underneath waits for the answer.
      await tester.tap(robot.underneath, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(robot.sheet, findsOneWidget);
    });

    testWidgets('offers both answers with equal weight', (tester) async {
      final robot = _PromptRobot(tester);
      await robot.launch();

      final allow = tester.widget<OutlinedButton>(robot.allow);
      final deny = tester.widget<OutlinedButton>(robot.deny);
      expect(deny.runtimeType, allow.runtimeType);
      expect(deny.style, allow.style);
      expect(tester.getSize(robot.deny), tester.getSize(robot.allow));
    });

    testWidgets('allowing sets PostHog up and goes away', (tester) async {
      final robot = _PromptRobot(tester);
      await robot.launch();

      await robot.tap(robot.allow);

      expect(robot.sheet, findsNothing);
      expect(robot.analytics.lifecycle, ['setup', 'reset']);
      expect(GetIt.I<PostHogGate>().choice, AnalyticsChoice.allowed);

      await robot.tap(robot.underneath);
    });

    testWidgets('refusing sets nothing up and goes away', (tester) async {
      final robot = _PromptRobot(tester);
      await robot.launch();

      await robot.tap(robot.deny);

      expect(robot.sheet, findsNothing);
      expect(robot.analytics.lifecycle, isEmpty);
      expect(GetIt.I<PostHogGate>().choice, AnalyticsChoice.denied);
    });

    testWidgets('stays away once answered', (tester) async {
      for (final stored in AnalyticsChoice.values) {
        await GetIt.I.reset();
        final robot = _PromptRobot(tester, stored: stored);
        await tester.pumpWidget(
          KeyedSubtree(key: ValueKey(stored), child: robot.app),
        );
        await tester.pumpAndSettle();

        expect(robot.sheet, findsNothing, reason: '$stored');
        expect(robot.underneath, findsOneWidget);
      }
    });

    testWidgets('asks again once the choice is forgotten on sign-out', (
      tester,
    ) async {
      final robot = _PromptRobot(tester, stored: AnalyticsChoice.allowed);
      await robot.launch();

      expect(robot.sheet, findsNothing);

      await GetIt.I<AuthAnalytics>().signedOut();
      await tester.pumpAndSettle();

      expect(robot.sheet, findsOneWidget);
    });

    testWidgets('links the privacy notice', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = _PromptRobot(tester);
      await robot.launch();

      await robot.tap(robot.notice);

      expect(launcher.launched, [privacyNoticeUrl]);
      expect(robot.sheet, findsOneWidget);
    });

    testWidgets('meets accessibility guidelines, in light and dark', (
      tester,
    ) async {
      final robot = _PromptRobot(tester);
      await tester.expectMeetsAccessibilityGuidelines(robot.app);
    });
  });
}
