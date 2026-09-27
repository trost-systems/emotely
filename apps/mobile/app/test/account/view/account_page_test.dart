import 'package:feature_account/feature_account.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/helpers.dart';
import '../account_robot.dart';

void main() {
  group(AccountPage, () {
    const deletion = 'POST /rest/v1/rpc/delete_account';
    const logout = 'POST /auth/v1/logout';
    const journalViewed = {'entries': 0, 'open_session': false};

    /// The user is gone by the time the SDK tells Supabase about the
    /// sign-out; Supabase refuses, and the SDK treats that as signed out.
    final userGone = authRefused(
      statusCode: 403,
      errorCode: 'user_not_found',
      message: 'User not found',
    );

    AccountRobot robotWith(
      WidgetTester tester, {
      List<AuthRound> deletions = const [],
      AuthRound? logoutAnswer,
    }) {
      final supabase = SupabaseStub()
        ..rest(deletion, deletions)
        ..script(logout: [logoutAnswer ?? userGone]);
      return AccountRobot(tester, supabase: supabase, agent: AgentStub());
    }

    testWidgets('deletes the account once the loss is confirmed', (
      tester,
    ) async {
      final robot = robotWith(tester, deletions: [rpcReturned(null)]);
      await robot.launch();

      expect(robot.account, findsOneWidget);
      expect(robot.confirmation, findsNothing);

      await robot.askToDelete();

      expect(robot.confirmation, findsOneWidget);
      expect(find.text(AccountView.confirmationMessage), findsOneWidget);
      expect(robot.supabase.to(deletion), isEmpty);

      await robot.tap(robot.confirm);

      expect(robot.supabase.to(deletion), hasLength(1));
      expect(robot.supabase.to(logout), hasLength(1));
      expect(robot.welcome, findsOneWidget);
      expect(robot.account, findsNothing);
      expect(robot.home, findsNothing);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('account_deleted'),
      ]);
      expect(robot.analytics.resets, 1);
    });

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.askToDelete();

      await robot.tap(robot.cancel);

      expect(robot.confirmation, findsNothing);
      expect(robot.account, findsOneWidget);
      expect(robot.deleteAccount, findsOneWidget);

      await robot.back();

      expect(robot.more, findsOneWidget);
      expect(robot.supabase.to(deletion), isEmpty);
      expect(robot.supabase.to(logout), isEmpty);
      expect(robot.analytics.events, [event('journal_viewed', journalViewed)]);
      expect(robot.analytics.resets, 0);
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

      expect(robot.welcome, findsOneWidget);
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

      expect(robot.welcome, findsOneWidget);
      expect(robot.account, findsNothing);
      expect(robot.home, findsNothing);
      expect(robot.supabase.to(logout), hasLength(1));
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('account_deleted'),
      ]);
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
      expect(robot.retry, findsOneWidget);
      expect(robot.supabase.to(logout), isEmpty);
      expect(robot.analytics.events, [event('journal_viewed', journalViewed)]);
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
      expect(robot.welcome, findsOneWidget);
      expect(robot.analytics.events.last, event('account_deleted'));
      expect(robot.analytics.resets, 1);
    });

    testWidgets('offers to sign out when the account cannot be deleted', (
      tester,
    ) async {
      // A deletion that failed on this side may have succeeded on the
      // server; signing out is the way to stop holding a token for a user
      // who may no longer exist.
      final robot = robotWith(
        tester,
        deletions: [restRefused()],
        logoutAnswer: signedOut(),
      );
      await robot.launch();
      await robot.askToDelete();
      await robot.tap(robot.confirm);

      expect(robot.failure, findsOneWidget);

      await robot.tap(robot.signOut);

      expect(robot.welcome, findsOneWidget);
      expect(robot.account, findsNothing);
      expect(robot.home, findsNothing);
      expect(robot.supabase.to(logout), hasLength(1));
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('signed_out'),
      ]);
      expect(robot.analytics.resets, 1);
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

      expect(robot.welcome, findsOneWidget);
      expect(robot.account, findsNothing);
      expect(robot.analytics.events.last, event('account_deleted'));
      expect(robot.analytics.resets, 1);
    });

    testWidgets('never lets journal content leave the device (ADR 0005)', (
      tester,
    ) async {
      const needle = 'needle: the day the sea turned violet';
      // The refusal quotes the row it choked on, as Postgres does; the
      // report of it must not.
      final robot = robotWith(
        tester,
        deletions: [
          restRefused(message: 'Failing row contains ($needle)'),
          rpcReturned(null),
        ],
      );
      robot.supabase.rest('GET /rest/v1/entries', [
        rows([
          entryRow(
            id: 'e-needle',
            summary: needle,
            createdAt: DateTime.utc(2026, 9, 7, 20),
          ),
        ]),
      ]);
      await robot.launch();
      await robot.askToDelete();
      await robot.tap(robot.confirm);
      await robot.tap(robot.retry);

      expect(robot.welcome, findsOneWidget);
      expect(robot.analytics.exceptions, hasLength(1));
      final outgoing = robot.analytics.outgoingStrings.toList();
      expect(outgoing, contains('account_deleted'));
      for (final leaving in outgoing) {
        expect(leaving, isNot(contains('needle')));
        expect(leaving, isNot(contains('violet')));
      }
    });

    testWidgets('meets accessibility guidelines with and without the '
        'confirmation', (tester) async {
      final robot = robotWith(tester, deletions: [restRefused()]);
      await robot.supabase.signedIn();
      // Pumping the same widget type again updates the tree in place, and
      // the navigator would still be on the account screen; a key per pass
      // starts each one from the journal.
      // Each pass is a fresh composition, so the container is emptied first:
      // composing twice into a filled container fails loudly by design.
      Future<Widget> freshApp() async {
        await GetIt.I.reset();
        return KeyedSubtree(key: UniqueKey(), child: robot.app);
      }

      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) => robot.openAccount(),
      );
      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) async {
          await robot.openAccount();
          await robot.askToDelete();
        },
      );
      await tester.expectMeetsAccessibilityGuidelines(
        await freshApp(),
        prepare: (tester) async {
          await robot.openAccount();
          await robot.askToDelete();
          await robot.tap(robot.confirm);
        },
      );
    });
  });
}
