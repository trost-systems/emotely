import 'package:analytics/analytics.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import '../fake_account_navigator.dart';

/// Drives the More tab on its own, composed the way the app composes it:
/// the utilities and this feature registered over a scripted Supabase, the
/// consent bloc handed in from the route as the app hands it, and a fake
/// navigator for what the app would do.
class _MoreRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  final AnalyticsChoice? stored = AnalyticsChoice.allowed,
}) {
  late final analytics = AnalyticsSpy(stored: stored);
  final navigator = FakeAccountNavigator();

  Finder get more => find.byType(MorePage);
  Finder get privacySettings => find.byKey(MoreView.privacySettingsKey);
  Finder get notice => find.byKey(MoreView.privacyNoticeKey);
  Finder get feedback => find.byKey(MoreView.feedbackKey);
  Finder get imprint => find.byKey(MoreView.imprintKey);
  Finder get signOut => find.byKey(MoreView.signOutKey);
  Finder get account => find.byKey(MoreView.accountKey);

  Finder heading(String title) => find.text(title);

  /// The status line under Privacy settings.
  String get status => tester
      .widget<Text>(
        find.descendant(of: privacySettings, matching: find.byType(Text)).last,
      )
      .data!;

  /// Reading this composes the container, so read it once per test.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    registerAccount(GetIt.I);
    GetIt.I.registerSingleton<AccountNavigator>(navigator);
    return featureUnderTest(
      routes: [$moreRoute],
      initialLocation: const MoreRoute().location,
    );
  }

  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
  }

  /// A viewport tall enough for the whole list, for the tests that measure
  /// where its rows sit: a scrolled list has no single answer to that.
  void showEverything() {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle() => tester.pumpAndSettle();

  /// Taps [finder], scrolling it into view first: the list is longer than
  /// a test viewport.
  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle();
    await tester.tap(finder);
    await settle();
  }
}

void main() {
  group(MorePage, () {
    _MoreRobot robotWith(
      WidgetTester tester, {
      bool granted = true,
      List<AuthRound> reads = const [],
      AnalyticsChoice? stored = AnalyticsChoice.allowed,
    }) {
      final supabase = SupabaseStub()
        ..rest(consentRead, reads)
        ..always(consentRead, consentStands(granted: granted));
      return _MoreRobot(tester, supabase: supabase, stored: stored);
    }

    testWidgets('lists privacy, about and the account last, in order', (
      tester,
    ) async {
      final robot = robotWith(tester)..showEverything();
      await robot.launch();

      final rows = [
        robot.heading(MoreView.privacySection),
        robot.privacySettings,
        robot.notice,
        robot.signOut,
        robot.heading(MoreView.aboutSection),
        robot.feedback,
        robot.imprint,
        robot.heading(MoreView.accountSection),
        robot.account,
      ];
      for (var i = 0; i + 1 < rows.length; i++) {
        expect(
          tester.getTopLeft(rows[i]).dy,
          lessThan(tester.getTopLeft(rows[i + 1]).dy),
          reason: 'row $i sits above row ${i + 1}',
        );
      }
    });

    testWidgets('sets the sections apart by more than a row', (tester) async {
      final robot = robotWith(tester)..showEverything();
      await robot.launch();

      // The gap from the last row of one section to the next heading is
      // what tells the sections apart at a glance; a row-to-row gap is
      // none at all.
      final beforeSignOut =
          tester.getTopLeft(robot.signOut).dy -
          tester.getBottomLeft(robot.notice).dy;
      expect(beforeSignOut, greaterThanOrEqualTo(MoreView.sectionGap));
      final beforeAccount =
          tester.getTopLeft(robot.heading(MoreView.accountSection)).dy -
          tester.getBottomLeft(robot.imprint).dy;
      expect(beforeAccount, greaterThanOrEqualTo(MoreView.sectionGap));
      expect(
        tester.getTopLeft(robot.notice).dy,
        tester.getBottomLeft(robot.privacySettings).dy,
      );
    });

    testWidgets('names deletion in the error colour, and signing out in the '
        'normal one', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      final colors = Theme.of(tester.element(robot.more)).colorScheme;
      final delete = tester.widget<Text>(
        find.descendant(
          of: robot.account,
          matching: find.text(MoreView.accountLabel),
        ),
      );
      expect(delete.style?.color, colors.error);
      expect(find.text(MoreView.accountExplanation), findsOneWidget);
      final signOut = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: robot.signOut,
          matching: find.text(MoreView.signOutLabel),
        ),
      );
      expect(signOut.text.style?.color, isNot(colors.error));
    });

    group('privacy settings', () {
      testWidgets('says in one line where both consents stand', (tester) async {
        final robot = robotWith(tester);
        await robot.launch();

        expect(robot.status, 'Journal: allowed · Usage analytics: on');
      });

      testWidgets('says so when neither stands', (tester) async {
        final robot = robotWith(
          tester,
          granted: false,
          stored: AnalyticsChoice.denied,
        );
        await robot.launch();

        expect(robot.status, 'Journal: off · Usage analytics: off');
      });

      testWidgets('leaves out what it could not read', (tester) async {
        final robot = robotWith(tester, reads: [restRefused()]);
        await robot.launch();

        expect(robot.status, 'Usage analytics: on');
      });

      testWidgets('opens on its own route, and the line follows what '
          'changed there', (tester) async {
        final robot = robotWith(tester);
        robot.supabase.rest(consentWithdraw, [rpcReturned(null)]);
        await robot.launch();

        await robot.tap(robot.privacySettings);

        expect(find.byType(PrivacySettingsPage), findsOneWidget);

        await robot.tap(find.byKey(PrivacySettingsPage.usageAnalyticsKey));
        robot.supabase.rest(consentRead, [consentStands(granted: false)]);
        await tester.pageBack();
        await robot.settle();

        expect(robot.more, findsOneWidget);
        expect(robot.status, 'Journal: off · Usage analytics: off');
      });
    });

    testWidgets('opens the account screen on its own route, and comes back', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.account);

      expect(find.byType(AccountPage), findsOneWidget);
      expect(robot.more, findsNothing);

      await tester.pageBack();
      await robot.settle();

      expect(robot.more, findsOneWidget);
      expect(find.byType(AccountPage), findsNothing);
    });

    testWidgets('signs out through the app', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.signOut);

      expect(robot.navigator.signOuts, 1);
    });

    testWidgets('the rows span the whole width', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      // Each row is a button the width of the screen, so its highlight runs
      // edge to edge and the label sits 16 in — not a strip inside the page
      // margin that lights up narrower than the finger expects.
      final screen = tester.getRect(
        find.descendant(of: robot.more, matching: find.byType(Scaffold)),
      );
      for (final row in [robot.privacySettings, robot.notice, robot.feedback]) {
        final rect = tester.getRect(row);
        expect(rect.left, screen.left);
        expect(rect.width, screen.width);
      }
      expect(
        tester.getRect(find.text(privacyNoticeLabel)).left,
        screen.left + 16,
      );
    });

    testWidgets('links the privacy notice and the imprint', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.notice);
      await robot.tap(robot.imprint);

      expect(launcher.launched, [privacyNoticeUrl, imprintUrl]);
    });

    testWidgets('opens a prefilled feedback mail', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.feedback);

      final mail = Uri.parse(launcher.launched.single);
      expect(mail.scheme, 'mailto');
      expect(mail.path, feedbackAddress);
      expect(
        mail.queryParameters['subject'],
        allOf(
          contains(testBuildInfo.versionAndBuild),
          contains(testBuildInfo.platform),
        ),
      );
    });

    testWidgets('reports a device with no mail app, and says nothing', (
      tester,
    ) async {
      UrlLauncherSpy.setup().fails = true;
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.feedback);

      // The screen is unchanged: there is nothing useful to say, and the
      // beta's one feedback channel dead-ending is ours to notice, not the
      // user's to work around.
      expect(robot.feedback, findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(withheld(PlatformException), {'step': 'feedback_mail'}),
      ]);
    });

    testWidgets('tells the mail nothing about the user or their journal', (
      tester,
    ) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();

      await robot.tap(robot.feedback);

      // The signed-in user's id and address are what this screen holds and
      // the mail must not carry; the mail itself already says who sent it.
      final user = robot.supabase.supabase.auth.currentUser!;
      expect(launcher.launched.single, isNot(contains(user.id)));
      expect(launcher.launched.single, isNot(contains(user.email)));
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      final robot = robotWith(tester);
      await robot.supabase.signedIn();
      await tester.expectMeetsAccessibilityGuidelines(robot.app);
    });
  });
}
