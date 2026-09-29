import 'package:design_system/design_system.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_journal/src/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

import 'fake_journal_navigator.dart';

/// Drives the journal on its own page, composed the way the app composes
/// it, against a scripted Supabase; what it asks of the app is recorded by
/// the fake navigator.
class JournalRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
  final bool startSession = false,
}) {
  /// What the journal's clock says: an evening, unless a test says
  /// otherwise.
  var now = DateTime(2026, 9, 26, 20, 15);

  final analytics = AnalyticsSpy();
  final navigator = FakeJournalNavigator();

  Finder get home => find.byType(JournalPage);
  Finder get entryPage => find.byType(EntryPage);
  Finder get start => find.byKey(JournalView.startKey);
  Finder get continueSession => find.byKey(JournalView.continueKey);
  Finder get discard => find.byKey(JournalView.discardKey);
  Finder get retry => find.byKey(JournalView.retryKey);
  Finder get empty => find.byKey(JournalView.emptyKey);
  Finder get entries => find.byType(ListTile);
  Finder get summary => find.byKey(EntryView.summaryKey);

  Finder entry(String id) => find.byKey(JournalView.entryKey(id));

  /// The journal's strings as the page on screen reads them, in whatever
  /// language it speaks: tests assert a message by its key, so a rewording
  /// never breaks them.
  JournalLocalizations get strings => tester.element(home).l10n;

  /// Flutter's own strings and date formats in the locale on screen.
  MaterialLocalizations get material =>
      MaterialLocalizations.of(tester.element(home));

  /// The journal's routes as the app mounts them, opened on the journal.
  /// Reading this composes the container, so read it once per test.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: agent,
      supabase: supabase,
      analytics: analytics,
    );
    registerJournal(GetIt.I, now: () => now);
    GetIt.I.registerSingleton<JournalNavigator>(navigator);
    return featureUnderTest(
      routes: [$journalRoute],
      initialLocation: JournalRoute(startSession: startSession).location,
      localizations: const [JournalLocalizations.delegate],
    );
  }

  /// Signed in, with the journal loaded.
  Future<void> launch() async {
    await supabase.signedIn();
    await tester.pumpWidget(app);
    await settle();
  }

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await settle();
  }

  Future<void> back() => tester.tapBack();
}
