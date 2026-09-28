import 'package:feature_account/feature_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/helpers.dart';
import '../consent_robot.dart';

void main() {
  group(ConsentPage, () {
    const journalViewed = {'entries': 0, 'open_session': false};
    const version = {'version': consentVersion};

    /// A Supabase that answers every `consent_stands` with [granted], and
    /// accepts whatever the screen writes unless a test scripts otherwise.
    /// The agent has one question ready, so a session that does start is
    /// visibly a session rather than a spinner.
    ///
    /// `always` rather than a queue, because the gate asks again before
    /// every session (a withdrawal elsewhere has to stop this device), so a
    /// test cannot know how many reads it will need. [reads] queues rounds
    /// ahead of that fallback for the tests that want a read to fail or the
    /// answer to change mid-test.
    ConsentRobot robotWith(
      WidgetTester tester, {
      bool granted = false,
      List<AuthRound> grants = const [],
      List<AuthRound> withdrawals = const [],
      List<AuthRound> reads = const [],
    }) {
      final supabase = SupabaseStub()
        ..rest(consentRead, reads)
        ..always(consentRead, consentStands(granted: granted))
        ..rest(consentGrant, grants)
        ..rest(consentWithdraw, withdrawals);
      final agent = AgentStub()
        ..script([awaiting(toolCallId: 'c1', question: rateQuestion)]);
      return ConsentRobot(tester, supabase: supabase, agent: agent);
    }

    testWidgets('asks before the first session and starts it once given', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();

      // Nothing has been sent, and nothing is asked until a session is.
      expect(robot.consent, findsNothing);
      expect(robot.supabase.to(consentGrant), isEmpty);

      await robot.startSession();

      // The gate, not the session.
      expect(robot.consent, findsOneWidget);
      expect(robot.session, findsNothing);
      expect(find.text(robot.strings.consentTitle), findsOneWidget);

      // The box starts unticked, and until it is ticked the button cannot
      // be pressed at all: no pre-ticked box, and no "by continuing".
      expect(tester.widget<CheckboxListTile>(robot.checkbox).value, isFalse);
      expect(tester.widget<FilledButton>(robot.agree).enabled, isFalse);
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.session, findsNothing);

      await robot.consentAndContinue();

      // Recorded server-side, naming the wording that was agreed to, and
      // only then does the session begin.
      expect(robot.supabase.to(consentGrant), hasLength(1));
      expect(robot.supabase.bodies('/rest/v1/rpc/record_consent'), [
        {'version': consentVersion},
      ]);
      expect(robot.session, findsOneWidget);
      expect(robot.consent, findsNothing);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_granted', version),
        ...robot.analytics.events.skip(2),
      ]);
    });

    testWidgets('does not ask again once consent stands', (tester) async {
      final robot = robotWith(tester, granted: true);
      robot.supabase.always(profileRead, rows(const []));
      await robot.launch();

      await robot.startSession();

      // Straight into the session: the record is what decides, and it was
      // read from the server.
      expect(robot.consent, findsNothing);
      expect(robot.session, findsOneWidget);
      expect(robot.supabase.to(consentGrant), isEmpty);
      // The user has no profile yet, so the round says nothing about them.
      expect(robot.agent.lastRequest, {'app_version': AgentStub.appVersion});
    });

    testWidgets(
      'the answer comes from the server every time, not a local flag',
      (tester) async {
        final robot = robotWith(tester, granted: true);
        await robot.launch();

        // Nothing is read at launch and nothing is remembered: the question
        // is asked of the server on the way into every session, so a
        // reinstall cannot lose the answer and cannot invent one, and a
        // withdrawal made elsewhere is seen before anything is sent.
        expect(robot.supabase.to(consentRead), isEmpty);

        await robot.startSession();

        expect(robot.supabase.to(consentRead), hasLength(1));
        // The journal's own purpose, by leaving it out: the wire shape the
        // app in testers' hands already sends (ADR 0009).
        expect(robot.supabase.to(consentRead).single.body, {
          'version': consentVersion,
        });
        expect(robot.session, findsOneWidget);
      },
    );

    testWidgets('a withdrawal made on another device stops this one', (
      tester,
    ) async {
      // Consent stood for the first session; by the time Start is tapped
      // again the server says otherwise, because the user withdrew it on
      // their phone. The yes from a minute ago must not be what decides.
      final robot = robotWith(tester, reads: [consentStands()]);
      await robot.launch();

      await robot.startSession();

      expect(robot.session, findsOneWidget);

      await robot.back();
      await robot.startSession();

      expect(robot.consent, findsOneWidget);
      expect(robot.session, findsNothing);
    });

    testWidgets('a withdrawn consent is asked for again', (tester) async {
      final robot = robotWith(tester);
      await robot.launch();

      await robot.startSession();

      // Withdrawn reads the same as never given: ask before sending
      // anything, rather than treating an old row as a standing yes.
      expect(robot.consent, findsOneWidget);
      expect(robot.session, findsNothing);
    });

    testWidgets('continuing an unfinished session is gated too', (
      tester,
    ) async {
      // A session begun before consent was withdrawn (or before this
      // shipped) still sends its transcript to the model when it resumes,
      // so resuming asks the same question as starting.
      final robot = robotWith(tester);
      robot.supabase.rest('GET /rest/v1/sessions', [
        rows([
          sessionRow(questions: [rateQuestion]),
        ]),
      ]);
      await robot.launch();

      await robot.tap(robot.continueSession);

      expect(robot.consent, findsOneWidget);
      expect(robot.session, findsNothing);
    });

    testWidgets('declining starts nothing and leaves the journal usable', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();

      await robot.tap(robot.decline);

      // Nothing recorded, nothing sent, and the journal is still there.
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.session, findsNothing);
      expect(robot.consent, findsNothing);
      expect(robot.home, findsOneWidget);
      expect(robot.start, findsOneWidget);
      expect(robot.declined, findsOneWidget);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_declined', version),
      ]);

      // And the question can be answered differently a moment later.
      await robot.startSession();

      expect(robot.consent, findsOneWidget);
    });

    testWidgets('leaving the gate by the back arrow starts nothing', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();

      // Dismissing the route is not an answer, and certainly not a yes.
      await robot.back();

      expect(robot.home, findsOneWidget);
      expect(robot.session, findsNothing);
      expect(robot.supabase.to(consentGrant), isEmpty);

      // Nothing is left half-set: asking again is a clean question.
      await robot.startSession();

      expect(robot.consent, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(robot.checkbox).value, isFalse);
    });

    testWidgets('a consent that cannot be recorded starts no session', (
      tester,
    ) async {
      final robot = robotWith(tester, grants: [restRefused()]);
      await robot.launch();
      await robot.startSession();

      await robot.consentAndContinue();

      // The write failed, so the gate stays shut: a session must never run
      // on a consent the server has no record of.
      expect(robot.session, findsNothing);
      expect(robot.consent, findsOneWidget);
      expect(robot.consentFailure, findsOneWidget);
      expect(
        robot.analytics.events,
        isNot(contains(event('consent_granted', version))),
      );

      // The retry is the same act, and it lands this time.
      await robot.tap(robot.retry);

      expect(robot.supabase.to(consentGrant), hasLength(2));
      expect(robot.session, findsOneWidget);
    });

    testWidgets('a double tap records one consent and starts one session', (
      tester,
    ) async {
      final robot = robotWith(tester, grants: [delayedAuth(rpcReturned(null))]);
      await robot.launch();
      await robot.startSession();
      await robot.tap(robot.checkbox);

      await tester.tap(robot.agree);
      await tester.pump();

      // While the write is in flight the button is gone — the screen shows
      // progress — so a second tap has nothing to hit and cannot write a
      // second consent. The bloc refuses one anyway if it ever did.
      expect(robot.agree, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await robot.settle();

      expect(robot.supabase.to(consentGrant), hasLength(1));
      expect(robot.session, findsOneWidget);
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_granted', version),
        ...robot.analytics.events.skip(2),
      ]);
    });

    testWidgets('a consent that cannot be read starts no session', (
      tester,
    ) async {
      // Both reads fail — the journal's on the way in, which then defers
      // to the screen, and the screen's own — so it is reached without an
      // answer.
      final robot = robotWith(tester, reads: [restRefused(), restRefused()]);
      await robot.launch();

      await robot.startSession();

      // Not knowing is not the same as knowing the user consented: the gate
      // stays shut and no session starts.
      expect(robot.session, findsNothing);
      expect(robot.consent, findsOneWidget);
      // But it does not ask the question either — re-prompting someone who
      // already consented, every time the network hiccups, is what trains
      // people to tick boxes without reading them.
      expect(robot.checkbox, findsNothing);
      expect(find.text(robot.strings.consentUnknownMessage), findsOneWidget);
      // The screen's failed read is reported, content-free, as its own
      // step; the journal's only defers to the screen, so it is not counted
      // twice.
      expect(robot.analytics.exceptions, hasLength(1));
      expect(robot.analytics.exceptions.single.properties, {
        'step': 'consent_load',
      });

      // Looking again is offered, and works.
      await robot.tap(robot.retry);

      expect(robot.checkbox, findsOneWidget);
      expect(find.text(robot.strings.consentUnknownMessage), findsNothing);
    });

    testWidgets('a failed read can be backed out of', (tester) async {
      final robot = robotWith(tester, reads: [restRefused(), restRefused()]);
      await robot.launch();
      await robot.startSession();

      await robot.tap(robot.decline);

      // Leaving a screen that could not ask the question is not a refusal,
      // so nothing is recorded and nothing is claimed about it.
      expect(robot.home, findsOneWidget);
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.declined, findsNothing);
    });

    testWidgets('declining after a failed write still starts nothing', (
      tester,
    ) async {
      final robot = robotWith(tester, grants: [restRefused()]);
      await robot.launch();
      await robot.startSession();
      await robot.consentAndContinue();

      expect(robot.consentFailure, findsOneWidget);

      await robot.tap(robot.decline);

      // Out of the gate without a session and without a record.
      expect(robot.home, findsOneWidget);
      expect(robot.session, findsNothing);
      // And told what actually happened: the user ticked the box and the
      // write failed, so calling that a refusal would be the app
      // misreporting its own history.
      expect(robot.declined, findsNothing);
      expect(find.text(robot.strings.consentFailureMessage), findsOneWidget);
    });

    testWidgets('the notice is a link the screen can open', (tester) async {
      final launcher = UrlLauncherSpy.setup();
      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();

      await robot.tap(robot.notice);

      expect(launcher.launched, [privacyNoticeUrl]);
      // Reading the notice is not consenting to it.
      expect(robot.supabase.to(consentGrant), isEmpty);
      expect(robot.consent, findsOneWidget);
    });

    testWidgets('says what is sent, to whom, and under which basis', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();

      // Everything an explicit consent has to be informed about, in the
      // app's own words and in three points: what is sent and to whom, what
      // may not be done with it, why it is sensitive and that it can be
      // taken back. The full notice is one tap away for the rest.
      final points = consentPoints(robot.strings);
      expect(points, hasLength(3));
      for (final point in points) {
        expect(find.text('${point.lead} ${point.body}'), findsOneWidget);
      }
      expect(find.textContaining('training'), findsOneWidget);
      expect(find.text(robot.strings.consentCheckboxLabel), findsOneWidget);
      expect(find.byKey(ConsentView.noticeKey), findsOneWidget);

      // EDPB 05/2020 para 64 (vi): a third-country transfer and its
      // safeguard are minimum elements, so they are named rather than
      // implied.
      expect(find.textContaining('outside the EU'), findsOneWidget);
      expect(
        find.textContaining('standard contractual clauses'),
        findsOneWidget,
      );

      // The name travels with the answers so the companion can address the
      // user (#204), whether they chose it or emotely picked a nickname.
      expect(find.textContaining('the name you chose'), findsOneWidget);
      expect(find.textContaining('nickname emotely picked'), findsOneWidget);
    });

    testWidgets('stays usable and complete at double text size', (
      tester,
    ) async {
      // The screen is already longer than a viewport; at 2.0 it is much
      // longer, and a consent nobody can scroll to the end of is not an
      // informed one.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();

      expect(robot.consent, findsOneWidget);
      expect(tester.takeException(), isNull);

      await robot.consentAndContinue();

      expect(robot.supabase.to(consentGrant), hasLength(1));
      expect(robot.session, findsOneWidget);
    });

    testWidgets('never lets journal content leave the device (ADR 0005)', (
      tester,
    ) async {
      final robot = robotWith(tester);
      await robot.launch();
      await robot.startSession();
      await robot.consentAndContinue();

      // The consent events carry a version and nothing else; no wording of
      // the notice and nothing the user wrote ever reaches PostHog.
      final strings = robot.strings;
      for (final outgoing in robot.analytics.outgoingStrings) {
        for (final point in consentPoints(strings)) {
          expect(outgoing, isNot(contains(point.body)));
        }
        expect(outgoing, isNot(contains(strings.consentCheckboxLabel)));
      }
      expect(robot.analytics.events, [
        event('journal_viewed', journalViewed),
        event('consent_granted', version),
        ...robot.analytics.events.skip(2),
      ]);
    });

    testWidgets('meets accessibility guidelines', (tester) async {
      final robot = robotWith(tester);
      await robot.supabase.signedIn();

      await tester.expectMeetsAccessibilityGuidelines(
        robot.app,
        prepare: (tester) async {
          await robot.settle();
          await robot.startSession();
          // The box reachable and labelled, the button and the link too.
          await tester.ensureVisible(robot.checkbox);
          await robot.settle();
        },
      );
    });
  });
}
