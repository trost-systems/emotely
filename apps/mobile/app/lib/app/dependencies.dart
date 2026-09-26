import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:emotely/app/navigators.dart';
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
/// registers into [getIt] here, in dependency order, and nowhere else.
///
/// The parameters are the leaves — the http clients, the Supabase client,
/// the PostHog instance — plus the build-time values the app owns (the
/// endpoints, the Google sign-in clients). `main`
/// passes the real ones; a test passes scripted ones and nothing else, so
/// what a test exercises is the production graph with fake edges.
///
/// Everything registered here is user-agnostic and lives for the process;
/// blocs are factories, created by the screen that owns them. Nothing is
/// lazy: a dependency that cannot be built fails the launch, not the first
/// screen that needs it.
///
/// [passwordAccounts] are the addresses, beyond the store review accounts,
/// that sign in with a password: `main` passes the smoke account in a debug
/// build the verification CLI drives, and nothing in any other build.
void registerApp(
  GetIt getIt, {
  required http.Client agentHttpClient,
  required http.Client configHttpClient,
  required SupabaseClient supabase,
  required Posthog posthog,
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
    // Read on every round: the token the app holds now, not at registration.
    accessToken: () => supabase.auth.currentSession?.accessToken,
    // When the agent says it lapsed; a refresh that cannot happen signs the
    // user out through the auth stream, and the router takes it from there.
    refreshAccessToken: supabase.auth.refreshSession,
  );
  registerAnalytics(getIt, posthog: posthog, consentVersion: consentVersion);
  registerJournalRepository(getIt, supabase: supabase);
  registerConsentRepository(getIt, supabase: supabase, version: consentVersion);
  registerFeedbackLink(getIt, build: build);
  registerConfig(getIt, appVersion: appVersion);
  registerAuth(getIt, google: google, passwordAccounts: passwordAccounts);
  registerJournal(getIt);
  registerSession(getIt);
  // The app's side of each feature's navigator, next to the feature.
  getIt
    ..registerSingleton<AccountNavigator>(const AppAccountNavigator())
    ..registerSingleton<JournalNavigator>(const AppJournalNavigator());
  registerAccount(getIt);
}
