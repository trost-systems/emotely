/// The journal feature: home. The entries so far, the way into the next
/// session (behind the consent gate), and each entry read back. The app
/// registers it with `registerJournal` and implements `JournalNavigator` —
/// the session, the consent screen, the account screen and signing out all
/// belong to other features, so the journal only asks for them.
library;

export 'src/l10n/journal_localizations.dart' show JournalLocalizations;
export 'src/navigator.dart';
export 'src/register.dart';
// Every feature's part file generates a `$appRoutes`; the app composes
// from the named routes instead, so the collision never reaches it.
export 'src/routes.dart' hide $appRoutes;
export 'src/view/entry_page.dart';
export 'src/view/journal_page.dart';
