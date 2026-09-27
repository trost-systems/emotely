import 'dart:async';

import 'package:agent_client/agent_client.dart';
import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:journal_repository/journal_repository.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:testing/src/agent_stub.dart';
import 'package:testing/src/analytics_spy.dart';
import 'package:testing/src/config_stub.dart';
import 'package:testing/src/supabase_stub.dart';

/// The consent wording version a feature test registers. The app owns the
/// real one; a feature only ever reports or records whatever it is given.
const testConsentVersion = '2026-01-01';

/// The usage-analytics wording version a feature test records, for the
/// same reason (#204).
const testUsageAnalyticsVersion = '2026-01-02';

/// The onboarding flow version a feature test registers; the onboarding
/// feature owns the real one, and the app hands it in (#204).
const testOnboardingFlowVersion = 1;

/// The build a feature test runs as. Fixed rather than read from the host,
/// so what a feedback mail says is the same on every machine; the app hands
/// in the real one, read from `package_info_plus` and the platform.
const testBuildInfo = BuildInfo(
  version: '1.0.0',
  buildNumber: '1',
  platform: 'iOS',
  operatingSystemVersion: '18.0',
);

/// Registers every utility into [getIt] the way the app's `registerApp`
/// does — the production registration functions, in the same order — over
/// scripted leaves: the stubs' http clients, the scripted Supabase client
/// and the spied PostHog. A feature package's tests compose on top of this
/// with the feature's own registration function and, where it has one, a
/// fake navigator; nothing else is registered from a test.
///
/// The container is emptied when the test ends. Composing twice in one
/// test fails loudly — get_it refuses to re-register — unless the test
/// resets in between and says why.
void registerUtilitiesUnderTest(
  GetIt getIt, {
  required AgentStub agent,
  required SupabaseStub supabase,
  required AnalyticsSpy analytics,
  ConfigStub? config,
  String appVersion = AgentStub.appVersion,
  String consentVersion = testConsentVersion,
  BuildInfo build = testBuildInfo,
}) {
  final configStub = config ?? (ConfigStub()..serves());
  // A journal that accepts every write unless the test scripts otherwise.
  supabase.journalWorks();
  addTearDown(getIt.reset);
  getIt.registerSingleton(supabase.supabase);
  registerAgentClient(
    getIt,
    agentHttpClient: agent.client,
    configHttpClient: configStub.client,
    agentUrl: AgentStub.endpoint,
    configUrl: ConfigStub.endpoint,
    appVersion: appVersion,
    accessToken: () => supabase.supabase.auth.currentSession?.accessToken,
    refreshAccessToken: supabase.supabase.auth.refreshSession,
  );
  registerAnalytics(
    getIt,
    posthog: analytics.posthog,
    config: PostHogConfig('phc_test'),
    consentVersion: consentVersion,
    onboardingFlowVersion: testOnboardingFlowVersion,
  );
  // `main` awaits this before the first frame; here every call PostHog
  // hears queues behind it instead, so the order is the same.
  unawaited(getIt<PostHogGate>().restore());
  registerJournalRepository(getIt, supabase: supabase.supabase);
  registerProfileRepository(getIt, supabase: supabase.supabase);
  registerConsentRepository(
    getIt,
    supabase: supabase.supabase,
    version: consentVersion,
    usageAnalyticsVersion: testUsageAnalyticsVersion,
  );
  registerFeedbackLink(getIt, build: build);
}
