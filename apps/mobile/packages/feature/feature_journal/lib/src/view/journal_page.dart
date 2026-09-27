import 'dart:async';

import 'package:feature_journal/src/bloc/journal_bloc.dart';
import 'package:feature_journal/src/navigator.dart';
import 'package:feature_journal/src/routes.dart';
import 'package:feature_journal/src/view/greeting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:material_ui/material_ui.dart';

/// Home: the user greeted by name, the journal so far and the way into the
/// next session.
///
/// Everything it leads to — the session, the consent screen, and its own
/// entries on their routes — is the app's to show, so it asks for them
/// through [JournalNavigator] (ADR 0015, ADR 0016). With [startSession] it
/// starts one as soon as the journal is read, the way "Start a session"
/// does: how a new account goes from sign-up straight into its first
/// reflection (#204).
class const JournalPage({final bool startSession = false, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<JournalBloc>()..add(const JournalEvent.loaded()),
    child: JournalView(startSession: startSession),
  );
}

/// One widget per [JournalState]; the greeting, entries and the session
/// card when ready.
class const JournalView({final bool startSession = false, super.key})
    extends StatefulWidget {
  static const startKey = Key('journal_view.start');
  static const continueKey = Key('journal_view.continue');
  static const discardKey = Key('journal_view.discard');
  static const retryKey = Key('journal_view.retry');
  static const emptyKey = Key('journal_view.empty');
  static Key entryKey(String id) => Key('journal_view.entry.$id');

  static const failureMessage = 'Could not load your journal.';

  @override
  State<JournalView> createState() => _JournalViewState();
}

class _JournalViewState() extends State<JournalView> {
  /// Whether the session asked for on the way in is still to start: once,
  /// however often the journal is read again.
  late var _toStart = widget.startSession;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocConsumer<JournalBloc, JournalState>(
        listenWhen: (_, state) => _toStart && state is JournalReady,
        listener: (context, state) {
          _toStart = false;
          unawaited(_SessionCard.open(context, resume: null));
        },
        builder: (context, state) => switch (state) {
          JournalLoading() => const Center(child: CircularProgressIndicator()),
          JournalFailure() => const _Failure(),
          JournalReady(
            :final entries,
            :final openSession,
            :final displayName,
            :final now,
          ) =>
            _Journal(
              entries: entries,
              openSession: openSession,
              greeting: JournalGreeting(now: now, name: displayName),
            ),
        },
      ),
    ),
  );
}

/// The greeting, the session card and the entries, scrolling as one so a
/// large text size never pushes the card off a small screen.
class const _Journal({
  required final List<EntryRecord> entries,
  required final OpenSession? openSession,
  required final Widget greeting,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: greeting,
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: _SessionCard(openSession: openSession),
      ),
      if (entries.isEmpty)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No entries yet. Your first session writes the first one.',
            key: JournalView.emptyKey,
            textAlign: TextAlign.center,
          ),
        )
      else
        for (final record in entries) _EntryTile(record: record),
    ],
  );
}

/// Start a session, or continue (or drop) the one still in progress.
class const _SessionCard({required final OpenSession? openSession})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (openSession) {
    null => FilledButton(
      key: JournalView.startKey,
      onPressed: () => unawaited(open(context, resume: null)),
      child: const Text('Start a session'),
    ),
    final session => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        const Text('You have an unfinished session.'),
        FilledButton(
          key: JournalView.continueKey,
          onPressed: () => unawaited(open(context, resume: session.id)),
          child: const Text('Continue'),
        ),
        TextButton(
          key: JournalView.discardKey,
          onPressed: () => context.read<JournalBloc>().add(
            const JournalEvent.sessionDiscarded(),
          ),
          child: const Text('Discard it'),
        ),
      ],
    ),
  };

  /// Runs the session on its own route; the journal reloads when it is
  /// popped, whether the session finished or not.
  ///
  /// Nothing starts before consent stands. A user who signed up before this
  /// shipped has entries but no consent row, so they are asked here, on the
  /// way into their next session — which is why the question reads as the
  /// app asking rather than as an error. The answer comes from the server
  /// before every session, never from what this device read at launch.
  static Future<void> open(
    BuildContext context, {
    required String? resume,
  }) async {
    final journal = context.read<JournalBloc>();
    final app = GetIt.I<JournalNavigator>();
    // Each await is a server round trip; a page that is gone by the time
    // the answer arrives navigates nowhere on its own behalf.
    if (!await journal.consentStands()) {
      if (!context.mounted || !await app.requestConsent(context)) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    await app.startSession(context, resume: resume);
    journal.add(const JournalEvent.loaded());
  }
}

class const _EntryTile({required final EntryRecord record})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: JournalView.entryKey(record.id),
    title: Text(
      // Month, day and year: a journal spans years.
      MaterialLocalizations.of(context).formatShortDate(record.createdAt),
    ),
    subtitle: Text(
      record.summary,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () {
      context.read<JournalBloc>().add(const JournalEvent.entryOpened());
      // The journal's own screen, on the journal's own route (ADR 0016).
      EntryRoute(id: record.id).go(context);
    },
  );
}

class const _Failure() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const Text(JournalView.failureMessage, textAlign: TextAlign.center),
        FilledButton(
          key: JournalView.retryKey,
          onPressed: () =>
              context.read<JournalBloc>().add(const JournalEvent.loaded()),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}
