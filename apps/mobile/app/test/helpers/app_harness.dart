import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:testing/testing.dart';

/// The whole app, composed by the production `registerApp` over the scripted
/// agent, the scripted config endpoint, the scripted Supabase and the spied
/// PostHog: the leaves are replaced and nothing else, so what a test
/// exercises is the production graph with fake edges. The agent client
/// forwards whatever token the Supabase session holds, exactly as in
/// `main.dart`, because the same code builds it.
///
/// The container is emptied when the test ends. Composing twice in one test
/// fails loudly — get_it refuses to re-register — rather than silently
/// replacing what the first composition built.
Widget appUnderTest({
  required AgentStub agent,
  required SupabaseStub supabase,
  required AnalyticsSpy analytics,
  ConfigStub? config,
  bool debugBanner = true,
}) {
  // `PosthogObserver`, mounted so surveys can find a context, calls the
  // native SDK directly on every route change rather than through the
  // injected instance. There is no native side here, so answer its channel
  // with nothing; what a test asserts on still goes through the spy.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('posthog_flutter'),
        (call) async => null,
      );
  supabase
    // An account that already has a name, so a sign-in lands on the
    // journal rather than on the name step, unless the test scripts the
    // profile.
    ..unless(profileRead, rows([profileRow(displayName: accountName)]))
    // A journal that accepts every write unless the test scripts otherwise.
    ..journalWorks();
  // A startup gate that opens unless the test scripts otherwise; without it
  // every test would sit on the checking screen.
  final configStub = config ?? (ConfigStub()..serves());
  addTearDown(GetIt.I.reset);
  registerApp(
    GetIt.I,
    agentHttpClient: agent.client,
    configHttpClient: configStub.client,
    supabase: supabase.supabase,
    posthog: analytics.posthog,
    posthogConfig: PostHogConfig('phc_test'),
    appVersion: AgentStub.appVersion,
    build: testBuildInfo,
    agentUrl: AgentStub.endpoint,
    configUrl: ConfigStub.endpoint,
    // Public ids, but not the real ones: nothing here talks to Google.
    google: const GoogleClientIds(
      server: 'server.apps.googleusercontent.com',
      ios: 'ios.apps.googleusercontent.com',
    ),
    // Turnstile's web view cannot run here; every check passes.
    humanCheckToken: HumanCheckStub().token,
  );
  // `main` awaits both restores before the first frame, the gate's over the
  // session Supabase restored; here every call PostHog hears queues behind
  // the gate's instead, so the order is the same, and the onboarding store
  // reads the in-memory preferences before the router first asks it.
  final gate = GetIt.I<PostHogGate>();
  unawaited(gate.restore(account: supabase.supabase.auth.currentUser?.id));
  final onboarding = GetIt.I<OnboardingStore>();
  unawaited(onboarding.restore());
  return EmotelyApp(
    screenViews: gate.screenObserver(),
    onboarding: onboarding,
    debugBanner: debugBanner,
    turnstile: HumanCheckStub.idleTurnstile,
  );
}

/// A deep link arriving while the app runs: the platform's `pushRoute`
/// notification, delivered to the router the way iOS and Android deliver
/// it, rather than a call on the router. What the router does with it —
/// the redirect included — is then exactly what it would do on a device.
Future<void> deepLink(WidgetTester tester, String location) async {
  await tester.binding.handlePushRoute(location);
  await tester.pumpAndSettle();
}

/// The name the harness's account already has.
const accountName = 'Alice';

/// Signs in through the sign-in screen the way a returning user does: "I
/// have an account" on Welcome, if that is where they are, then the email
/// and the password, done. The Supabase stub must have a `password:` round
/// scripted.
Future<void> signInThroughTheScreen(
  WidgetTester tester, {
  String email = SupabaseStub.email,
  String password = 'correct horse battery staple',
}) async {
  final haveAccount = find.byKey(WelcomeStepView.haveAccountKey);
  if (haveAccount.evaluate().isNotEmpty) {
    await tester.tap(haveAccount);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(SignInPage.emailKey), email);
  await tester.enterText(find.byKey(SignInPage.passwordKey), password);
  await tester.pump();
  await tester.ensureVisible(find.byKey(SignInPage.submitKey));
  await tester.tap(find.byKey(SignInPage.submitKey));
  await tester.pumpAndSettle();
}
