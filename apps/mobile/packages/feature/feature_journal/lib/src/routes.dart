import 'package:feature_journal/src/view/entry_page.dart';
import 'package:feature_journal/src/view/journal_page.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

part 'routes.g.dart';

/// The journal's own screens as routes (ADR 0016): the feature says where
/// its screens live and moves between them itself; the app mounts the
/// tree as the journal tab. A route carries only what its location can
/// say — an entry travels as its id and the screen reads it back.

/// Home: the journal. Its entries sit under it, so the back button leads
/// here. With [startSession] it starts a session as soon as it has read the
/// journal, through the same consent check as "Start a session": where a
/// new account lands at the end of onboarding (#204).
@TypedGoRoute<JournalRoute>(
  path: '/',
  name: 'journal',
  routes: [TypedGoRoute<EntryRoute>(path: 'entries/:id', name: 'entry')],
)
@immutable
class const JournalRoute({final bool startSession = false})
    extends GoRouteData
    with $JournalRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      JournalPage(startSession: startSession);
}

/// One filed entry, by its id; the screen reads it back itself.
@immutable
class const EntryRoute({required final String id})
    extends GoRouteData
    with $EntryRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      EntryPage(entryId: id);
}
