/// The auth feature: who is signed in, and the ways in — the two-step
/// email code (a password instead for the stores' review accounts), Sign in
/// with Google, and Sign in with Apple on iOS.
/// The app registers it with `registerAuth`, holds the one `AuthBloc`
/// above every screen and shows `SignInPage` while nobody is signed in,
/// as the last step of onboarding or as "I have an account"; it implements
/// `SignInNavigator`, what the screen asks of onboarding.
library;

export 'src/bloc/auth_bloc.dart';
export 'src/l10n/auth_localizations.dart'
    show AuthLocalizations, lookupAuthLocalizations;
export 'src/last_sign_in/last_sign_in_store.dart';
export 'src/navigator.dart';
export 'src/providers/provider_sign_in.dart' show GoogleClientIds;
export 'src/register.dart';
export 'src/review_accounts.dart';
// Every feature's part file generates a `$appRoutes`; the app composes
// from the named routes instead, so the collision never reaches it.
export 'src/routes.dart' hide $appRoutes;
export 'src/view/sign_in_page.dart';
