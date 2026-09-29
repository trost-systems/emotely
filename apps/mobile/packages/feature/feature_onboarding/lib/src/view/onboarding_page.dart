import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/src/bloc/onboarding_bloc.dart';
import 'package:feature_onboarding/src/flow.dart';
import 'package:feature_onboarding/src/l10n/l10n.dart';
import 'package:feature_onboarding/src/navigator.dart';
import 'package:feature_onboarding/src/progress.dart';
import 'package:feature_onboarding/src/view/hello_step.dart';
import 'package:feature_onboarding/src/view/intro_steps.dart';
import 'package:feature_onboarding/src/view/name_step.dart';
import 'package:feature_onboarding/src/view/placeholder_names.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

/// Onboarding, one screen for every step: the bloc picks the step, and the
/// device remembers it (ADR 0016: screens are routes, steps are state).
/// [phase] says whether this is the flow before sign-up or its one step
/// after a sign-in; [from] is where the user was going, handed on to sign-in
/// and past it.
class const OnboardingPage({
  required final OnboardingPhase phase,
  final String? from,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        GetIt.I<OnboardingBloc>()..add(OnboardingEvent.started(phase)),
    child: OnboardingView(from: from),
  );
}

/// The step the bloc is on, or a wait while there is none to show.
class const OnboardingView({final String? from, super.key})
    extends StatelessWidget {
  static const waitingKey = Key('onboarding.waiting');
  static const savingKey = Key('onboarding.saving');
  static const retryKey = Key('onboarding.retry');

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<OnboardingBloc, OnboardingState>(
        listenWhen: (_, state) => state is OnboardingFinished,
        listener: (context, state) {
          if (state case OnboardingFinished(:final next)) {
            GetIt.I<OnboardingNavigator>().finish(
              context,
              next: next,
              from: from,
            );
          }
        },
        builder: (context, state) => switch (state) {
          OnboardingShowing() => _Step(state, from: from),
          OnboardingSaveFailed() => const _SaveFailed(),
          OnboardingSaving() => const Scaffold(
            key: savingKey,
            body: Center(child: CircularProgressIndicator()),
          ),
          OnboardingLoading() ||
          OnboardingFinished() => const Scaffold(key: waitingKey),
        },
      );
}

/// One step, with the system's back gesture taking the flow's way back
/// rather than leaving it.
class const _Step(final OnboardingShowing state, {required final String? from})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OnboardingBloc>();
    final id = state.step.id;
    void back() => bloc.add(OnboardingEvent.back(id));
    return PopScope(
      canPop: !state.canGoBack,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : back(),
      child: _view(context, bloc, back: back),
    );
  }

  Widget _view(
    BuildContext context,
    OnboardingBloc bloc, {
    required VoidCallback back,
  }) {
    final id = state.step.id;
    void forward() => bloc.add(OnboardingEvent.continued(id));
    final counted = state.step.showsProgress;
    return switch (state.step) {
      WelcomeStep() => WelcomeStepView(
        position: state.position,
        dots: state.dots,
        onGetStarted: forward,
        onHaveAccount: () =>
            GetIt.I<OnboardingNavigator>().signIn(context, from: from),
      ),
      ValueStep() => ValueStepView(
        position: state.position,
        dots: state.dots,
        onContinue: forward,
        onBack: back,
      ),
      NameStep() => NameStepView(
        draft: state.progress.draft,
        problem: state.problem,
        position: counted ? state.position : null,
        dots: counted ? state.dots : null,
        onBack: state.canGoBack ? back : null,
        onChanged: (text) => bloc.add(OnboardingEvent.nameChanged(text)),
        onContinue: forward,
        onSkip: () => bloc.add(
          OnboardingEvent.skipped(
            id,
            placeholderNames: context.l10n.placeholderNameList,
          ),
        ),
      ),
      HelloStep() => switch (state.progress.placeholder) {
        null => HelloStepView(
          name: state.progress.displayName,
          onStart: forward,
        ),
        final placeholder => SkippedStepView(
          placeholder: placeholder,
          onStart: forward,
          onTellYou: back,
        ),
      },
    };
  }
}

/// The name could not be saved to the new account: say so, and try again.
class const _SaveFailed() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              spacing: 16,
              children: [
                Text(strings.saveFailedMessage, textAlign: TextAlign.center),
                FilledButton(
                  key: OnboardingView.retryKey,
                  onPressed: () => context.read<OnboardingBloc>().add(
                    const OnboardingEvent.retried(),
                  ),
                  child: Text(strings.retryButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
