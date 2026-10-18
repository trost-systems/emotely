import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:emotely/app/account_device_data.dart';
import 'package:emotely/app/navigators.dart';
import 'package:emotely/app/user_context.dart';
import 'package:emotely/config/config_dependencies.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_session/feature_session.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:human_check/human_check.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The one composition root (ADR 0015): every utility and every feature
/// registers into [getIt] here, in dependency order, and nowhere else. The
/// parameters are the leaves — the http clients, Supabase, the PostHog
/// instance and config (used by the gate alone, once allowed, #204), the
/// human check's token source (Turnstile in a web view, #94) — and
/// the app's build-time values; a test passes scripted leaves only, so it
/// exercises the production graph with fake edges.
///
/// Everything registered here is user-agnostic and lives for the process;
/// blocs are factories, and so is the session's user context, which lives
/// as long as the session bloc that asks it. Nothing is lazy: a dependency
/// that cannot be built fails the launch, not the first screen that needs
/// it.
void registerApp(
  GetIt getIt, {
  required http.Client agentHttpClient,
  required http.Client configHttpClient,
  required SupabaseClient supabase,
  required Posthog posthog,
  required PostHogConfig posthogConfig,
  required String appVersion,
  required BuildInfo build,
  required Uri agentUrl,
  required Uri configUrl,
  required GoogleClientIds google,
  required HumanCheckToken humanCheckToken,
}) {
  getIt.registerSingleton(supabase);
  _registerAgent(
    getIt,
    supabase,
    clients: (agent: agentHttpClient, config: configHttpClient),
    urls: (agent: agentUrl, config: configUrl),
    appVersion: appVersion,
  );
  registerAnalytics(
    getIt,
    posthog: posthog,
    config: posthogConfig,
    consentVersion: consentVersion,
    onboardingFlowVersion: onboardingFlowVersion,
  );
  _registerRecords(getIt, supabase);
  registerFeedbackLink(getIt, build: build);
  registerConfig(getIt, appVersion: appVersion);
  registerHumanCheck(getIt, token: humanCheckToken);
  registerAuth(getIt, google: google);
  registerJournal(getIt);
  registerSession(getIt);
  registerOnboarding(getIt);
  _registerSeams(getIt);
  registerAccount(getIt);
}

/// The agent's two endpoints, with the token the app holds on every round,
/// refreshed when the agent says it lapsed; a refresh that cannot happen
/// signs the user out.
void _registerAgent(
  GetIt getIt,
  SupabaseClient supabase, {
  required ({http.Client agent, http.Client config}) clients,
  required ({Uri agent, Uri config}) urls,
  required String appVersion,
}) => registerAgentClient(
  getIt,
  agentHttpClient: clients.agent,
  configHttpClient: clients.config,
  agentUrl: urls.agent,
  configUrl: urls.config,
  appVersion: appVersion,
  accessToken: () => supabase.auth.currentSession?.accessToken,
  refreshAccessToken: supabase.auth.refreshSession,
);

/// The user's records on the server: the journal, the profile, and the
/// consent record with the wordings the app currently asks consent for.
void _registerRecords(GetIt getIt, SupabaseClient supabase) {
  registerJournalRepository(getIt, supabase: supabase);
  registerProfileRepository(getIt, supabase: supabase);
  registerConsentRepository(
    getIt,
    supabase: supabase,
    version: consentVersion,
    usageAnalyticsVersion: usageAnalyticsVersion,
  );
}

/// The app's side of each feature's navigator, next to the features, of
/// the session's question of who the user is, and of what a deleted
/// account leaves on this device.
///
/// The user context is a factory, like the bloc that asks it: it remembers
/// the user's profile for one session (#264), and nothing per-user may
/// outlive a screen, so each session gets its own and closes it.
void _registerSeams(GetIt getIt) => getIt
  ..registerFactory<UserContextSource>(
    () => AppUserContextSource(profiles: getIt(), errors: getIt()),
  )
  ..registerSingleton<AccountDeviceData>(AppAccountDeviceData(getIt()))
  ..registerSingleton<AccountNavigator>(const AppAccountNavigator())
  ..registerSingleton<JournalNavigator>(const AppJournalNavigator())
  ..registerSingleton<OnboardingNavigator>(const AppOnboardingNavigator())
  ..registerSingleton<SignInNavigator>(AppSignInNavigator(getIt()));
