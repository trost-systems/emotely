import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';
import '../config_robot.dart';

/// The startup gate, driven through the real app: the server says once,
/// before anything else, whether this build may run (#49).
void main() {
  group('startup gate', () {
    testWidgets('lets the app through when the server serves this build', (
      tester,
    ) async {
      final config = ConfigStub()..serves();
      final robot = ConfigRobot(tester, config);

      await robot.launchSignedIn();
      await robot.settle();

      expect(robot.journal, findsOneWidget);
      expect(robot.updateRequired, findsNothing);
      expect(config.calls, 1);
    });

    testWidgets('a minimum equal to the running version does not block', (
      tester,
    ) async {
      // The boundary: `>` not `>=`. Slipping this would force-update every
      // user to the version they are already on, with no retry by design
      // and an edge cache between the fix and the user.
      final config = ConfigStub()..serves(minAppVersion: AgentStub.appVersion);
      final robot = ConfigRobot(tester, config);

      await robot.launchSignedIn();
      await robot.settle();

      expect(robot.journal, findsOneWidget);
      expect(robot.updateRequired, findsNothing);
    });

    testWidgets('shows the check before the answer is in', (tester) async {
      final config = ConfigStub()..script([configDelayed(servesConfig())]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await tester.pump();

      expect(robot.checking, findsOneWidget);
      expect(robot.welcome, findsNothing);

      await robot.settle();
    });

    testWidgets('blocks a build below the minimum, before sign-in', (
      tester,
    ) async {
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.updateRequired, findsOneWidget);
      // The whole point of gating above auth: a build the server refuses
      // never reaches a screen that may depend on a wire shape that is gone.
      expect(robot.welcome, findsNothing);
      expect(robot.journal, findsNothing);
    });

    testWidgets('blocks a signed-in user just the same', (tester) async {
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);

      await robot.launchSignedIn();
      await robot.settle();

      expect(robot.updateRequired, findsOneWidget);
      expect(robot.journal, findsNothing);
    });

    testWidgets('the update button opens the store the server named', (
      tester,
    ) async {
      final launcher = UrlLauncherSpy.setup();
      final config = ConfigStub()
        ..serves(minAppVersion: '9.0.0', storeUrl: 'https://store.test/new');
      final robot = ConfigRobot(tester, config);
      await robot.launch();
      await robot.settle();

      await robot.tapUpdate();

      // The link comes off the wire, not off a dart-define, so it can be
      // corrected for users who cannot install a build carrying a new one.
      expect(launcher.launched, ['https://store.test/new']);
    });

    testWidgets('reports a store that will not open', (tester) async {
      // The screen stays blocking either way, but the user is now stuck on
      // their only way out — worth knowing about.
      final launcher = UrlLauncherSpy.setup()..fails = true;
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);
      await robot.launch();
      await robot.settle();

      await robot.tapUpdate();

      expect(launcher.launched, isEmpty);
      expect(
        robot.analytics.exceptions.single.properties,
        containsPair('step', 'store_launch'),
      );
    });

    testWidgets('has no way past the force-update screen', (tester) async {
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);
      await robot.launch();
      await robot.settle();

      expect(robot.retryButton, findsNothing);
      expect(robot.checking, findsNothing);
    });

    testWidgets('reports both versions to analytics', (tester) async {
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      // No session was started, so this is the only event: the gate runs
      // before the journal and before any session.
      expect(robot.analytics.events, [
        event('update_required', {
          'min_app_version': '9.0.0',
          'app_version': AgentStub.appVersion,
        }),
      ]);
    });

    testWidgets('meets accessibility guidelines when blocking', (tester) async {
      final config = ConfigStub()..serves(minAppVersion: '9.0.0');
      final robot = ConfigRobot(tester, config);

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => tester.pumpAndSettle(),
      );
    });
  });

  group('startup gate failures', () {
    testWidgets('blocks with a retry when the server cannot be reached', (
      tester,
    ) async {
      final config = ConfigStub()..script([configUnreachable()]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      // Fails shut: an unreachable server is not permission to run.
      expect(robot.failure, findsOneWidget);
      expect(robot.retryButton, findsOneWidget);
      expect(robot.welcome, findsNothing);
    });

    testWidgets('blocks when the server refuses', (tester) async {
      final config = ConfigStub()..script([configRefused(500)]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.failure, findsOneWidget);
    });

    testWidgets('blocks when the config cannot be read', (tester) async {
      final config = ConfigStub()..script([configMalformed()]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.failure, findsOneWidget);
    });

    testWidgets('blocks when a field the gate needs is missing', (
      tester,
    ) async {
      // A partial config is not a usable one: both fields are required.
      final config = ConfigStub()
        ..script([configMalformed('{"min_app_version": "1.0.0"}')]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.failure, findsOneWidget);
    });

    testWidgets('the retry asks again and lets the app through', (
      tester,
    ) async {
      final config = ConfigStub()
        ..script([configUnreachable(), servesConfig()]);
      final robot = ConfigRobot(tester, config);
      await robot.launch();
      await robot.settle();
      expect(robot.failure, findsOneWidget);

      await robot.tapRetry();

      expect(robot.failure, findsNothing);
      expect(robot.welcome, findsOneWidget);
      expect(config.calls, 2);
    });

    testWidgets('the retry is replaced by the check while it runs', (
      tester,
    ) async {
      // What keeps one read in flight at a time: there is no retry button on
      // screen to press twice, so the bloc needs no re-entrancy guard.
      final config = ConfigStub()
        ..script([configUnreachable(), configDelayed(servesConfig())]);
      final robot = ConfigRobot(tester, config);
      await robot.launch();
      await robot.settle();

      await tester.tap(robot.retryButton);
      await tester.pump();

      expect(robot.checking, findsOneWidget);
      expect(robot.retryButton, findsNothing);

      await robot.settle();
      expect(config.calls, 2);
    });

    testWidgets('a minimum it cannot parse is a failure, not an update', (
      tester,
    ) async {
      // A version neither side can parse is a misconfigured server, not an
      // out-of-date app: the store cannot fix it, so the update screen would
      // be a lie. Still fails shut, and still reports.
      final config = ConfigStub()..serves(minAppVersion: 'not-a-version');
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.failure, findsOneWidget);
      expect(robot.updateRequired, findsNothing);
      expect(robot.welcome, findsNothing);
      expect(
        robot.analytics.exceptions.single.properties,
        containsPair('step', 'config_load'),
      );
      // Not an update_required: the app never established a real minimum.
      expect(robot.analytics.events, isEmpty);
    });

    testWidgets('reports the failure to error tracking, without a version', (
      tester,
    ) async {
      final config = ConfigStub()..script([configUnreachable()]);
      final robot = ConfigRobot(tester, config);

      await robot.launch();
      await robot.settle();

      expect(robot.analytics.exceptions, hasLength(1));
      expect(
        robot.analytics.exceptions.single.properties,
        containsPair('step', 'config_load'),
      );
      // A failure to read the config is not an update_required: the app does
      // not know which it is, and must not report a version it never saw.
      expect(robot.analytics.events, isEmpty);
    });

    testWidgets('meets accessibility guidelines when it cannot ask', (
      tester,
    ) async {
      final config = ConfigStub()..script([configUnreachable()]);
      final robot = ConfigRobot(tester, config);

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) => tester.pumpAndSettle(),
      );
    });
  });
}
