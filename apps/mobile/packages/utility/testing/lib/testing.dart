/// Test support shared by every package: the accessibility bar, the submit
/// helpers, the agent, the config endpoint and Supabase scripted at the http
/// seam, the PostHog spy, the url_launcher spy, the Google and Apple
/// sign-in fakes and the generated mocks.
/// Nothing here knows the app or a feature — only utilities.
library;

export 'src/a11y.dart';
export 'src/agent_stub.dart';
export 'src/analytics_spy.dart';
export 'src/color_picker.dart';
export 'src/compose.dart';
export 'src/config_stub.dart';
export 'src/consent_rounds.dart';
export 'src/identity_providers.dart';
export 'src/journal_rows.dart';
export 'src/mocks.dart';
export 'src/profile_rows.dart';
export 'src/pump_app.dart';
export 'src/questions.dart';
export 'src/slider.dart';
export 'src/submit.dart';
export 'src/supabase_stub.dart';
export 'src/url_launcher_spy.dart';
