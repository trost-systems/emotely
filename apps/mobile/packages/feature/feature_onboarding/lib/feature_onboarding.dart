/// The onboarding feature (#204, ADR 0019): the steps a new user walks on
/// the device before an account exists — Welcome, what emotely gives, the
/// name to be called by, the greeting — kept there until the account
/// exists and then saved to it; and the name step once more for an account
/// that came in without one.
///
/// The app registers it with `registerOnboarding`, restores the
/// `OnboardingStore` before the first frame, and asks it in the router's
/// redirect whether a signed-out user belongs in onboarding or on sign-up.
/// It implements `OnboardingNavigator`, what this feature asks of the
/// outside: sign-in, and where to go once onboarding is over. The name goes
/// to the profile through `profile_repository`.
library;

export 'src/flow.dart';
// The app lists the delegate, and its tests read the strings on screen.
export 'src/l10n/onboarding_localizations.dart' show OnboardingLocalizations;
export 'src/navigator.dart';
export 'src/onboarding_store.dart';
export 'src/progress.dart';
export 'src/register.dart';
// Every feature's part file generates a `$appRoutes`; the app composes
// from the named routes instead, so the collision never reaches it.
export 'src/routes.dart' hide $appRoutes;
// The step views for their keys: the app's tests and the verification CLI
// drive the flow by them.
export 'src/view/hello_step.dart';
export 'src/view/intro_steps.dart';
export 'src/view/name_step.dart';
export 'src/view/onboarding_page.dart';
export 'src/view/step_frame.dart' show StepFrame;
