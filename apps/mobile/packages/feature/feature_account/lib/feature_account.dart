/// The account feature: the More tab (privacy, the legal links, feedback,
/// signing out, the account), the account screen (deletion), Privacy
/// settings, and the two consents the app asks for — the explicit consent
/// before the first session (ADR 0014), and usage analytics on first launch
/// (#204) — with their blocs, screens and wording.
///
/// The app registers it with `registerAccount` and implements
/// `AccountNavigator`, what this feature asks of the outside: to be signed
/// out, and to be shown the consent screen on its own route. The consent
/// bloc, screen and outcome are exported because the app owns that route
/// and the journal gates every session on its answer; the usage-analytics
/// prompt because the app mounts it above every screen, and its version
/// because the app hands it to the consent record.
library;

export 'src/account/view/account_page.dart';
export 'src/consent/bloc/consent_bloc.dart';
export 'src/consent/consent_outcome.dart';
export 'src/consent/consent_text.dart';
export 'src/consent/view/consent_page.dart';
export 'src/more/view/more_page.dart';
export 'src/navigator.dart';
export 'src/privacy/view/privacy_settings_page.dart';
export 'src/register.dart';
// Every feature's part file generates a `$appRoutes`; the app composes
// from the named routes instead, so the collision never reaches it.
export 'src/routes.dart' hide $appRoutes;
export 'src/usage_analytics/usage_analytics_text.dart';
export 'src/usage_analytics/view/usage_analytics_prompt.dart';
