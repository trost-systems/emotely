import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/l10n/l10n.dart';
import 'package:feature_onboarding/src/view/nicknames.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group(OnboardingFlow, () {
    const flow = onboardingFlow;
    OnboardingProgress done(Set<OnboardingStepId> completed) =>
        OnboardingProgress(completed: completed);

    test('is version 1: welcome, value, name and hello before sign-up, '
        'and the name once more after a sign-in', () {
      expect(flow.version, 1);
      expect(
        [for (final step in flow.of(OnboardingPhase.beforeSignUp)) step.id],
        [
          OnboardingStepId.welcome,
          OnboardingStepId.value,
          OnboardingStepId.name,
          OnboardingStepId.hello,
        ],
      );
      expect(
        [for (final step in flow.of(OnboardingPhase.afterSignIn)) step.id],
        [OnboardingStepId.accountName],
      );
    });

    test('resumes at the first step not done', () {
      const phase = OnboardingPhase.beforeSignUp;

      expect(flow.current(phase, done({}))?.id, OnboardingStepId.welcome);
      expect(
        flow.current(phase, done({OnboardingStepId.welcome}))?.id,
        OnboardingStepId.value,
      );
      expect(
        flow
            .current(
              phase,
              done({OnboardingStepId.welcome, OnboardingStepId.value}),
            )
            ?.id,
        OnboardingStepId.name,
      );
    });

    test('is ready for the account once every step before sign-up is done, '
        'whatever happens after sign-in', () {
      final before = {
        OnboardingStepId.welcome,
        OnboardingStepId.value,
        OnboardingStepId.name,
      };

      expect(flow.readyForAccount(done(before)), isFalse);
      expect(
        flow.readyForAccount(done({...before, OnboardingStepId.hello})),
        isTrue,
      );
      expect(
        flow.current(
          OnboardingPhase.beforeSignUp,
          done({...before, OnboardingStepId.hello}),
        ),
        isNull,
      );
    });

    test('knows the step before each, within its phase only', () {
      expect(flow.before(const WelcomeStep()), isNull);
      expect(flow.before(const ValueStep())?.id, OnboardingStepId.welcome);
      expect(flow.before(const HelloStep())?.id, OnboardingStepId.name);
      expect(flow.before(NameStep.afterSignIn), isNull);
    });

    test('places each step in its phase for analytics', () {
      final hello = flow.view(const HelloStep());
      final account = flow.view(NameStep.afterSignIn);

      expect(
        (hello.id, hello.index, hello.phase),
        (OnboardingStepId.hello, 3, OnboardingPhase.beforeSignUp),
      );
      expect(
        (account.id, account.index, account.phase),
        (OnboardingStepId.accountName, 0, OnboardingPhase.afterSignIn),
      );
    });

    test(
      'counts the steps that ask something in the dots, not the greeting',
      () {
        expect(
          [
            for (final step in flow.steps)
              if (step.showsProgress) step.id,
          ],
          [
            OnboardingStepId.welcome,
            OnboardingStepId.value,
            OnboardingStepId.name,
          ],
        );
      },
    );
  });

  group(OnboardingProgress, () {
    test('greets by the placeholder after a skip, by the typed name '
        'otherwise', () {
      const typed = OnboardingProgress(draft: '  Peter ');
      const skipped = OnboardingProgress(draft: 'Pe', placeholder: 'Wren');

      expect(
        (typed.displayName, typed.nameSource),
        ('Peter', NameSource.typed),
      );
      expect(
        (skipped.displayName, skipped.nameSource),
        ('Wren', NameSource.placeholder),
      );
    });

    test('never prints the name it holds', () {
      const progress = OnboardingProgress(draft: 'Needle', placeholder: 'Pip');

      expect('$progress', isNot(contains('Needle')));
      expect('$progress', isNot(contains('Pip')));
    });
  });

  group(OnboardingLocalizations, () {
    test('nicknames the user with distinct names the profile takes, in every '
        'locale', () {
      for (final locale in OnboardingLocalizations.supportedLocales) {
        final names = lookupOnboardingLocalizations(locale).nicknames;

        expect(names, isNotEmpty, reason: '$locale');
        expect(names.toSet(), hasLength(names.length), reason: '$locale');
        for (final name in names) {
          expect(
            DisplayName.check(name),
            isA<DisplayNameAccepted>(),
            reason: '$locale: $name',
          );
        }
      }
    });
  });
}
