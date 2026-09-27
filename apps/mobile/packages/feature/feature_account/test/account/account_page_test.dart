import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

import '../fake_account_navigator.dart';

/// Drives the account screen on its own route, composed the way the app
/// composes it: the utilities and this feature registered over a scripted
/// Supabase, and a fake navigator for what the app would do.
class _AccountRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
}) {
  final analytics = AnalyticsSpy();
  final navigator = FakeAccountNavigator();

  static const openKey = Key('launcher.open');

  Finder get launcher => find.byKey(openKey);
  Finder get account => find.byType(AccountPage);
  Finder get deleteAccount => find.byKey(AccountView.deleteKey);
  Finder get confirmation => find.byType(AlertDialog);
  Finder get confirm => find.byKey(AccountView.confirmKey);
  Finder get cancel => find.byKey(AccountView.cancelKey);
  Finder get retry => find.byKey(AccountView.retryKey);
  Finder get signOut => find.byKey(AccountView.signOutKey);
  Finder get failure => find.text(AccountView.failureMessage);
  Finder get busy => find.byType(CircularProgressIndicator);

  /// A launcher route that pushes the account screen, as the More tab
  /// does. Reading this composes the container.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    registerAccount(GetIt.I);
    GetIt.I.registerSingleton<AccountNavigator>(navigator);
    return pageUnderTest(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: openKey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountPage()),
              ),
              child: const Text('Account'),
            ),
          ),
        ),
      ),
    );
  }

  /// Signed in, on the account screen.
  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
    await tap(launcher);
  }

  Future<void> askToDelete() => tap(deleteAccount);

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle();
  }

  Future<void> back() async {
    await tester.pageBack();
    await settle();
  }
}

void main() {
  group(AccountPage, () {
    const deletion = 'POST /rest/v1/rpc/delete_account';
    const logout = 'POST /auth/v1/logout';

    /// The user is gone by the time the SDK tells Supabase about the
    /// sign-out; Supabase refuses, and the SDK treats that as signed out.
    final userGone = authRefused(
      statusCode: 403,
      errorCode: 'user_not_found',
      message: 'User not found',
    );

    _AccountRobot robotWith(
      WidgetTester tester, {
      List<AuthRound> deletions = const [],
      AuthRound? logoutAnswer,
    }) {
      final supabase = SupabaseStub()
        ..rest(deletion, deletions)
        ..script(logout: [logoutAnswer ?? userGone]);
      return _AccountRobot(tester, supabase: supabase);
    }

    testWidgets('deletes the account once the loss is confirmed', (
      tester,
    ) async {
      final robot = robotWith(tester, deletions: [rpcReturned(null)]);
      await robot.launch();

      expect(robot.account, findsOneWidget);
      expect(find.text(AccountView.consequenceMessage), findsOneWidget);
      expect(robot.confirmation, findsNothing);

      await robot.askToDelete();

      expect(robot.confirmation, findsOneWidget);
      expect(find.text(AccountView.confirmationMessage), findsOneWidget);
      expect(robot.supabase.to(deletion), isEmpty);

      await robot.tap(robot.confirm);

      expect(robot.supabase.to(deletion), hasLength(1));
      expect(robot.supabase.to(logout), hasLength(1));
      // The route left on its own; the app's root has swapped underneath.
      expect(robot.account, findsNothing);
      expect(robot.launcher, findsOneWidget);
      expect(robot.analytics.events, [event('account_deleted')]);
      expect(robot.analytics.resets, 1);
    });

    testWidgets('tells PostHog, and forgets the choice, before the session '
        'ends', (tester) async {
      // What PostHog had heard when the SDK told the server; the session
      // was dropped on the device just before, and the app follows it.
      late List<CapturedEvent> heard;
      late int resets;
      late final _AccountRobot robot;
      robot = robotWith(
        tester,
        deletions: [rpcReturned(null)],
        logoutAnswer: () {
          heard = [...robot.analytics.events];
          resets = robot.analytics.resets;
          return userGone();
        },
      );
      await robot.launch();
      await robot.askToDelete();

      await robot.tap(robot.confirm);

      expect(heard, [event('account_deleted')]);
      expect(resets, 1);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.askToDelete();

      await robot.tap(robot.cancel);

      expect(robot.confirmation, findsNothing);
      expect(robot.account, findsOneWidget);

      await robot.back();

      expect(robot.launcher, findsOneWidget);
      expect(robot.supabase.to(deletion), isEmpty);
      expect(robot.supabase.to(logout), isEmpty);
      expect(robot.analytics.events, isEmpty);
    });

    testWidgets('shows progress while the account is deleted', (tester) async {
      final robot = robotWith(
        tester,
        deletions: [delayedAuth(rpcReturned(null))],
      );
      await robot.launch();
      await robot.askToDelete();

      await tester.tap(robot.confirm);
      await tester.pump();

      expect(robot.busy, findsOneWidget);
      expect(robot.deleteAccount, findsNothing);

      await robot.settle();

      expect(robot.account, findsNothing);
    });

    testWidgets('cannot be left while the account is being deleted', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        deletions: [delayedAuth(rpcReturned(null))],
      );
      await robot.launch();
      await robot.askToDelete();

      await tester.tap(robot.confirm);
      await tester.pump();
      // The server is deleting the account whatever happens on this side;
      // leaving now would keep a session for a user who no longer exists.
      await robot.back();

      expect(robot.supabase.to(logout), hasLength(1));
      expect(robot.account, findsNothing);
      expect(robot.analytics.events, [event('account_deleted')]);
      expect(robot.analytics.resets, 1);
    });

    testWidgets('explains when the account cannot be deleted, and retries', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        deletions: [restRefused(), rpcReturned(null)],
      );
      await robot.launch();
      await robot.askToDelete();

      await robot.tap(robot.confirm);

      expect(robot.account, findsOneWidget);
      expect(robot.failure, findsOneWidget);
      expect(robot.supabase.to(logout), isEmpty);
      // Reported while PostHog still knows who this is: the user is only
      // forgotten once the deletion went through.
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'account_deletion'},
        ),
      ]);
      expect(robot.analytics.resets, 0);

      await robot.tap(robot.retry);

      expect(robot.supabase.to(deletion), hasLength(2));
      expect(robot.account, findsNothing);
      expect(robot.analytics.events.last, event('account_deleted'));
      expect(robot.analytics.resets, 1);
    });

    testWidgets('asks the app to sign out when the account cannot be deleted', (
      tester,
    ) async {
      // A deletion that failed on this side may have succeeded on the
      // server; signing out is the way to stop holding a token for a user
      // who may no longer exist — and signing out is the app's to do.
      final robot = robotWith(tester, deletions: [restRefused()]);
      await robot.launch();
      await robot.askToDelete();
      await robot.tap(robot.confirm);

      expect(robot.failure, findsOneWidget);

      await robot.tap(robot.signOut);

      expect(robot.navigator.signOuts, 1);
      expect(robot.account, findsNothing);
      expect(robot.launcher, findsOneWidget);
    });

    testWidgets('leaves even when the sign-out cannot reach the server', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        deletions: [rpcReturned(null)],
        logoutAnswer: authUnreachable(),
      );
      await robot.launch();
      await robot.askToDelete();

      await robot.tap(robot.confirm);

      expect(robot.account, findsNothing);
      expect(robot.analytics.events.last, event('account_deleted'));
      expect(robot.analytics.resets, 1);
    });

    testWidgets('meets accessibility guidelines in every state', (
      tester,
    ) async {
      final robot = robotWith(tester, deletions: [restRefused()]);
      await robot.supabase.signedIn();
      // Each pass is a fresh composition, so the container is emptied first.
      Future<Widget> freshApp() async {
        await GetIt.I.reset();
        return KeyedSubtree(key: UniqueKey(), child: robot.app);
      }

      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) => robot.tap(robot.launcher),
      );
      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) async {
          await robot.tap(robot.launcher);
          await robot.askToDelete();
        },
      );
      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) async {
          await robot.tap(robot.launcher);
          await robot.askToDelete();
          await robot.tap(robot.confirm);
        },
      );
    });
  });
}
