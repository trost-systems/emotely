import 'package:agent_client/agent_client.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_session/src/bloc/session_bloc.dart';
import 'package:feature_session/src/l10n/l10n.dart';
import 'package:feature_session/src/widgets/answer_input.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

/// Wires a [SessionBloc] to the [AgentClient] in scope and starts a session
/// — or, with [resume], the id of a stored session, picks that one up where
/// the journal left it — in the language the screen shows: the locale the
/// app resolved against the ones it ships, not the device's own list.
class const SessionPage({final String? resume, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Read here, not in `create`, which runs once and must not listen.
    final locale = Localizations.localeOf(context);
    return BlocProvider(
      create: (_) =>
          GetIt.I<SessionBloc>()
            ..add(SessionEvent.started(locale: locale, resume: resume)),
      child: const SessionView(),
    );
  }
}

/// One journaling session, one widget per [SessionState].
class const SessionView({super.key}) extends StatelessWidget {
  static const retryKey = Key('session_view.retry');
  static const questionKey = Key('session_view.question');
  static const startOverKey = Key('session_view.start_over');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.sessionTitle)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<SessionBloc, SessionState>(
          builder: (context, state) => switch (state) {
            SessionInitial() || SessionLoading() => const _Thinking(),
            SessionAwaitingAnswer(:final pending, :final answered) => _Question(
              pending: pending,
              answered: answered,
            ),
            SessionCompleted(:final entry, :final questions) => EntryView(
              entry: entry,
              questions: questions,
            ),
            SessionFailure(:final reason) => _Failure(reason: reason),
          },
        ),
      ),
    ),
  );
}

class const _Thinking() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const CircularProgressIndicator(),
        Text(context.l10n.thinkingLabel),
      ],
    ),
  );
}

class const _Question({
  required final PendingQuestion pending,
  required final int answered,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            context.l10n.questionNumber(answered + 1),
            style: theme.textTheme.labelLarge,
          ),
          Text(
            pending.question.question,
            key: SessionView.questionKey,
            style: theme.textTheme.headlineSmall,
          ),
          AnswerInput(
            // A new tool call gets a fresh widget, never a stale draft.
            key: ValueKey(pending.toolCallId),
            question: pending.question,
            onSubmit: (answer) =>
                context.read<SessionBloc>().add(SessionEvent.answered(answer)),
          ),
        ],
      ),
    );
  }
}

class const _Failure({required final SessionFailureReason reason})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(_messageFor(strings), textAlign: TextAlign.center),
          // Resending cannot help a session the agent will not continue.
          if (reason == SessionFailureReason.cannotContinue)
            FilledButton(
              key: SessionView.startOverKey,
              onPressed: () => context.read<SessionBloc>().add(
                const SessionEvent.restarted(),
              ),
              child: Text(strings.startOverButton),
            )
          else
            FilledButton(
              key: SessionView.retryKey,
              onPressed: () =>
                  context.read<SessionBloc>().add(const SessionEvent.retried()),
              child: Text(strings.tryAgainButton),
            ),
        ],
      ),
    );
  }

  /// The words for each [SessionFailureReason]: the bloc names the reason,
  /// this is the one place the session's failure copy is chosen.
  String _messageFor(SessionLocalizations strings) => switch (reason) {
    SessionFailureReason.unreachable => strings.unreachableMessage,
    // It is us and not their connection, what they wrote is safe, and
    // waiting is what helps (#107).
    SessionFailureReason.modelUnavailable => strings.modelUnavailableMessage,
    SessionFailureReason.refused => strings.refusedMessage,
    SessionFailureReason.cannotContinue => strings.cannotContinueMessage,
    SessionFailureReason.entrySaveFailed => strings.entrySaveFailedMessage,
    SessionFailureReason.sessionReadFailed => strings.sessionReadFailedMessage,
  };
}
