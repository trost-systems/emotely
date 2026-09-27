import 'package:feature_journal/src/bloc/entry_bloc.dart';
import 'package:feature_journal/src/bloc/journal_bloc.dart';
import 'package:get_it/get_it.dart';

/// The journal feature's registrations: its two blocs, a fresh one per
/// screen, the journal's reading the time of day from [now] (the clock; a
/// test pins it). The app registers a `JournalNavigator` implementation
/// itself; it is the app's to provide, not this feature's.
void registerJournal(GetIt getIt, {DateTime Function() now = DateTime.now}) =>
    getIt
      ..registerFactory(
        () => JournalBloc(
          repository: getIt(),
          consent: getIt(),
          analytics: getIt(),
          profiles: getIt(),
          errors: getIt(),
          now: now,
        ),
      )
      ..registerFactory(() => EntryBloc(repository: getIt()));
