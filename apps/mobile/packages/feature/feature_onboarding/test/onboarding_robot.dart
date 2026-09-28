import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

/// What onboarding asked of the app, in order.
class FakeOnboardingNavigator() extends OnboardingNavigator {
  final asked = <String>[];

  @override
  void signIn(BuildContext context, {String? from}) =>
      asked.add('signIn from $from');

  @override
  void finish(
    BuildContext context, {
    required OnboardingNext next,
    String? from,
  }) => asked.add('finish ${next.name} from $from');
}

/// Drives onboarding on its own route, composed the way the app composes
/// it, over the device's preferences as the analytics spy keeps them and a
/// scripted Supabase for the profile; what it asks of the app is recorded
/// by the fake navigator.
class OnboardingRobot(
  final WidgetTester tester, {
  final AnalyticsChoice? choice = AnalyticsChoice.allowed,
}) {
  late final analytics = AnalyticsSpy(stored: choice);
  final navigator = FakeOnboardingNavigator();
  final supabase = SupabaseStub();

  Finder get getStarted => find.byKey(WelcomeStepView.getStartedKey);
  Finder get haveAccount => find.byKey(WelcomeStepView.haveAccountKey);
  Finder get valueContinue => find.byKey(ValueStepView.continueKey);
  Finder get nameField => find.byKey(NameStepView.fieldKey);
  Finder get nameContinue => find.byKey(NameStepView.continueKey);
  Finder get skip => find.byKey(NameStepView.skipKey);
  Finder get helloStart => find.byKey(HelloStepView.startKey);
  Finder get skippedStart => find.byKey(SkippedStepView.startKey);
  Finder get tellYou => find.byKey(SkippedStepView.tellYouKey);
  Finder get back => find.byKey(StepFrame.backKey);
  Finder get waiting => find.byKey(OnboardingView.waitingKey);
  Finder get retry => find.byKey(OnboardingView.retryKey);

  Finder get welcome => find.byType(WelcomeStepView);
  Finder get value => find.byType(ValueStepView);
  Finder get name => find.byType(NameStepView);
  Finder get hello => find.byType(HelloStepView);
  Finder get skipped => find.byType(SkippedStepView);

  OnboardingStore get store => GetIt.I<OnboardingStore>();

  /// The account already has [name].
  void accountNamed(String name) =>
      supabase.always(profileRead, rows([profileRow(displayName: name)]));

  /// The names saved to the account, in order.
  List<({Object? name, Object? isPlaceholder})> get saved => [
    for (final body in supabase.bodies(profilesPath))
      (name: body['display_name'], isPlaceholder: body['name_is_placeholder']),
  ];

  /// Keeps [progress] on the device as a run of this flow left it, before
  /// the app starts.
  Future<void> kept(Map<String, Object?> progress) => analytics.preferences
      .setString(OnboardingStore.key, jsonEncode(progress));

  /// The words on screen, in the locale the test pumped: tests read what
  /// they expect through it, so each holds in every language.
  OnboardingLocalizations get strings =>
      OnboardingLocalizations.of(tester.element(find.byType(OnboardingView)));

  /// Onboarding's route as the app mounts it, opened in [phase], in
  /// [locale] or else the helpers' own. Reading this composes the
  /// container, so read it once per test.
  Widget app({
    OnboardingPhase phase = OnboardingPhase.beforeSignUp,
    String? from,
    ThemeMode themeMode = ThemeMode.light,
    Locale? locale,
  }) {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: AgentStub(),
      supabase: supabase,
      analytics: analytics,
    );
    registerOnboarding(GetIt.I);
    GetIt.I.registerSingleton<OnboardingNavigator>(navigator);
    final routes = [$onboardingRoute];
    final initialLocation = OnboardingRoute(phase: phase, from: from).location;
    const localizations = [OnboardingLocalizations.delegate];
    return locale == null
        ? featureUnderTest(
            routes: routes,
            initialLocation: initialLocation,
            themeMode: themeMode,
            localizations: localizations,
          )
        : featureUnderTest(
            routes: routes,
            initialLocation: initialLocation,
            themeMode: themeMode,
            localizations: localizations,
            locale: locale,
          );
  }

  /// Opens onboarding the way `main` does: the progress restored first.
  Future<void> launch({
    OnboardingPhase phase = OnboardingPhase.beforeSignUp,
    String? from,
    Locale? locale,
  }) async {
    final widget = app(phase: phase, from: from, locale: locale);
    await store.restore();
    await tester.pumpWidget(widget);
    await settle();
  }

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle();
  }

  Future<void> type(String text) async {
    await tester.enterText(nameField, text);
    await settle();
  }

  /// From Welcome to the name step.
  Future<void> toName() async {
    await tap(getStarted);
    await tap(valueContinue);
  }

  /// The events PostHog heard, by name.
  List<String> get eventNames => [
    for (final captured in analytics.events) captured['event']! as String,
  ];

  /// The properties of every event named [name].
  List<Map<String, Object>> propertiesOf(String name) => [
    for (final captured in analytics.events)
      if (captured['event'] == name)
        captured['properties']! as Map<String, Object>,
  ];
}
