import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:emotely/app/environment.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:get_it/get_it.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

import 'fake_backend.dart';

/// The app as `main` composes it over [backend], signed in and past the
/// first-launch usage-analytics sheet: what the survey
/// (`survey_test.dart`) walks. The same composition as the budget's
/// `PerfPaths.compose` (`perf_test.dart`).
Future<EmotelyApp> composeApp(FakeBackend backend) async {
  final supabase = SupabaseClient(
    FakeBackend.supabaseUrl,
    SupabaseStub.publishableKey,
    httpClient: backend,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  // A restored sign-in, as on every launch after the first.
  await supabase.auth.recoverSession(jsonEncode(SupabaseStub.session()));
  registerApp(
    GetIt.I,
    agentHttpClient: backend,
    configHttpClient: backend,
    supabase: supabase,
    posthog: Posthog(),
    // Without a POSTHOG_KEY define the gate sets nothing up, and analytics
    // stay off as in a build without the key.
    posthogConfig: PostHogConfig(posthogKey)..host = posthogHost,
    appVersion: '1.0.0',
    build: testBuildInfo,
    agentUrl: FakeBackend.agentUrl,
    configUrl: FakeBackend.configUrl,
    passwordAccounts: const {},
    google: googleClients,
  );
  // What `main` reads before the first frame; usage analytics allowed, as
  // most testers do on the first-launch sheet (#204).
  final gate = GetIt.I<PostHogGate>();
  await gate.restore(account: supabase.auth.currentUser?.id);
  await gate.allow();
  final onboarding = GetIt.I<OnboardingStore>();
  await onboarding.restore();
  return EmotelyApp(screenViews: gate.screenObserver(), onboarding: onboarding);
}
