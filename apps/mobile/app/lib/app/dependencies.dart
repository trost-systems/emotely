import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:emotely/app/navigators.dart';
import 'package:emotely/app/user_context.dart';
import 'package:emotely/config/config_dependencies.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_session/feature_session.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:journal_repository/journal_repository.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The one composition root (ADR 0015): every utility and every feature
/// registers into [getIt] here, in dependency order, and nowhere else. The
/// parameters are the leaves — the http clients, Supabase, the PostHog
/// instance and config (used by the gate alone, once allowed, #204) — and
/// the app's build-time values; a test passes scripted leaves only, so it
/// exercises the production graph with fake edges.
///
/// Everything registered here is user-agnostic and lives for the process;
/// blocs are factories. Nothing is lazy: a dependency that cannot be built
/// fails the launch, not the first screen that needs it.
///
/// [passwordAccounts] are the addresses beyond the store review accounts
/// that sign in with a password: the smoke account in a debug build the
/// verification CLI drives, nothing in any other build.
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
  required Set<String> passwordAccounts,
  required GoogleClientIds google,
}) {
  getIt.registerSingleton(supabase);
  registerAgentClient(
    getIt,
    agentHttpClient: agentHttpClient,
    configHttpClient: configHttpClient,
    agentUrl: agentUrl,
    configUrl: configUrl,
    appVersion: appVersion,
    // The token the app holds on every round, refreshed when the agent says
    // it lapsed; a refresh that cannot happen signs the user out.
    accessToken: () => supabase.auth.currentSession?.accessToken,
    refreshAccessToken: supabase.auth.refreshSession,
  );
  registerAnalytics(
    getIt,
    posthog: posthog,
    config: posthogConfig,
    consentVersion: consentVersion,
  );
  _registerRecords(getIt, supabase);
  registerFeedbackLink(getIt, build: build);
  registerConfig(getIt, appVersion: appVersion);
  registerAuth(getIt, google: google, passwordAccounts: passwordAccounts);
  registerJournal(getIt);
  registerSession(getIt);
  // The app's side of each feature's navigator, next to the feature, and
  // of the session's question of who the user is.
  getIt
    ..registerSingleton<UserContextSource>(const AppUserContextSource())
    ..registerSingleton<AccountNavigator>(const AppAccountNavigator())
    ..registerSingleton<JournalNavigator>(const AppJournalNavigator());
  registerAccount(getIt);
}

/// The user's records on the server: the journal, and the consent record
/// with the wordings the app currently asks consent for.
void _registerRecords(GetIt getIt, SupabaseClient supabase) {
  registerJournalRepository(getIt, supabase: supabase);
  registerConsentRepository(
    getIt,
    supabase: supabase,
    version: consentVersion,
    usageAnalyticsVersion: usageAnalyticsVersion,
  );
}
