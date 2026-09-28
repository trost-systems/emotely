/// The session feature: one journaling session, from the first question to
/// the finished entry. The app registers it with `registerSession`, tells
/// it who the user is through a `UserContextSource`, and opens it with
/// `SessionPage`; the answer widgets are exported so the
/// app's own end-to-end tests can find and drive them.
library;

// The app lists the delegate; the session's tests look strings up through it.
export 'src/l10n/session_localizations.dart' show SessionLocalizations;
export 'src/register.dart';
// Every feature's part file generates a `$appRoutes`; the app composes
// from the named routes instead, so the collision never reaches it.
export 'src/routes.dart' hide $appRoutes;
export 'src/user_context_source.dart';
export 'src/view/session_page.dart';
export 'src/widgets/answer_input.dart';
export 'src/widgets/color_input.dart';
export 'src/widgets/emoji_input.dart';
export 'src/widgets/longtext_input.dart';
export 'src/widgets/rating_input.dart';
export 'src/widgets/text_list_input.dart';
