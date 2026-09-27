import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/view/onboarding_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestApiException;
import 'package:testing/testing.dart';

import 'onboarding_robot.dart';

void main() {
  const flow = {
    'flow_version': testOnboardingFlowVersion,
    'variant': 'control',
  };

  Map<String, Object> step(
    String id,
    int index, [
    String phase = 'before_sign_up',
  ]) => {...flow, 'step_id': id, 'step_index': index, 'phase': phase};

  /// A run of the flow that reached sign-up, as the device keeps it.
  Map<String, Object?> readyForAccount({
    String draft = 'Peter',
    String? placeholder,
  }) => {
    'flow_version': onboardingFlowVersion,
    'completed': ['welcome', 'value', 'name', 'hello'],
    'draft': draft,
    'placeholder': placeholder,
    'started': true,
  };

  group('before sign-up', () {
    testWidgets('walks from Welcome through what emotely gives and the name '
        'to the greeting', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();

      expect(robot.welcome, findsOneWidget);
      expect(find.text(welcomeTitle), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);

      await robot.tap(robot.getStarted);

      expect(robot.value, findsOneWidget);
      for (final promise in promises) {
        expect(find.text(promise.title), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);

      await robot.tap(robot.valueContinue);

      expect(robot.name, findsOneWidget);
      expect(find.text(nameTitle), findsOneWidget);
      expect(tester.widget<TextField>(robot.nameField).autofillHints, [
        AutofillHints.givenName,
      ]);

      await robot.type('  Peter ');
      await robot.tap(robot.nameContinue);

      expect(robot.hello, findsOneWidget);
      expect(find.text(helloTitle('Peter')), findsOneWidget);
      final title = tester.widget<Text>(find.text(helloTitle('Peter')));
      expect(title.style?.fontStyle, FontStyle.normal);
    });

    testWidgets('is ready for the account once the greeting is left, and '
        'waits there for the router', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();
      await robot.type('Peter');
      await robot.tap(robot.nameContinue);

      expect(robot.store.readyForAccount, isFalse);

      await robot.tap(robot.helloStart);

      expect(robot.store.readyForAccount, isTrue);
      expect(robot.waiting, findsOneWidget);
      expect(robot.store.progress.displayName, 'Peter');
    });

    testWidgets('resumes at the step reached, with what was typed', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.kept({
        'flow_version': onboardingFlowVersion,
        'completed': ['welcome', 'value'],
        'draft': 'Pet',
        'placeholder': null,
        'started': true,
      });
      await robot.launch();

      expect(robot.name, findsOneWidget);
      expect(find.text('Pet'), findsOneWidget);
    });

    testWidgets('keeps every keystroke on the device', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();
      await robot.type('Pete');

      expect(robot.store.progress.draft, 'Pete');
    });

    testWidgets('continues only with a name the profile would take', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();

      FilledButton button() => tester.widget<FilledButton>(
        find.descendant(
          of: robot.nameContinue,
          matching: find.byType(FilledButton),
        ),
      );

      expect(button().onPressed, isNull);

      await robot.type('   ');
      expect(button().onPressed, isNull);
      expect(find.text(nameTooLong), findsNothing);

      await robot.type('a' * 41);
      expect(button().onPressed, isNull);
      expect(find.text(nameTooLong), findsOneWidget);

      await robot.type('Pe\tter');
      expect(button().onPressed, isNull);
      expect(find.text(nameControlCharacter), findsOneWidget);

      // The keyboard's "done" does not slip past the check either.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await robot.settle();
      expect(robot.name, findsOneWidget);

      await robot.type('😀' * 40);
      expect(button().onPressed, isNotNull);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await robot.settle();
      expect(robot.hello, findsOneWidget);
    });

    testWidgets('announces a placeholder on skip, and takes it back on '
        '"Actually, I\'ll tell you"', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();
      await robot.type('Pe');
      await robot.tap(robot.skip);

      final placeholder = robot.store.progress.placeholder;
      expect(placeholderNames, contains(placeholder));
      expect(robot.skipped, findsOneWidget);
      expect(find.text(skippedTitle), findsOneWidget);
      expect(find.text(skippedBody(placeholder!)), findsOneWidget);

      await robot.tap(robot.tellYou);

      expect(robot.name, findsOneWidget);
      expect(robot.store.progress.placeholder, isNull);
      expect(find.text('Pe'), findsOneWidget);

      await robot.tap(robot.skip);
      await robot.tap(robot.skippedStart);

      expect(robot.store.readyForAccount, isTrue);
      expect(robot.store.progress.nameSource, NameSource.placeholder);
    });

    testWidgets('goes back a step with the arrow and with the system back', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();

      await robot.tap(robot.back);
      expect(robot.value, findsOneWidget);

      await tester.binding.handlePopRoute();
      await robot.settle();
      expect(robot.welcome, findsOneWidget);
      expect(robot.back, findsNothing);
    });

    testWidgets('moves once for a double tap', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();

      await tester.tap(robot.getStarted);
      await tester.tap(robot.getStarted, warnIfMissed: false);
      await robot.settle();

      expect(robot.value, findsOneWidget);
    });

    testWidgets('hands "I have an account" to the app, with where the user '
        'was going', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch(from: '/entries/e-1');

      await robot.tap(robot.haveAccount);

      expect(robot.navigator.asked, ['signIn from /entries/e-1']);
    });

    testWidgets('shows nothing once every step is done: the router takes the '
        'user on', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.kept(readyForAccount());
      await robot.launch();

      expect(robot.waiting, findsOneWidget);
      expect(robot.navigator.asked, isEmpty);
    });
  });

  group('after a sign-in', () {
    testWidgets('saves the typed name to the new account and goes on to the '
        'first session', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.kept(readyForAccount());
      await robot.launch(phase: OnboardingPhase.afterSignIn, from: '/x');

      expect(robot.saved, [(name: 'Peter', isPlaceholder: false)]);
      expect(robot.store.progress, const OnboardingProgress());
      expect(robot.navigator.asked, ['finish session from /x']);
    });

    testWidgets('saves a placeholder flagged as one', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.kept(readyForAccount(draft: 'Pe', placeholder: 'Maple'));
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.saved, [(name: 'Maple', isPlaceholder: true)]);
      expect(robot.navigator.asked, ['finish session from null']);
    });

    testWidgets('offers a retry when the name cannot be saved, and keeps it '
        'on the device meanwhile', (tester) async {
      final robot = OnboardingRobot(tester);
      robot.supabase.rest(profileSave, [restRefused()]);
      await robot.kept(readyForAccount());
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.retry, findsOneWidget);
      expect(find.text(saveFailedMessage), findsOneWidget);
      expect(robot.store.readyForAccount, isTrue);
      expect(robot.navigator.asked, isEmpty);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_save'},
        ),
      ]);

      await robot.tap(robot.retry);

      expect(robot.saved, [
        (name: 'Peter', isPlaceholder: false),
        (name: 'Peter', isPlaceholder: false),
      ]);
      expect(robot.navigator.asked, ['finish session from null']);
    });

    testWidgets('asks again for a name the device kept that the profile would '
        'refuse', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.kept(readyForAccount(draft: '   '));
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.saved, isEmpty);
      expect(robot.name, findsOneWidget);
    });

    testWidgets('goes straight to the journal for an account that has a '
        'name', (tester) async {
      final robot = OnboardingRobot(tester)..accountNamed('Peter');
      await robot.kept({
        'flow_version': onboardingFlowVersion,
        'completed': ['welcome'],
        'draft': '',
        'placeholder': null,
        'started': true,
      });
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.saved, isEmpty);
      expect(robot.store.progress, const OnboardingProgress());
      expect(robot.navigator.asked, ['finish journal from null']);
    });

    testWidgets('does not keep the user waiting when the profile cannot be '
        'read', (tester) async {
      final robot = OnboardingRobot(tester);
      robot.supabase.always(profileRead, restRefused());
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.navigator.asked, ['finish journal from null']);
      expect(robot.analytics.exceptions, [
        captured(
          withheld(PostgrestApiException, code: 'XX000', statusCode: 409),
          {'step': 'profile_load'},
        ),
      ]);
    });

    testWidgets('asks an account without a name once, then goes to the '
        'journal', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.name, findsOneWidget);
      expect(robot.back, findsNothing);
      expect(find.bySemanticsLabel(RegExp('Step')), findsNothing);

      await robot.type('Peter');
      await robot.tap(robot.nameContinue);

      expect(robot.saved, [(name: 'Peter', isPlaceholder: false)]);
      expect(robot.navigator.asked, ['finish journal from null']);
      expect(robot.store.progress, const OnboardingProgress());
    });

    testWidgets('saves a placeholder when that account skips', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      await robot.tap(robot.skip);

      expect(robot.saved, hasLength(1));
      expect(placeholderNames, contains(robot.saved.single.name));
      expect(robot.saved.single.isPlaceholder, isTrue);
      expect(robot.navigator.asked, ['finish journal from null']);
    });
  });

  group('analytics', () {
    testWidgets('reports the flow step by step, with how each was left', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();
      await robot.tap(robot.back);
      await robot.tap(robot.valueContinue);
      await robot.tap(robot.skip);
      await robot.tap(robot.skippedStart);

      expect(robot.eventNames, [
        'onboarding_started',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_viewed',
        'onboarding_step_completed',
        'onboarding_step_viewed',
        'onboarding_step_completed',
      ]);
      expect(robot.propertiesOf('onboarding_started'), [
        {...flow, 'step_count': 4},
      ]);
      expect(robot.propertiesOf('onboarding_step_viewed'), [
        step('welcome', 0),
        step('value', 1),
        step('name', 2),
        step('value', 1),
        step('name', 2),
        step('hello', 3),
      ]);
      expect(
        [
          for (final properties in robot.propertiesOf(
            'onboarding_step_completed',
          ))
            (properties['step_id'], properties['action']),
        ],
        [
          ('welcome', 'continue'),
          ('value', 'continue'),
          ('name', 'back'),
          ('value', 'continue'),
          ('name', 'skip'),
          ('hello', 'continue'),
        ],
      );
      for (final properties in robot.propertiesOf(
        'onboarding_step_completed',
      )) {
        expect(properties['duration_ms'], isA<int>());
      }
    });

    testWidgets('starts the flow once per run, not on every return to '
        'Welcome', (tester) async {
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.tap(robot.getStarted);
      await robot.tap(robot.back);

      expect(
        robot.eventNames.where((name) => name == 'onboarding_started'),
        hasLength(1),
      );
    });

    testWidgets('counts Welcome under the usage-analytics sheet once the '
        'user allows', (tester) async {
      final robot = OnboardingRobot(tester, choice: null);
      await robot.launch();

      expect(robot.eventNames, isEmpty);

      await GetIt.I<PostHogGate>().allow();
      await robot.settle();

      expect(robot.eventNames, [
        'usage_analytics_allowed',
        'onboarding_started',
        'onboarding_step_viewed',
      ]);
    });

    testWidgets('reports where onboarding led and where the name came from', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.kept(readyForAccount(placeholder: 'Wren'));
      await robot.launch(phase: OnboardingPhase.afterSignIn);

      expect(robot.propertiesOf('display_name_changed'), [
        {...flow, 'source': 'onboarding'},
      ]);
      expect(robot.propertiesOf('onboarding_completed'), [
        {...flow, 'next': 'session', 'name_source': 'placeholder'},
      ]);
    });

    testWidgets('reports the name step after a sign-in in its own phase', (
      tester,
    ) async {
      final robot = OnboardingRobot(tester);
      await robot.launch(phase: OnboardingPhase.afterSignIn);
      await robot.type('Peter');
      await robot.tap(robot.nameContinue);

      expect(robot.propertiesOf('onboarding_step_viewed'), [
        step('account_name', 0, 'after_sign_in'),
      ]);
      expect(robot.propertiesOf('onboarding_completed'), [
        {...flow, 'next': 'journal', 'name_source': 'typed'},
      ]);
    });

    testWidgets('never sends the name, typed or placeholder', (tester) async {
      const needle = 'Needlewort';
      final robot = OnboardingRobot(tester);
      await robot.launch();
      await robot.toName();
      await robot.type(needle);
      await robot.tap(robot.nameContinue);
      await robot.tap(robot.helloStart);
      final kept = robot.store.progress;
      // The same device after sign-up: a second composition over what the
      // first one kept.
      await GetIt.I.reset();
      final after = OnboardingRobot(tester);
      await after.kept(readyForAccount(draft: kept.draft));
      await after.launch(phase: OnboardingPhase.afterSignIn);

      expect(after.saved.single.name, needle);
      for (final spy in [robot.analytics, after.analytics]) {
        expect(spy.events, isNotEmpty);
        for (final sent in spy.outgoingStrings) {
          expect(sent, isNot(contains(needle)));
          for (final placeholder in placeholderNames) {
            expect(sent, isNot(contains(placeholder)));
          }
        }
      }
    });
  });

  group('layout', () {
    testWidgets('fits every step at twice the text size, scrolling rather '
        'than overflowing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final robot = OnboardingRobot(tester);
      await robot.launch();

      expect(tester.takeException(), isNull);
      await robot.tap(robot.getStarted);
      expect(tester.takeException(), isNull);
      await robot.tap(robot.valueContinue);
      expect(tester.takeException(), isNull);
      await robot.type('Peter');
      await robot.tap(robot.skip);
      expect(tester.takeException(), isNull);
      await robot.tap(robot.tellYou);
      await robot.tap(robot.nameContinue);
      expect(tester.takeException(), isNull);
      expect(robot.hello, findsOneWidget);
    });
  });

  group('theme', () {
    testWidgets('redraws the pictures when the phone turns dark', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final robot = OnboardingRobot(tester);
      final widget = robot.app(themeMode: ThemeMode.system);
      await robot.store.restore();
      await tester.pumpWidget(widget);
      await robot.settle();

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await robot.settle();
      await robot.toName();
      await robot.tap(robot.skip);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await robot.settle();

      expect(robot.skipped, findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('meets the guidelines on every step', (tester) async {
      final robot = OnboardingRobot(tester);
      final widget = robot.app();
      await robot.store.restore();
      await tester.expectMeetsAccessibilityGuidelines(widget);
      await robot.tap(robot.getStarted);
      await tester.expectMeetsAccessibilityGuidelines(widget);
      await robot.tap(robot.valueContinue);
      await tester.expectMeetsAccessibilityGuidelines(widget);
      await robot.type('Peter');
      await robot.tap(robot.skip);
      await tester.expectMeetsAccessibilityGuidelines(widget);
      await robot.tap(robot.tellYou);
      await robot.tap(robot.nameContinue);
      await tester.expectMeetsAccessibilityGuidelines(widget);
    });
  });
}
