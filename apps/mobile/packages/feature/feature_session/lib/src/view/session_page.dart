import 'package:agent_client/agent_client.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_session/src/bloc/session_bloc.dart';
import 'package:feature_session/src/widgets/answer_input.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

/// Wires a [SessionBloc] to the [AgentClient] in scope and starts a session
/// — or, with [resume], the id of a stored session, picks that one up where
/// the journal left it.
class const SessionPage({final String? resume, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        GetIt.I<SessionBloc>()..add(SessionEvent.started(resume: resume)),
    child: const SessionView(),
  );
}

/// One journaling session, one widget per [SessionState].
class const SessionView({super.key}) extends StatelessWidget {
  static const retryKey = Key('session_view.retry');
  static const questionKey = Key('session_view.question');
  static const startOverKey = Key('session_view.start_over');

  /// The words for each [SessionFailureReason], the one place the session's
  /// failure copy lives, so each becomes one localized string.
  static String describe(SessionFailureReason reason) => switch (reason) {
    SessionFailureReason.unreachable =>
      'Could not reach the journaling assistant.',
    // It is us and not their connection, what they wrote is safe, and
    // waiting is what helps (#107).
    SessionFailureReason.modelUnavailable =>
      'The journaling assistant is unavailable right now. This is not your '
          'connection, and your entry is safe. Please try again later.',
    SessionFailureReason.refused =>
      'Something went wrong on our side. Please try again.',
    SessionFailureReason.cannotContinue =>
      'This session can no longer be continued. Start a new one; your '
          'saved entries are not affected.',
    SessionFailureReason.entrySaveFailed =>
      'Your entry could not be saved. Please try again.',
    SessionFailureReason.sessionReadFailed =>
      'Could not load your unfinished session. Please try again.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Journaling session')),
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
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [CircularProgressIndicator(), Text('Thinking…')],
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
          Text('Question ${answered + 1}', style: theme.textTheme.labelLarge),
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
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(SessionView.describe(reason), textAlign: TextAlign.center),
        // Resending cannot help a session the agent will not continue.
        if (reason == SessionFailureReason.cannotContinue)
          FilledButton(
            key: SessionView.startOverKey,
            onPressed: () =>
                context.read<SessionBloc>().add(const SessionEvent.restarted()),
            child: const Text('Start over'),
          )
        else
          FilledButton(
            key: SessionView.retryKey,
            onPressed: () =>
                context.read<SessionBloc>().add(const SessionEvent.retried()),
            child: const Text('Try again'),
          ),
      ],
    ),
  );
}
