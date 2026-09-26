import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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
  // A journal that accepts every write unless the test scripts otherwise.
  supabase.journalWorks();
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
    appVersion: AgentStub.appVersion,
    build: testBuildInfo,
    agentUrl: AgentStub.endpoint,
    configUrl: ConfigStub.endpoint,
    // The release shape: every address outside the review accounts gets a
    // code (feature_auth's tests cover the password accounts).
    passwordAccounts: const {},
    // Public ids, but not the real ones: nothing here talks to Google.
    google: const GoogleClientIds(
      server: 'server.apps.googleusercontent.com',
      ios: 'ios.apps.googleusercontent.com',
    ),
  );
  return const EmotelyApp();
}

/// A deep link arriving while the app runs: the platform's `pushRoute`
/// notification, delivered to the router the way iOS and Android deliver
/// it, rather than a call on the router. What the router does with it —
/// the redirect included — is then exactly what it would do on a device.
Future<void> deepLink(WidgetTester tester, String location) async {
  await tester.binding.handlePushRoute(location);
  await tester.pumpAndSettle();
}

/// Signs in through the sign-in screen the way a user does: the email,
/// the code, done. The Supabase stub must have `otp:` and `verify:` rounds
/// scripted.
Future<void> signInThroughTheScreen(
  WidgetTester tester, {
  String email = SupabaseStub.email,
  String code = '123456',
}) async {
  await tester.enterText(find.byKey(SignInPage.emailKey), email);
  await tester.pump();
  await tester.tap(find.byKey(SignInPage.sendCodeKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(SignInPage.codeKey), code);
  await tester.pump();
  await tester.tap(find.byKey(SignInPage.signInKey));
  await tester.pumpAndSettle();
}
