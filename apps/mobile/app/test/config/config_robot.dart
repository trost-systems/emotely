import 'package:emotely/config/view/config_gate.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/helpers.dart';

/// Drives the startup gate through the real app against a scripted config
/// endpoint.
class ConfigRobot(
  final WidgetTester tester,
  final ConfigStub config, {
  final AgentStub? agent,
  final AnalyticsSpy? spy,
  final SupabaseStub? supabase,
}) {
  late final AnalyticsSpy analytics = spy ?? AnalyticsSpy();
  late final SupabaseStub supabaseStub = supabase ?? SupabaseStub();
  late final AgentStub agentStub = agent ?? AgentStub();

  Finder get checking => find.byKey(ConfigGate.checkingKey);
  Finder get updateRequired => find.byKey(ConfigGate.updateRequiredKey);
  Finder get updateButton => find.byKey(ConfigGate.updateKey);
  Finder get failure => find.byKey(ConfigGate.failureKey);
  Finder get retryButton => find.byKey(ConfigGate.retryKey);
  Finder get welcome => find.byType(WelcomeStepView);
  Finder get journal => find.byType(JournalPage);

  Widget get app => appUnderTest(
    agent: agentStub,
    supabase: supabaseStub,
    analytics: analytics,
    config: config,
  );

  /// Launches the app signed out; the gate's first read is in flight until
  /// [settle].
  Future<void> launch() => tester.pumpWidget(app);

  /// Launches already signed in, so a passing gate lands on the journal.
  Future<void> launchSignedIn() async {
    await supabaseStub.signedIn();
    await tester.pumpWidget(app);
  }

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> tapUpdate() async {
    await tester.tap(updateButton);
    await settle();
  }

  Future<void> tapRetry() async {
    await tester.tap(retryButton);
    await settle();
  }
}
