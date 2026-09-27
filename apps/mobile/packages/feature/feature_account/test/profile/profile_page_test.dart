import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestApiException;
import 'package:testing/testing.dart';

import 'profile_robot.dart';

void main() {
  group(ProfilePage, () {
    ProfileRobot robotWith(
      WidgetTester tester, {
      Map<String, Object?>? row,
      List<AuthRound> reads = const [],
      List<AuthRound> saves = const [],
    }) {
      final supabase = SupabaseStub()
        ..rest(profileRead, reads)
        ..always(profileRead, rows([?row]))
        ..rest(profileSave, saves);
      return ProfileRobot(tester, supabase: supabase);
    }

    testWidgets('shows the name, its initial, the address and the method', (
      tester,
    ) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'peter'));
      await robot.launch();

      expect(robot.name, 'peter');
      expect(robot.initial, 'P');
      expect(find.text(ProfileView.nameHelper), findsOneWidget);
      expect(
        find.descendant(
          of: robot.email,
          matching: find.text(SupabaseStub.email),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Text>(robot.method).data, ProfileView.viaGoogle);
      expect(robot.placeholderLine, findsNothing);
    });

    for (final (provider, email, line) in [
      ('email', SupabaseStub.email, ProfileView.viaEmailCode),
      ('apple', 'peter@icloud.com', ProfileView.viaApple),
      ('apple', 'x7k2@privaterelay.appleid.com', ProfileView.viaAppleRelay),
      ('phone', SupabaseStub.email, ProfileView.viaUnknown),
    ]) {
      testWidgets('says how an account of $provider signs in ($email)', (
        tester,
      ) async {
        final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
        await robot.launch(email: email, provider: provider);

        expect(tester.widget<Text>(robot.method).data, line);
      });
    }

    testWidgets('hides an address Apple made up, and says so', (tester) async {
      const relay = 'x7k2@privaterelay.appleid.com';
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch(email: relay, provider: 'apple');

      expect(find.text(relay), findsNothing);
      expect(
        find.descendant(
          of: robot.email,
          matching: find.text(ProfileView.hiddenByApple),
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaves the address out for an account without one', (
      tester,
    ) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch(email: '');

      expect(robot.email, findsNothing);
      expect(robot.method, findsNothing);
      expect(robot.signOut, findsOneWidget);
    });

    testWidgets('asks for a name when there is none yet', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      expect(robot.name, isEmpty);
      expect(find.text(ProfileView.nameHint), findsOneWidget);
      expect(robot.initial, isNull);
    });

    testWidgets('invites replacing a name it picked', (tester) async {
      final robot = robotWith(
        tester,
        row: profileRow(displayName: 'Pebble', nameIsPlaceholder: true),
      );
      await robot.launch();

      expect(robot.name, 'Pebble');
      expect(
        tester.widget<Text>(robot.placeholderLine).data,
        'Pebble · a nickname I picked – tell me yours',
      );
      expect(find.text(ProfileView.nameHelper), findsNothing);
    });

    testWidgets('saves a new name on the done key, and says so', (
      tester,
    ) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      await robot.type('  zoë ');
      await robot.done();

      expect(robot.supabase.bodies(profilesPath).single, {
        'display_name': 'zoë',
        'name_is_placeholder': false,
      });
      expect(robot.message, ProfileView.savedMessage);
      expect(robot.analytics.events, [
        event('display_name_changed', {
          'flow_version': testOnboardingFlowVersion,
          'variant': 'control',
          'source': 'profile',
        }),
      ]);
      expect(robot.name, 'zoë');
      expect(robot.initial, 'Z');
    });

    testWidgets('saves on leaving the field, once', (tester) async {
      final robot = robotWith(
        tester,
        row: profileRow(displayName: 'Pebble', nameIsPlaceholder: true),
      );
      await robot.launch();

      await robot.type('Petra');
      await robot.leaveField();

      // Typed by the user, so no longer a placeholder.
      expect(robot.supabase.bodies(profilesPath).single, {
        'display_name': 'Petra',
        'name_is_placeholder': false,
      });
      expect(robot.message, ProfileView.savedMessage);
      expect(robot.placeholderLine, findsNothing);
    });

    testWidgets('saves once when the field is left again mid-save', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        row: profileRow(displayName: 'Peter'),
        saves: [delayedAuth(rowsChanged())],
      );
      await robot.launch();

      await robot.type('Petra');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // Back into the field and out again while the name is on its way.
      await tester.tap(robot.nameField);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 1));
      await robot.settle();

      expect(robot.supabase.to(profileSave), hasLength(1));
      expect(robot.name, 'Petra');
      expect(robot.message, ProfileView.savedMessage);
    });

    testWidgets('writes nothing when the name did not change', (tester) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      await robot.type('Peter');
      await robot.done();

      expect(robot.supabase.to(profileSave), isEmpty);
      expect(robot.message, isNull);
    });

    testWidgets('goes back to the saved name when the field is emptied', (
      tester,
    ) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      await robot.type('   ');
      await robot.done();

      expect(robot.supabase.to(profileSave), isEmpty);
      expect(robot.name, 'Peter');
      expect(robot.message, ProfileView.emptyMessage);
    });

    testWidgets('says nothing when an empty field stays empty', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.type(' ');
      await robot.done();

      expect(robot.supabase.to(profileSave), isEmpty);
      expect(robot.message, isNull);
    });

    testWidgets('goes back to the saved name when the name cannot be used', (
      tester,
    ) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      await robot.type('Pe\tter');
      await robot.done();

      expect(robot.supabase.to(profileSave), isEmpty);
      expect(robot.name, 'Peter');
      expect(robot.message, ProfileView.refusedMessage);
    });

    testWidgets('goes back to the saved name when saving fails, and reports '
        'it', (tester) async {
      final robot = robotWith(
        tester,
        row: profileRow(displayName: 'Peter'),
        saves: [restRefused()],
      );
      await robot.launch();

      await robot.type('Petra');
      await robot.done();

      expect(robot.name, 'Peter');
      expect(robot.message, ProfileView.saveFailedMessage);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_save'},
        ),
      ]);
    });

    testWidgets('takes forty code points and no more, and counts them', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.type('😀' * 45);

      expect(robot.name, '😀' * 40);
      expect(find.text('40/40'), findsOneWidget);
    });

    testWidgets('says so when the name cannot be read, and reads it again', (
      tester,
    ) async {
      final robot = robotWith(
        tester,
        row: profileRow(displayName: 'Peter'),
        reads: [restRefused()],
      );
      await robot.launch();

      expect(robot.nameField, findsNothing);
      expect(find.text(ProfileView.loadFailedMessage), findsOneWidget);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_load'},
        ),
      ]);

      await robot.tap(robot.retry);

      expect(robot.name, 'Peter');
    });

    testWidgets('shows progress while the name is read', (tester) async {
      final robot = robotWith(
        tester,
        reads: [
          delayedAuth(rows([profileRow(displayName: 'Peter')])),
        ],
      );
      await robot.supabase.signedIn();
      await tester.pumpWidget(robot.app);
      await tester.pump();

      expect(robot.busy, findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await robot.settle();

      expect(robot.name, 'Peter');
    });

    testWidgets('signs out through the app, in plain text', (tester) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      final label = tester.widget<Text>(
        find.descendant(of: robot.signOut, matching: find.byType(Text)),
      );
      final error = Theme.of(tester.element(robot.signOut)).colorScheme.error;
      expect(label.style?.color, isNot(error));

      await robot.tap(robot.signOut);

      expect(robot.navigator.signOuts, 1);
    });

    testWidgets('offers no way to delete the account', (tester) async {
      final robot = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await robot.launch();

      expect(find.byType(AccountPage), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
    });

    testWidgets('meets accessibility guidelines with a name and without', (
      tester,
    ) async {
      final named = robotWith(tester, row: profileRow(displayName: 'Peter'));
      await named.supabase.signedIn(provider: 'google');
      await tester.expectMeetsAccessibilityGuidelines(named.app);

      await GetIt.I.reset();
      final nameless = robotWith(tester);
      await nameless.supabase.signedIn(provider: 'email');
      await tester.expectMeetsAccessibilityGuidelines(
        KeyedSubtree(key: UniqueKey(), child: nameless.app),
      );
    });
  });
}
