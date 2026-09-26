// The live-agent acceptance run: a whole journaling session on a device
// against the DEPLOYED agent, answering whatever the agent asks. Runs
// nightly / pre-release by hand — never per PR (see the write-tests skill):
//
//   flutter test integration_test -d <device> \
//     --dart-define=POSTHOG_KEY=phc_… \
//     --dart-define=SMOKE_EMAIL=… --dart-define=SMOKE_PASSWORD=… \
//     [--dart-define=EMOTELY_AGENT_URL=…]
//
// The agent serves signed-in users only, so the run signs in as the smoke
// user (a password account like the store review accounts; everyone else
// signs in with a code through the app's own screen).

import 'package:design_system/design_system.dart';
import 'package:emotely/app/app.dart';
import 'package:emotely/app/dependencies.dart';
import 'package:emotely/app/environment.dart';
import 'package:feature_account/feature_account.dart';
import 'package:feature_journal/feature_journal.dart';
import 'package:feature_session/feature_session.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:testing/testing.dart';

const _smokeEmail = String.fromEnvironment('SMOKE_EMAIL');
const _smokePassword = String.fromEnvironment('SMOKE_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes a full session against the deployed agent', (
    tester,
  ) async {
    await Posthog().setup(PostHogConfig(posthogKey)..host = posthogHost);
    final robot = LiveSessionRobot(tester);
    await robot.launch();

    const maxRounds = 15;
    var asked = 0;
    while (robot.summary.evaluate().isEmpty) {
      expect(asked, lessThan(maxRounds), reason: 'session did not complete');
      expect(robot.failure, findsNothing, reason: robot.failureMessage);
      await robot.answerCurrentQuestion();
      asked++;
    }

    expect(asked, greaterThanOrEqualTo(10));
    // The entry list is lazy, so count recorded answers, not rendered rows.
    final entry = tester.widget<EntryView>(find.byType(EntryView)).entry;
    expect(entry.answers, hasLength(greaterThanOrEqualTo(10)));
    expect(entry.summary, isNotEmpty);
    expect(find.byType(AnswerText), findsWidgets);
    await Posthog().flush();
  });
}

/// Answers whatever question is on screen with a plausible canned value.
class LiveSessionRobot(final WidgetTester tester) {
  Finder get summary => find.byKey(EntryView.summaryKey);
  Finder get failure => find.byKey(SessionView.retryKey);

  String? get failureMessage => failure.evaluate().isEmpty
      ? null
      : tester.widget<Text>(find.byType(Text).first).data;

  Future<void> launch() async {
    final supabase = await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        detectSessionInUri: false,
        persistSession: false,
      ),
    );
    await supabase.client.auth.signInWithPassword(
      email: _smokeEmail,
      password: _smokePassword,
    );
    final posthog = Posthog();
    // The real startup gate against the real endpoint: if the deployed config
    // is unreadable or blocks this build, the app never reaches the journal
    // and this test says so.
    final httpClient = http.Client();
    final packageInfo = await PackageInfo.fromPlatform();
    registerApp(
      GetIt.I,
      agentHttpClient: httpClient,
      configHttpClient: httpClient,
      supabase: supabase.client,
      posthog: posthog,
      appVersion: packageInfo.version,
      // The real build, as `main` composes it: this runs on a device.
      build: BuildInfo.ofPlatform(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      ),
      agentUrl: urlFrom(agentUrl, define: 'EMOTELY_AGENT_URL'),
      configUrl: urlFrom(configUrl, define: 'EMOTELY_CONFIG_URL'),
      // Signed in above, not through the screen.
      passwordAccounts: const {},
      google: googleClients,
    );
    await tester.pumpWidget(const EmotelyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JournalView.startKey));
    await tester.pumpAndSettle();
    await _consentIfAsked();
    await _settleRound();
  }

  /// The consent gate, the first time this account ever starts a session.
  /// The smoke account consents once and the row stays, so later runs walk
  /// straight past it — which is also what a store reviewer sees on the
  /// account the release skill creates.
  Future<void> _consentIfAsked() async {
    if (find.byType(ConsentPage).evaluate().isEmpty) {
      return;
    }
    // The screen is longer than a phone; both controls sit below the fold.
    await tester.ensureVisible(find.byKey(ConsentView.checkboxKey));
    await tester.tap(find.byKey(ConsentView.checkboxKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ConsentView.agreeKey));
    await tester.tap(find.byKey(ConsentView.agreeKey));
    await tester.pumpAndSettle();
  }

  Future<void> answerCurrentQuestion() async {
    if (find.byType(RatingInput).evaluate().isNotEmpty) {
      await tapSliderAt(tester, find.byKey(RatingInput.sliderKey), 8);
      await _submit(RatingInput.submitKey);
    } else if (find.byType(TextListInput).evaluate().isNotEmpty) {
      const items = ['the live smoke', 'green tests', 'cheap models'];
      // Each filled field opens the next one.
      for (final (index, item) in items.indexed) {
        await tester.enterText(find.byKey(TextListInput.fieldKey(index)), item);
        await tester.pump();
      }
      await _submit(TextListInput.submitKey);
    } else if (find.byType(LongtextInput).evaluate().isNotEmpty) {
      await tester.enterText(
        find.byKey(LongtextInput.fieldKey),
        'The session screen ran on a device against the deployed agent.',
      );
      await tester.pump();
      await _submit(LongtextInput.submitKey);
    } else if (find.byType(EmojiInput).evaluate().isNotEmpty) {
      // The empty slot opens the picker on its smileys page.
      await tester.tap(find.byKey(EmojiInput.slotKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😊'));
      await tester.pumpAndSettle();
      await _submit(EmojiInput.submitKey);
    } else if (find.byType(ColorInput).evaluate().isNotEmpty) {
      // The empty slot opens the picker on its Material swatches.
      await tester.tap(find.byKey(ColorInput.slotKey(0)));
      await tester.pumpAndSettle();
      await tapSwatch(tester, Colors.teal);
      await tester.tap(find.byKey(ColorInput.selectKey));
      await tester.pumpAndSettle();
      await _submit(ColorInput.submitKey);
    } else {
      fail('no answer widget on screen');
    }
    await _settleRound();
  }

  Future<void> _submit(Key key) async {
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  /// A round is a real model call; wait for the spinner to go away.
  Future<void> _settleRound() async {
    const step = Duration(milliseconds: 250);
    const limit = Duration(seconds: 60);
    var waited = Duration.zero;
    do {
      await tester.pump(step);
      waited += step;
    } while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        waited < limit);
    await tester.pumpAndSettle();
  }
}
