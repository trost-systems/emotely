import 'package:design_system/design_system.dart';
import 'package:feature_journal/src/bloc/entry_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:material_ui/material_ui.dart';

/// One filed entry, read back the way the session showed it. Reached by
/// its id alone, so it reads the entry itself (ADR 0016).
class const EntryPage({required final String entryId, super.key})
    extends StatelessWidget {
  static const retryKey = Key('entry_page.retry');
  static const failureMessage = 'Could not load this entry.';

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<EntryBloc>()..add(EntryEvent.loaded(entryId)),
    child: EntryPageView(entryId: entryId),
  );
}

/// One widget per [EntryState]; the entry itself is the design system's
/// [EntryView], the same one the session ends on.
class const EntryPageView({required final String entryId, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<EntryBloc, EntryState>(
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(switch (state) {
          EntryReady(:final record) =>
            // Month, day and year: a journal spans years.
            MaterialLocalizations.of(context).formatShortDate(record.createdAt),
          EntryLoading() || EntryFailure() => 'Entry',
        }),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (state) {
            EntryLoading() => const Center(child: CircularProgressIndicator()),
            EntryReady(:final record) => EntryView(
              entry: record.entry,
              questions: record.questionsById,
            ),
            EntryFailure() => _Failure(entryId: entryId),
          },
        ),
      ),
    ),
  );
}

class const _Failure({required final String entryId}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const Text(EntryPage.failureMessage, textAlign: TextAlign.center),
        FilledButton(
          key: EntryPage.retryKey,
          onPressed: () =>
              context.read<EntryBloc>().add(EntryEvent.loaded(entryId)),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}
