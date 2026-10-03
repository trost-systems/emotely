import 'package:emotely_web/app.dart';
import 'package:emotely_web/beta_links.dart';
import 'package:emotely_web/components/confirm_waitlist.dart';
import 'package:emotely_web/components/delete_account_form.dart';
import 'package:emotely_web/components/waitlist_form.dart';
import 'package:emotely_web/pages/app_privacy.dart';
import 'package:emotely_web/pages/beta.dart';
import 'package:emotely_web/pages/confirm.dart';
import 'package:emotely_web/pages/de/app_privacy.dart';
import 'package:emotely_web/pages/de/beta.dart';
import 'package:emotely_web/pages/de/confirm.dart';
import 'package:emotely_web/pages/de/delete_account.dart';
import 'package:emotely_web/pages/de/home.dart';
import 'package:emotely_web/pages/de/imprint.dart';
import 'package:emotely_web/pages/de/privacy.dart';
import 'package:emotely_web/pages/delete_account.dart';
import 'package:emotely_web/pages/home.dart';
import 'package:emotely_web/pages/imprint.dart';
import 'package:emotely_web/pages/privacy.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  group('Home', () {
    testComponents('leads with the promise and asks for an address', (tester) {
      tester.pumpComponent(const Home());

      expect(
        find.textContaining('without staring at a blank page'),
        findsOneComponent,
      );
      expect(find.byType(WaitlistForm), findsOneComponent);
    });

    testComponents('shows how it works, what you get and the risk reversal', (
      tester,
    ) {
      tester.pumpComponent(const Home());

      expect(find.text('How it works'), findsOneComponent);
      expect(find.text('What you get'), findsOneComponent);
      expect(
        find.textContaining('Free during early access'),
        findsOneComponent,
      );
      expect(find.textContaining('delete'), findsComponents);
    });

    testComponents('answers the questions people ask before they sign up', (
      tester,
    ) {
      tester.pumpComponent(const Home());

      expect(find.text('Questions'), findsOneComponent);
      expect(find.textContaining('therapy'), findsComponents);
      expect(find.textContaining('train'), findsComponents);
    });

    testComponents('links to the code', (tester) {
      tester.pumpComponent(const Home());

      expect(find.textContaining('Read the code'), findsComponents);
    });

    testComponents('names the platforms, not one phone brand', (tester) {
      tester.pumpComponent(const Home());

      expect(find.textContaining('iOS and Android'), findsComponents);
      expect(find.textContaining('iPhone'), findsNothing);
    });
  });

  group('Confirm', () {
    testComponents('pre-renders the checking state for the island', (tester) {
      tester.pumpComponent(const Confirm());

      expect(find.byType(ConfirmWaitlist), findsOneComponent);
      expect(find.textContaining('Checking your link'), findsOneComponent);
    });
  });

  group('DeleteAccount', () {
    testComponents('gives the in-app path first, then the form', (tester) {
      tester.pumpComponent(const DeleteAccount());

      expect(find.textContaining('If you still have the app'), findsComponents);
      expect(find.textContaining('More → Delete account'), findsComponents);
      expect(
        find.textContaining('If you no longer have the app'),
        findsComponents,
      );
      expect(find.byType(DeleteAccountForm), findsOneComponent);
    });

    testComponents('says what is deleted and that it does not come back', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccount());

      expect(find.textContaining('journal entry'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('promises nothing the form does not do', (tester) {
      tester.pumpComponent(const DeleteAccount());

      // Deleting is immediate; no "we will get back to you within 30 days".
      expect(find.textContaining('immediate'), findsComponents);
    });

    testComponents('names the app and developer as the Play listing has them', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccount());

      // The Play record keeps the legacy title until the first new
      // version (ADR 0012); when it is renamed, this test says so.
      expect(
        find.textContaining('Reflect Therapy AI: emotely'),
        findsOneComponent,
      );
      expect(find.textContaining('Peter Trost'), findsComponents);
    });

    testComponents('is honest about backups rather than claiming none', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccount());

      expect(find.textContaining('live database'), findsComponents);
      expect(find.textContaining('retention window'), findsComponents);
      // The old copy claimed there was no backup copy at all.
      expect(find.textContaining('no backup'), findsNothing);
    });

    testComponents('says what survives the deletion, and calls it that', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccount());

      expect(find.text('What is not deleted'), findsOneComponent);
      // "anonymous" would overstate what the counting actually is.
      expect(find.textContaining('pseudonymous'), findsComponents);
    });
  });

  group('Legal pages', () {
    testComponents('the imprint names the operator and a contact address', (
      tester,
    ) {
      tester.pumpComponent(const Imprint());

      expect(find.textContaining('Peter Trost'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('the imprint carries the VAT ID (§ 27a UStG)', (tester) {
      tester.pumpComponent(const Imprint());

      expect(find.textContaining('DE369514299'), findsOneComponent);
    });

    testComponents(
      'the privacy page names every party that touches an address',
      (tester) {
        tester.pumpComponent(const Privacy());

        expect(find.textContaining('Supabase'), findsComponents);
        expect(find.textContaining('Resend'), findsComponents);
        expect(find.textContaining('Vercel'), findsComponents);
        expect(find.textContaining('PostHog'), findsComponents);
        expect(find.textContaining('hello@getemotely.com'), findsComponents);
      },
    );

    testComponents(
      'the privacy page gives a legal basis, a retention and a regulator',
      (tester) {
        tester.pumpComponent(const Privacy());

        expect(find.textContaining('Art. 6 (1) (a)'), findsComponents);
        expect(find.textContaining('Art. 6 (1) (f)'), findsComponents);
        expect(find.textContaining('erased after one day'), findsOneComponent);
        expect(find.textContaining('deleted after a week'), findsOneComponent);
        expect(find.textContaining('Landesbeauftragte'), findsOneComponent);
        expect(find.textContaining('served from this site'), findsOneComponent);
      },
    );

    testComponents(
      'the privacy page answers the Art. 13 questions a reader cannot infer',
      (tester) {
        tester.pumpComponent(const Privacy());

        // Art. 13 (2) (e): whether giving the address is obligatory, and
        // what happens if you do not. Voluntariness alone does not say it.
        expect(find.textContaining('under no obligation'), findsOneComponent);
        // Art. 33/34: a breach has a named timeline, not just a promise of
        // "appropriate measures".
        expect(find.textContaining('within 72 hours'), findsOneComponent);
        // WP260: a dated change log plus an active notice, never "check
        // this page periodically" on its own.
        expect(find.textContaining('told by email before'), findsOneComponent);
        // Art. 13 (1) (b): the absence of a DPO is itself the disclosure.
        expect(
          find.textContaining('no data protection officer'),
          findsOneComponent,
        );
      },
    );

    testComponents('the privacy page says the language is stored, and why', (
      tester,
    ) {
      tester.pumpComponent(const Privacy());

      // supabase/migrations/*_waitlist_locale.sql: the row keeps the site
      // language, and the confirmation mail is written in it.
      expect(
        find.textContaining(
          'the language of the page you signed up on (English or German',
        ),
        findsOneComponent,
      );
      expect(
        find.textContaining('so the confirmation email comes in it'),
        findsOneComponent,
      );
    });

    testComponents(
      "the privacy page names the deletion page's human check (#94)",
      (tester) {
        tester.pumpComponent(const Privacy());

        // lib/turnstile_web.dart: Cloudflare's script loads on the deletion
        // page, once its reader asks for a code, and nowhere else.
        expect(find.textContaining('Cloudflare Turnstile'), findsComponents);
        expect(
          find.textContaining('only on the deletion page'),
          findsComponents,
        );
        expect(find.textContaining('once you ask for a code'), findsComponents);
        // What the Turnstile Privacy Addendum says it processes, and the
        // part Cloudflare decides for itself.
        expect(find.textContaining('TLS fingerprint'), findsComponents);
        expect(
          find.textContaining('improve its bot detection'),
          findsComponents,
        );
        expect(find.textContaining('§ 25 (2) No. 2 TDDDG'), findsComponents);
        // The old overclaims: PostHog is no longer the only outside script,
        // and the providers are no longer four.
        expect(find.textContaining('the only outside script'), findsNothing);
        expect(find.textContaining('Four providers'), findsNothing);
      },
    );

    testComponents('the privacy page points at the deletion page', (tester) {
      tester.pumpComponent(const Privacy());

      // The retention section links it; the human check names it too.
      expect(find.textContaining('the deletion page'), findsComponents);
      expect(find.textContaining('Delete account'), findsComponents);
      // Truthful about backups, rather than promising none exist.
      expect(find.textContaining('retention window'), findsComponents);
    });

    testComponents('the privacy page hands the app off to its own notice', (
      tester,
    ) {
      tester.pumpComponent(const Privacy());

      // What Google read and rejected: the site notice used to say the app
      // carried its notice inside itself, which it never did.
      expect(find.textContaining('notice inside it'), findsNothing);
      expect(find.textContaining('own privacy notice'), findsOneComponent);
    });

    testComponents('the privacy page says what a browser can do to the list', (
      tester,
    ) {
      tester.pumpComponent(const Privacy());

      // The form posts from the browser with the publishable key (ADR 0011),
      // so the notice once overclaimed: there is no server in between. What
      // the grants allow is an insert and the confirm_waitlist call (#281).
      expect(find.textContaining('never the browser'), findsNothing);
      expect(find.textContaining('own server can reach'), findsNothing);
      expect(
        find.textContaining('never readable from a browser'),
        findsOneComponent,
      );
    });
  });

  group('AppPrivacy', () {
    testComponents('names the controller and how to reach them', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('Peter Trost'), findsComponents);
      expect(find.textContaining('Rottenburg am Neckar'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('names the app as the Play listing still has it', (tester) {
      tester.pumpComponent(const AppPrivacy());

      // The Play record keeps the legacy title until the first new version
      // (ADR 0012); when it is renamed, this test says so.
      expect(
        find.textContaining('Reflect Therapy AI: emotely'),
        findsOneComponent,
      );
    });

    testComponents('covers every category the stores ask about', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.text('Your email address'), findsOneComponent);
      expect(find.text('Your name'), findsOneComponent);
      expect(find.text('Your journal entries and sessions'), findsOneComponent);
      expect(
        find.text('The conversation with the assistant'),
        findsOneComponent,
      );
      expect(find.text('Usage analytics and crash reports'), findsOneComponent);
      expect(find.text('What stays on your phone'), findsOneComponent);
      // The h3 subsections appear once; the h2 ones appear twice, because
      // the table of contents names each of them as well.
      expect(find.text('Who else sees any of it'), findsNComponents(2));
      expect(find.text('Deleting your account'), findsNComponents(2));
      expect(find.text('Your rights'), findsNComponents(2));
      expect(find.text('Children'), findsNComponents(2));
      expect(find.text('Changes to this notice'), findsNComponents(2));
    });

    testComponents('gives a legal basis, including Art. 9 for entries', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('Art. 6 (1) (b)'), findsComponents);
      // Still the basis of the firewall's rate limit and the agent's
      // per-round record — no longer of the in-app analytics.
      expect(find.textContaining('Art. 6 (1) (f)'), findsComponents);
      // Journal entries are special-category data, and the page says so.
      expect(find.textContaining('Art. 9 (2) (a)'), findsComponents);
      expect(find.textContaining('health'), findsComponents);
    });

    testComponents('names every processor and where the data sits', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('Supabase'), findsComponents);
      expect(find.textContaining('Vercel AI Gateway'), findsComponents);
      expect(find.textContaining('PostHog'), findsComponents);
      expect(find.textContaining('Frankfurt'), findsComponents);
    });

    testComponents('states the training and retention opt-out as settled', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Since #96 every round sends disallowPromptTraining and
      // zeroDataRetention, so the page states it rather than hedging.
      expect(find.textContaining('not to train on prompts'), findsComponents);
      expect(find.textContaining('zero-retention'), findsComponents);
      // Both filters fail closed, and the page says so rather than
      // implying a silent fallback.
      expect(find.textContaining('fail closed'), findsComponents);
      // The old hedge, from before the flags were set.
      expect(find.textContaining('not currently switched on'), findsNothing);
    });

    testComponents('names surveys as the one free text PostHog receives', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Content-free is still the rule, so the one exception is stated
      // rather than left to be discovered.
      expect(find.textContaining('survey'), findsComponents);
      expect(find.textContaining('Answering is optional'), findsComponents);
      expect(find.textContaining('sent to PostHog'), findsComponents);
      // Surveys do not make replay true.
      expect(
        find.textContaining('No session replay and no screen recording'),
        findsComponents,
      );
    });

    testComponents('says what Google and Apple hand over at sign-in', (tester) {
      tester.pumpComponent(const AppPrivacy());

      // #51: both providers are optional ways into the same account, and
      // what each passes on is stated rather than implied.
      expect(find.textContaining('Sign in with Google'), findsComponents);
      expect(find.textContaining('Sign in with Apple'), findsComponents);
      // Google's token carries a name and a picture; Supabase keeps them.
      expect(find.textContaining('name and profile picture'), findsComponents);
      // Apple lets the user hide the address, which then cannot match.
      expect(find.textContaining('Hide My Email'), findsComponents);
      // The provider learns of the sign-in as a controller of its own.
      expect(find.textContaining('learns that you signed in'), findsComponents);
      // The name the app uses is the one it asks for (#204), never the one
      // a provider passes on.
      expect(
        find.textContaining('does not take a name from Google or Apple'),
        findsComponents,
      );
    });

    testComponents('says the account keeps the language of the sign-in mail', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // #229: the app keeps its language on the account (Supabase Auth's
      // user metadata) so the sign-in mail comes in it.
      expect(
        find.textContaining('the language the app is shown in'),
        findsComponents,
      );
    });

    testComponents('says how a password is kept and an address confirmed', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // #187: email and password for everyone; a new account opens with
      // the code mailed to it, and a reset goes the same way. GoTrue keeps
      // a bcrypt hash of the password, never the password.
      expect(find.textContaining('a password you choose'), findsComponents);
      expect(find.textContaining('one-way hash'), findsComponents);
      expect(find.textContaining('six-digit code'), findsComponents);
      expect(find.textContaining('no password, no link'), findsNothing);
      expect(
        find.textContaining('with a password instead of a code'),
        findsNothing,
      );
    });

    testComponents('says the app asks what to call you, and where it goes', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // #204: onboarding asks for a name before the account exists.
      expect(find.textContaining('never asks for a name'), findsNothing);
      expect(find.textContaining('what to call you'), findsComponents);
      expect(find.textContaining('placeholder'), findsComponents);
      expect(find.textContaining('profile'), findsComponents);
      expect(find.textContaining('Profile'), findsComponents);
    });

    testComponents(
      'says the name goes to the model, and the address does not',
      (tester) {
        tester.pumpComponent(const AppPrivacy());

        // #204: the companion addresses you by name, so the name rides along
        // with each round. The old denial must not survive the change.
        expect(find.textContaining('no name, no email address'), findsNothing);
        expect(
          find.textContaining('no email address and no sign-in token'),
          findsComponents,
        );
        expect(
          find.textContaining('the name the app calls you'),
          findsComponents,
        );
      },
    );

    testComponents('says the language the app shows goes to the model', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // #228: the companion asks and writes in the app's language, so the
      // locale rides along with each round and reaches the provider too.
      expect(
        find.textContaining('the language the app is set to'),
        findsComponents,
      );
      expect(
        find.textContaining('the name the app calls you and its language'),
        findsComponents,
      );
    });

    testComponents('describes analytics by kind, never by event name', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Readers want what goes where and why; an event list goes stale
      // with every new event and buries that (#204).
      expect(find.textContaining('session_started'), findsNothing);
      expect(find.textContaining('sign_in_code_requested'), findsNothing);
      expect(find.textContaining('journal_viewed'), findsNothing);
      expect(find.textContaining('consent_granted'), findsNothing);
      expect(find.textContaining('screens, taps, timings'), findsComponents);
    });

    testComponents('asks before counting, and sets nothing up before Allow', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // § 25 TDDDG: the device identifier is stored on the phone, so
      // analytics need consent — bundled with Art. 6 (1) (a) for the
      // processing (DSK OH Digitale Dienste, Rn. 97–98).
      expect(find.textContaining('§ 25 (1) TDDDG'), findsComponents);
      expect(find.textContaining('Art. 6 (1) (a)'), findsComponents);
      expect(find.textContaining('equal weight'), findsComponents);
      expect(find.textContaining('before you tap Allow'), findsComponents);
      expect(find.textContaining('asked again'), findsComponents);
      expect(find.textContaining('More → Privacy settings'), findsComponents);
      // The old basis for the in-app counting.
      expect(
        find.textContaining('legitimate interest in knowing whether the app'),
        findsNothing,
      );
    });

    testComponents('keeps the last sign-in method on the phone', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('last used'), findsComponents);
      expect(find.textContaining('§ 25 (2)'), findsComponents);
    });

    testComponents('is dated to the rewrite', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(
        find.textContaining('Last updated 3 October 2026'),
        findsOneComponent,
      );
    });

    testComponents('discloses where the agent runs', (tester) {
      tester.pumpComponent(const AppPrivacy());

      // The agent's Vercel functions are pinned to fra1 by apps/agent/
      // vercel.json (ADR 0010, amendment 2026-09-27). The transcript can
      // still leave the EU at the gateway and the model provider, so that
      // transfer and its safeguard stay disclosed.
      expect(
        find.textContaining('agent runs on Vercel’s servers in Frankfurt'),
        findsOneComponent,
      );
      expect(
        find.textContaining('runs the emotely agent in Frankfurt'),
        findsOneComponent,
      );
      expect(find.textContaining('Washington'), findsNothing);
      expect(find.textContaining('USA'), findsNothing);
      expect(
        find.textContaining('model providers can sit outside the EU'),
        findsOneComponent,
      );
      expect(
        find.textContaining('standard contractual clauses'),
        findsComponents,
      );
    });

    testComponents('gives both deletion paths and links the web one', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('More → Delete account'), findsComponents);
      expect(find.textContaining('deletion page'), findsComponents);
    });

    testComponents('is honest about backups rather than claiming none', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('retention window'), findsComponents);
      expect(find.textContaining('no backup'), findsNothing);
      // "anonymous" would overstate what the counting actually is.
      expect(find.textContaining('pseudonymous'), findsComponents);
    });

    testComponents('points at the site notice for the site', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(find.textContaining('site privacy notice'), findsOneComponent);
    });

    testComponents('describes the consent gate and the way to take it back', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Apple 5.1.1(i) wants the revocation path described, and it must be
      // the one the app actually offers (#97, #204), not "delete your
      // account".
      expect(find.textContaining('More → Privacy settings'), findsComponents);
      expect(find.textContaining('does not require deleting'), findsComponents);
      expect(find.textContaining('Art. 7 (3)'), findsComponents);
    });

    testComponents('carries the Art. 13 disclosures that are easy to forget', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Art. 22 (1): a negative statement satisfies it, silence does not.
      // Twice: the heading, and its entry in the table of contents.
      expect(find.text('Automated decisions'), findsNComponents(2));
      expect(find.textContaining('Art. 22 (1)'), findsComponents);
      // Art. 12 (3) response time, and a privacy contact.
      expect(find.textContaining('within one month'), findsComponents);
      // Art. 13 (2) (e): consequence of not providing the address.
      expect(find.textContaining('not a statutory duty'), findsComponents);
      // Play's secure-handling disclosure.
      expect(find.textContaining('encrypted HTTPS'), findsComponents);
      // ADR 0008's IP-keyed rate limit.
      expect(find.textContaining('thirty a minute'), findsComponents);
    });

    testComponents('says an AI is doing this, rather than leaving it obvious', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // EU AI Act Art. 50, in force since 2 August 2026. The exemption is
      // for cases where it is obvious; this states it instead of relying
      // on that.
      expect(find.textContaining('produced by an AI system'), findsComponents);
      expect(find.textContaining('not by a person'), findsComponents);
    });

    testComponents('says what happens when the measures fail', (tester) {
      tester.pumpComponent(const AppPrivacy());

      // Art. 33/34. The legacy lawyer-drafted policy carried this and the
      // rewrite dropped it; a journal that can hold Art. 9 data is the
      // last place to leave it out. Twice: heading and table of contents.
      expect(find.text('If something goes wrong'), findsNComponents(2));
      expect(find.textContaining('within 72 '), findsComponents);
      expect(find.textContaining('Art. 34 GDPR'), findsComponents);
    });

    testComponents('confirms the recipients protect the data equally', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // Apple Guideline 5.1.1(i) asks for this confirmation specifically,
      // separately from naming the recipients.
      expect(find.textContaining('same standard'), findsComponents);
      // And that the two who are not processors are named as such, rather
      // than being swept into one reassuring sentence.
      expect(find.textContaining('not our processors'), findsComponents);
    });

    testComponents('names the identifiers analytics are tied to', (tester) {
      tester.pumpComponent(const AppPrivacy());

      // The store declarations name a Device ID and a User ID, and the page
      // has to account for both — including that identify() links what
      // came before sign-in to the account.
      expect(find.textContaining('random device identifier'), findsComponents);
      expect(find.textContaining('account identifier'), findsComponents);
      expect(find.textContaining('before you signed in'), findsComponents);
    });

    testComponents('gives analytics a retention criterion like every other '
        'category', (tester) {
      tester.pumpComponent(const AppPrivacy());

      expect(
        find.textContaining('retention window for the project'),
        findsComponents,
      );
    });

    testComponents('names the human check before a sign-in mail (#94)', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacy());

      // feature_auth: every captcha-protected Supabase call carries a
      // Turnstile token the app fetched in a hidden web view first.
      expect(find.textContaining('Cloudflare Turnstile'), findsComponents);
      expect(find.textContaining('hidden web view'), findsComponents);
      expect(find.textContaining('TLS fingerprint'), findsComponents);
      expect(find.textContaining('improve its bot detection'), findsComponents);
      expect(find.text('Cloudflare'), findsComponents);
      // Cloudflare is the one recipient besides Apple and Google that also
      // uses something for its own purpose; the blanket claim must say so.
      expect(
        find.textContaining('Every one of them except Apple and Google'),
        findsNothing,
      );
    });

    // The suite above asserts that hedges are PRESENT. These assert that
    // overclaims are ABSENT — the needle pattern from apps/mobile/app. Findings 1,
    // 2 and 4 of the red-team review all survived a presence-only suite.
    group('claims nothing the code does not do', () {
      testComponents('does not deny sending the address to our own server', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacy());

        // Every round carries the sign-in token, whose JWT holds the
        // address (agent_client.dart, request-auth.ts). The narrowed claim
        // is about the gateway payload only, and must stay narrowed.
        expect(
          find.textContaining('the transcript carries no name and no email'),
          findsNothing,
        );
        expect(find.textContaining('sign-in token'), findsComponents);
      });

      testComponents('does not claim the server sends PostHog nothing', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacy());

        // telemetry.ts ships a PostHogSpanProcessor: tokens, latency, cost
        // and promptId per round, content suppressed at source.
        expect(
          find.textContaining('technical record of each round'),
          findsComponents,
        );
        expect(
          find.textContaining('suppressed at the source'),
          findsComponents,
        );
      });

      testComponents('does not enumerate session columns without the '
          'transcript', (tester) {
        tester.pumpComponent(const AppPrivacy());

        // The migration stores `transcript jsonb not null`; leaving it out
        // of an otherwise exhaustive list understates what is kept.
        expect(
          find.textContaining('full transcript of the conversation'),
          findsComponents,
        );
      });

      testComponents('does not promise deletion leaves only two survivors', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacy());

        // /delete-account names three, the waitlist among them.
        expect(find.textContaining('waitlist'), findsComponents);
        expect(find.textContaining('Two things outlive'), findsNothing);
      });

      testComponents('does not count the forwarded exception types', (tester) {
        tester.pumpComponent(const AppPrivacy());

        // forwardedTypes has four entries, not three; the page avoids the
        // count rather than restating a number that drifts.
        expect(find.textContaining('Only three kinds'), findsNothing);
      });

      testComponents('does not overstate where the model is recorded', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacy());

        // EMOTELY_MODEL can override the default at runtime, so the repo
        // records the default, not necessarily the model in use.
        expect(
          find.textContaining('model in use is recorded in the public'),
          findsNothing,
        );
      });

      testComponents('does not call the counting anonymous', (tester) {
        tester.pumpComponent(const AppPrivacy());

        expect(find.textContaining('pseudonymous'), findsComponents);
        expect(find.textContaining('anonymous counting'), findsNothing);
      });
    });
  });

  // The German notice is held to the English one's claims, one for one: each
  // test below mirrors the English test of the same name with the German
  // phrase, so a claim dropped or softened in translation fails here the
  // way it would in English.
  group('ImprintDe', () {
    testComponents('names the operator and a contact address', (tester) {
      tester.pumpComponent(const ImprintDe());

      expect(find.text('Impressum'), findsOneComponent);
      expect(find.textContaining('Peter Trost'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
      expect(find.textContaining('§ 5 DDG'), findsOneComponent);
    });

    testComponents('carries the VAT ID (§ 27a UStG)', (tester) {
      tester.pumpComponent(const ImprintDe());

      expect(find.textContaining('DE369514299'), findsOneComponent);
      expect(
        find.textContaining('Umsatzsteuer-Identifikationsnummer'),
        findsOneComponent,
      );
    });
  });

  group('AppPrivacyDe', () {
    testComponents('names the controller and how to reach them', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Peter Trost'), findsComponents);
      expect(find.textContaining('Rottenburg am Neckar'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('links the German imprint', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.byComponentPredicate(
          (component) =>
              component is DomComponent &&
              component.attributes?['href'] == '/de/imprint',
        ),
        findsOneComponent,
      );
    });

    testComponents('names the app as the Play listing still has it', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Reflect Therapy AI: emotely'),
        findsOneComponent,
      );
    });

    testComponents('covers every category the stores ask about', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.text('Datenschutzerklärung der App'), findsOneComponent);
      expect(find.text('Deine E-Mail-Adresse'), findsOneComponent);
      expect(find.text('Dein Name'), findsOneComponent);
      expect(
        find.text('Deine Tagebucheinträge und Sessions'),
        findsOneComponent,
      );
      expect(find.text('Das Gespräch mit emotely'), findsOneComponent);
      expect(
        find.text('Nutzungsanalyse und Absturzberichte'),
        findsOneComponent,
      );
      expect(find.text('Was auf deinem Handy bleibt'), findsOneComponent);
      expect(find.text('Wer sonst etwas davon sieht'), findsNComponents(2));
      expect(find.text('Dein Konto löschen'), findsNComponents(2));
      expect(find.text('Deine Rechte'), findsNComponents(2));
      expect(find.text('Kinder'), findsNComponents(2));
      expect(
        find.text('Änderungen dieser Datenschutzerklärung'),
        findsNComponents(2),
      );
    });

    testComponents('gives a legal basis, including Art. 9 for entries', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Art. 6 Abs. 1 lit. b'), findsComponents);
      expect(find.textContaining('Art. 6 Abs. 1 lit. f'), findsComponents);
      expect(find.textContaining('Art. 9 Abs. 2 lit. a'), findsComponents);
      expect(find.textContaining('Gesundheit'), findsComponents);
    });

    testComponents('names every processor and where the data sits', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Supabase'), findsComponents);
      expect(find.textContaining('Vercel AI Gateway'), findsComponents);
      expect(find.textContaining('PostHog'), findsComponents);
      expect(find.textContaining('Frankfurt'), findsComponents);
    });

    testComponents('states the training and retention opt-out as settled', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('untersagt ist, mit Prompts zu trainieren'),
        findsComponents,
      );
      expect(find.textContaining('Zero Data Retention'), findsComponents);
      expect(find.textContaining('fail closed'), findsComponents);
      expect(find.textContaining('derzeit nicht eingeschaltet'), findsNothing);
    });

    testComponents('names surveys as the one free text PostHog receives', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Umfrage'), findsComponents);
      expect(
        find.textContaining('Die Antwort ist freiwillig'),
        findsComponents,
      );
      expect(find.textContaining('an PostHog gesendet'), findsComponents);
      expect(
        find.textContaining('Session Replay) und keine Bildschirmaufnahme'),
        findsComponents,
      );
    });

    testComponents('says what Google and Apple hand over at sign-in', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Mit Google anmelden'), findsComponents);
      expect(find.textContaining('Mit Apple anmelden'), findsComponents);
      expect(
        find.textContaining('Namen und den Link zum Profilbild'),
        findsComponents,
      );
      expect(find.textContaining('E-Mail-Adresse verbergen'), findsComponents);
      expect(
        find.textContaining('erfährt, dass du dich bei emotely angemeldet'),
        findsComponents,
      );
      expect(
        find.textContaining('übernimmt sie weder von Google noch von Apple'),
        findsComponents,
      );
    });

    testComponents('says the account keeps the language of the sign-in mail', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('die Sprache, in der die App angezeigt wird'),
        findsComponents,
      );
    });

    testComponents('says how a password is kept and an address confirmed', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('ein Passwort, das du wählst'),
        findsComponents,
      );
      expect(find.textContaining('Einweg-Hash'), findsComponents);
      expect(find.textContaining('sechsstelligen Code'), findsComponents);
      expect(find.textContaining('kein Passwort, kein Link'), findsNothing);
      expect(
        find.textContaining('mit einem Passwort statt mit einem Code'),
        findsNothing,
      );
    });

    testComponents('says the app asks what to call you, and where it goes', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('fragt nie nach einem Namen'), findsNothing);
      expect(find.textContaining('wie sie dich nennen soll'), findsComponents);
      expect(find.textContaining('Platzhalter'), findsComponents);
      expect(find.textContaining('dein Profil'), findsComponents);
      expect(find.textContaining('unter Profil'), findsComponents);
    });

    testComponents(
      'says the name goes to the model, and the address does not',
      (tester) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(
          find.textContaining('kein Name, keine E-Mail-Adresse'),
          findsNothing,
        );
        expect(
          find.textContaining('keine E-Mail-Adresse und kein Anmelde-Token'),
          findsComponents,
        );
        expect(
          find.textContaining('den Namen, mit dem die App dich anspricht'),
          findsComponents,
        );
      },
    );

    testComponents('says the language the app shows goes to the model', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      // #228, as in English: the app's language rides along with each
      // round and reaches the provider too.
      expect(
        find.textContaining('die Sprache, auf die die App eingestellt ist'),
        findsComponents,
      );
      expect(
        find.textContaining('dich anspricht, und die Sprache der App'),
        findsComponents,
      );
    });

    testComponents('describes analytics by kind, never by event name', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('session_started'), findsNothing);
      expect(find.textContaining('sign_in_code_requested'), findsNothing);
      expect(find.textContaining('journal_viewed'), findsNothing);
      expect(find.textContaining('consent_granted'), findsNothing);
      expect(
        find.textContaining('Bildschirme, Antippen, Zeiten'),
        findsComponents,
      );
    });

    testComponents('asks before counting, and sets nothing up before Allow', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('§ 25 Abs. 1 TDDDG'), findsComponents);
      expect(find.textContaining('Art. 6 Abs. 1 lit. a'), findsComponents);
      expect(find.textContaining('gleich gewichtet'), findsComponents);
      expect(
        find.textContaining('Bevor du „Erlauben“ antippst'),
        findsComponents,
      );
      expect(find.textContaining('erneut gefragt'), findsComponents);
      expect(
        find.textContaining('Mehr → Datenschutzeinstellungen'),
        findsComponents,
      );
      expect(
        find.textContaining('berechtigtes Interesse daran, zu wissen, ob'),
        findsNothing,
      );
    });

    testComponents('keeps the last sign-in method on the phone', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('zuletzt verwendet'), findsComponents);
      expect(find.textContaining('§ 25 Abs. 2'), findsComponents);
    });

    testComponents('is dated to the rewrite', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Zuletzt aktualisiert am 3. Oktober 2026'),
        findsOneComponent,
      );
    });

    testComponents('discloses where the agent runs', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Agent läuft auf Vercels Servern in Frankfurt'),
        findsOneComponent,
      );
      expect(
        find.textContaining('betreibt den emotely-Agenten in Frankfurt'),
        findsOneComponent,
      );
      expect(find.textContaining('Washington'), findsNothing);
      expect(find.textContaining('USA'), findsNothing);
      expect(
        find.textContaining('Modellanbieter können außerhalb der EU sitzen'),
        findsOneComponent,
      );
      expect(find.textContaining('Standardvertragsklauseln'), findsComponents);
    });

    testComponents('gives both deletion paths and links the web one', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Mehr → Konto löschen'), findsComponents);
      expect(find.textContaining('Löschseite'), findsComponents);
    });

    testComponents('is honest about backups rather than claiming none', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Aufbewahrungsfenster'), findsComponents);
      expect(find.textContaining('kein Backup'), findsNothing);
      expect(find.textContaining('pseudonym'), findsComponents);
    });

    testComponents('points at the site notice for the site', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Datenschutzerklärung der Website'),
        findsOneComponent,
      );
    });

    testComponents('describes the consent gate and the way to take it back', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Mehr → Datenschutzeinstellungen'),
        findsComponents,
      );
      expect(find.textContaining('nichts löschen musst'), findsComponents);
      expect(find.textContaining('Art. 7 Abs. 3'), findsComponents);
    });

    testComponents('carries the Art. 13 disclosures that are easy to forget', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.text('Automatisierte Entscheidungen'), findsNComponents(2));
      expect(find.textContaining('Art. 22 Abs. 1'), findsComponents);
      expect(find.textContaining('innerhalb eines Monats'), findsComponents);
      expect(find.textContaining('keine gesetzliche Pflicht'), findsComponents);
      expect(find.textContaining('verschlüsselte HTTPS'), findsComponents);
      expect(find.textContaining('dreißig pro Minute'), findsComponents);
    });

    testComponents('says an AI is doing this, rather than leaving it obvious', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('von einem KI-System erzeugt'),
        findsComponents,
      );
      expect(find.textContaining('nicht von einem Menschen'), findsComponents);
    });

    testComponents('says what happens when the measures fail', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.text('Wenn etwas schiefgeht'), findsNComponents(2));
      expect(find.textContaining('innerhalb von 72 '), findsComponents);
      expect(find.textContaining('Art. 34 DSGVO'), findsComponents);
    });

    testComponents('confirms the recipients protect the data equally', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('demselben Standard'), findsComponents);
      expect(
        find.textContaining('nicht unsere Auftragsverarbeiter'),
        findsComponents,
      );
    });

    testComponents('names the identifiers analytics are tied to', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('zufällige Gerätekennung'), findsComponents);
      expect(find.textContaining('Kontokennung'), findsComponents);
      expect(find.textContaining('vor deiner Anmeldung'), findsComponents);
    });

    testComponents('gives analytics a retention criterion like every other '
        'category', (tester) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(
        find.textContaining('Aufbewahrungsfenster von PostHog für das Projekt'),
        findsComponents,
      );
    });

    // CONTEXT.md's words to avoid, which the copy spell check enforces in
    // the app's ARB files but cannot see in Dart: "Assistent" for the
    // companion, "Sitzung" for a session, "Datenschutzhinweise" for the
    // privacy notice.
    testComponents('uses the glossary’s German terms', (tester) {
      for (final page in const [AppPrivacyDe(), ImprintDe()]) {
        tester.pumpComponent(page);

        expect(find.textContaining('Assistent'), findsNothing);
        expect(find.textContaining('Sitzung'), findsNothing);
        expect(find.textContaining('Datenschutzhinweis'), findsNothing);
      }
    });

    testComponents('names the human check before a sign-in mail (#94)', (
      tester,
    ) {
      tester.pumpComponent(const AppPrivacyDe());

      expect(find.textContaining('Cloudflare Turnstile'), findsComponents);
      expect(find.textContaining('verborgenen Web-Ansicht'), findsComponents);
      expect(find.textContaining('TLS-Fingerabdruck'), findsComponents);
      expect(
        find.textContaining('seine Bot-Erkennung zu verbessern'),
        findsComponents,
      );
      expect(find.text('Cloudflare'), findsComponents);
      expect(find.textContaining('Alle außer Apple und Google'), findsNothing);
    });

    group('claims nothing the code does not do', () {
      testComponents('does not deny sending the address to our own server', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(
          find.textContaining('Transkript enthält keinen Namen und keine'),
          findsNothing,
        );
        expect(find.textContaining('Anmelde-Token'), findsComponents);
      });

      testComponents('does not claim the server sends PostHog nothing', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(
          find.textContaining('technischen Datensatz zu jeder Runde'),
          findsComponents,
        );
        expect(
          find.textContaining('schon an der Quelle unterdrückt'),
          findsComponents,
        );
      });

      testComponents('does not enumerate session columns without the '
          'transcript', (tester) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(
          find.textContaining('vollständige Transkript des Gesprächs'),
          findsComponents,
        );
      });

      testComponents('does not promise deletion leaves only two survivors', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(find.textContaining('Warteliste'), findsComponents);
        expect(find.textContaining('Zwei Dinge überdauern'), findsNothing);
      });

      testComponents('does not count the forwarded exception types', (tester) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(find.textContaining('Nur drei Arten'), findsNothing);
      });

      testComponents('does not overstate where the model is recorded', (
        tester,
      ) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(
          find.textContaining('verwendete Modell steht im öffentlichen'),
          findsNothing,
        );
      });

      testComponents('does not call the counting anonymous', (tester) {
        tester.pumpComponent(const AppPrivacyDe());

        expect(find.textContaining('pseudonym'), findsComponents);
        expect(find.textContaining('anonyme Zählung'), findsNothing);
      });
    });
  });

  // The site notice in German, held to the English one's claims in the
  // 'Legal pages' group above, one test per English test.
  group('PrivacyDe', () {
    testComponents('names every party that touches an address', (tester) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.text('Datenschutzerklärung'), findsOneComponent);
      expect(find.textContaining('Supabase'), findsComponents);
      expect(find.textContaining('Resend'), findsComponents);
      expect(find.textContaining('Vercel'), findsComponents);
      expect(find.textContaining('PostHog'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('gives a legal basis, a retention and a regulator', (
      tester,
    ) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.textContaining('Art. 6 Abs. 1 lit. a'), findsComponents);
      expect(find.textContaining('Art. 6 Abs. 1 lit. f'), findsComponents);
      expect(find.textContaining('nach einem Tag gelöscht'), findsOneComponent);
      expect(
        find.textContaining('nach einer Woche gelöscht'),
        findsOneComponent,
      );
      expect(find.textContaining('Landesbeauftragte'), findsOneComponent);
      expect(
        find.textContaining('von dieser Website selbst ausgeliefert'),
        findsOneComponent,
      );
    });

    testComponents('names the human check on the deletion page (#94)', (
      tester,
    ) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.textContaining('Cloudflare Turnstile'), findsComponents);
      expect(find.textContaining('nur auf der Löschseite'), findsComponents);
      expect(
        find.textContaining('sobald du einen Code anforderst'),
        findsComponents,
      );
      expect(find.textContaining('TLS-Fingerabdruck'), findsComponents);
      expect(
        find.textContaining('seine Bot-Erkennung zu verbessern'),
        findsComponents,
      );
      expect(find.textContaining('§ 25 Abs. 2 Nr. 2 TDDDG'), findsComponents);
      expect(find.textContaining('das einzige fremde Skript'), findsNothing);
      expect(find.textContaining('Vier Anbieter'), findsNothing);
    });

    testComponents('answers the Art. 13 questions a reader cannot infer', (
      tester,
    ) {
      tester.pumpComponent(const PrivacyDe());

      // Art. 13 (2) (e): obligatory or not, and what follows if not.
      expect(find.textContaining('nicht verpflichtet'), findsOneComponent);
      // Art. 33/34: a breach has a named timeline.
      expect(
        find.textContaining('innerhalb von 72 Stunden'),
        findsOneComponent,
      );
      // WP260: an active notice before a material change.
      expect(
        find.textContaining('per E-Mail, bevor es wirksam wird'),
        findsOneComponent,
      );
      // Art. 13 (1) (b): the absence of a DPO is itself the disclosure.
      expect(
        find.textContaining('keinen Datenschutzbeauftragten'),
        findsOneComponent,
      );
    });

    testComponents('says the language is stored, and why', (tester) {
      tester.pumpComponent(const PrivacyDe());

      expect(
        find.textContaining(
          'die Sprache der Seite, auf der du dich eingetragen hast (Englisch '
          'oder Deutsch',
        ),
        findsOneComponent,
      );
      expect(
        find.textContaining('damit die Bestätigungs-E-Mail in ihr kommt'),
        findsOneComponent,
      );
    });

    testComponents('points at the German deletion page', (tester) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.text('der Löschseite'), findsOneComponent);
      expect(find.textContaining('Konto löschen'), findsComponents);
      expect(
        find.byComponentPredicate(
          (component) =>
              component is DomComponent &&
              component.attributes?['href'] == '/de/delete-account',
        ),
        findsOneComponent,
      );
      // Truthful about backups, rather than promising none exist.
      expect(find.textContaining('Aufbewahrungsfenster'), findsComponents);
    });

    testComponents('hands the app off to its own German notice', (tester) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.textContaining('in der App selbst'), findsNothing);
      expect(find.text('eigene Datenschutzerklärung'), findsOneComponent);
      expect(
        find.byComponentPredicate(
          (component) =>
              component is DomComponent &&
              component.attributes?['href'] == '/de/app-privacy',
        ),
        findsOneComponent,
      );
    });

    testComponents('says what a browser can do to the list', (tester) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.textContaining('nie der Browser'), findsNothing);
      expect(find.textContaining('eigene Server der'), findsNothing);
      expect(
        find.textContaining('von einem Browser aus nie lesen'),
        findsOneComponent,
      );
    });

    testComponents('says "Datenschutzerklärung", never "Datenschutzhinweise"', (
      tester,
    ) {
      tester.pumpComponent(const PrivacyDe());

      expect(find.textContaining('Datenschutzhinweis'), findsNothing);
    });
  });

  // The German landing pages, held to what their English originals say, one
  // test per English test.
  group('HomeDe', () {
    testComponents('leads with the promise and asks for an address', (tester) {
      tester.pumpComponent(const HomeDe());

      expect(
        find.textContaining('ohne vor einer leeren Seite zu sitzen'),
        findsOneComponent,
      );
      expect(find.byType(WaitlistForm), findsOneComponent);
    });

    testComponents('shows how it works, what you get and the risk reversal', (
      tester,
    ) {
      tester.pumpComponent(const HomeDe());

      expect(find.text('So funktioniert’s'), findsOneComponent);
      expect(find.text('Was du bekommst'), findsOneComponent);
      expect(
        find.textContaining('Kostenlos während des frühen Zugangs'),
        findsOneComponent,
      );
      expect(find.textContaining('lösch'), findsComponents);
    });

    testComponents('answers the questions people ask before they sign up', (
      tester,
    ) {
      tester.pumpComponent(const HomeDe());

      expect(find.text('Fragen'), findsOneComponent);
      expect(find.textContaining('Therapie'), findsComponents);
      expect(find.textContaining('Trainieren'), findsComponents);
    });

    testComponents('links to the code', (tester) {
      tester.pumpComponent(const HomeDe());

      expect(find.textContaining('Den Code auf GitHub lesen'), findsComponents);
    });

    testComponents('names the platforms, not one phone brand', (tester) {
      tester.pumpComponent(const HomeDe());

      expect(find.textContaining('iOS und Android'), findsComponents);
      expect(find.textContaining('iPhone'), findsNothing);
    });
  });

  group('ConfirmDe', () {
    testComponents('pre-renders the checking state for the island', (tester) {
      tester.pumpComponent(const ConfirmDe());

      expect(find.byType(ConfirmWaitlist), findsOneComponent);
      expect(find.textContaining('Dein Link wird geprüft'), findsOneComponent);
    });
  });

  group('DeleteAccountDe', () {
    testComponents('gives the in-app path first, then the form', (tester) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(find.textContaining('Wenn du die App noch hast'), findsComponents);
      expect(find.textContaining('Mehr → Konto löschen'), findsComponents);
      expect(
        find.textContaining('Wenn du die App nicht mehr hast'),
        findsComponents,
      );
      expect(find.byType(DeleteAccountForm), findsOneComponent);
    });

    testComponents('says what is deleted and that it does not come back', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(find.textContaining('Tagebucheintrag'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
    });

    testComponents('promises nothing the form does not do', (tester) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(find.textContaining('sofort'), findsComponents);
    });

    testComponents('names the app and developer as the Play listing has them', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(
        find.textContaining('Reflect Therapy AI: emotely'),
        findsOneComponent,
      );
      expect(find.textContaining('Peter Trost'), findsComponents);
    });

    testComponents('is honest about backups rather than claiming none', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(find.textContaining('Live-Datenbank'), findsComponents);
      expect(find.textContaining('Aufbewahrungsfenster'), findsComponents);
      expect(find.textContaining('kein Backup'), findsNothing);
    });

    testComponents('says what survives the deletion, and calls it that', (
      tester,
    ) {
      tester.pumpComponent(const DeleteAccountDe());

      expect(find.text('Was nicht gelöscht wird'), findsOneComponent);
      expect(find.textContaining('pseudonym'), findsComponents);
    });
  });

  group('BetaDe', () {
    testComponents('says it is an invitation and asks not to share it', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.text('emotely-Beta'), findsOneComponent);
      expect(find.textContaining('eingeladen'), findsComponents);
      expect(find.textContaining('nur mit Einladung'), findsComponents);
      expect(find.textContaining('nicht weiterzugeben'), findsComponents);
    });

    testComponents('tells crawlers not to index or follow it', (tester) {
      tester.pumpComponent(const BetaDe());

      expect(
        find.byComponentPredicate((component) {
          if (component is! DomComponent || component.tag != 'meta') {
            return false;
          }
          final attributes = component.attributes;
          return attributes?['name'] == 'robots' &&
              attributes?['content'] == 'noindex, nofollow';
        }),
        findsOneComponent,
      );
    });

    testComponents('gives iPhone the TestFlight link and the two steps', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.text('iPhone'), findsOneComponent);
      expect(find.text('Bei TestFlight mitmachen'), findsOneComponent);
      expect(find.textContaining('TestFlight-App'), findsComponents);
      expect(find.textContaining('auf dem iPhone'), findsComponents);
    });

    testComponents('gives Android the Play link and the account caveat', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.text('Android'), findsOneComponent);
      expect(find.text('Bei Google Play mitmachen'), findsOneComponent);
      expect(
        find.textContaining('Google-Konto beschränkt, das wir eingeladen'),
        findsComponents,
      );
      expect(
        find.textContaining('antworte auf die Einladung'),
        findsComponents,
      );
    });

    testComponents('sets expectations for a beta rather than a release', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.text('Was dich erwartet'), findsOneComponent);
      expect(find.textContaining('kaputtgehen'), findsComponents);
      expect(find.textContaining('neuer Build'), findsComponents);
      expect(find.textContaining('privat'), findsComponents);
      expect(find.textContaining('Umfrage'), findsComponents);
    });

    testComponents('promises no build per merge and warns of forced updates', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.textContaining('Jeder Merge'), findsNothing);
      expect(find.textContaining('ohne Vorwarnung'), findsNothing);
      expect(find.textContaining('zu aktualisieren'), findsComponents);
    });

    testComponents('gives both feedback channels and asks for the version', (
      tester,
    ) {
      tester.pumpComponent(const BetaDe());

      expect(find.text('Feedback'), findsOneComponent);
      expect(find.textContaining('Feedback senden'), findsComponents);
      expect(find.textContaining('Tab „Mehr“'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
      expect(find.textContaining('App-Version'), findsComponents);
    });
  });

  testComponents('the German pages use the glossary’s German terms', (tester) {
    for (final page in const [
      HomeDe(),
      ConfirmDe(),
      DeleteAccountDe(),
      BetaDe(),
    ]) {
      tester.pumpComponent(page);

      expect(find.textContaining('Assistent'), findsNothing);
      expect(find.textContaining('Sitzung'), findsNothing);
      expect(find.textContaining('Datenschutzhinweis'), findsNothing);
    }
  });

  group('Beta', () {
    testComponents('says it is an invitation and asks not to share it', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.text('emotely beta'), findsOneComponent);
      expect(find.textContaining('invited'), findsComponents);
      expect(find.textContaining('by invitation only'), findsComponents);
      expect(find.textContaining('not to share'), findsComponents);
    });

    // The page is linked from nothing: not the header, not the footer, not
    // the sitemap. robots.txt stays untouched on purpose — a Disallow line
    // would advertise the path — so the meta tag is the only instruction a
    // crawler that found the URL anyway ever gets.
    testComponents('tells crawlers not to index or follow it', (tester) {
      tester.pumpComponent(const Beta());

      // Document.head renders each meta entry as a real <meta> element, so
      // the assertion is on what ships rather than on the wrapper type.
      expect(
        find.byComponentPredicate((component) {
          if (component is! DomComponent || component.tag != 'meta') {
            return false;
          }
          final attributes = component.attributes;
          return attributes?['name'] == 'robots' &&
              attributes?['content'] == 'noindex, nofollow';
        }),
        findsOneComponent,
      );
    });

    testComponents('gives iPhone the TestFlight link and the two steps', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.text('iPhone'), findsOneComponent);
      expect(find.text('Join on TestFlight'), findsOneComponent);
      expect(find.textContaining('TestFlight app'), findsComponents);
      expect(find.textContaining('on the iPhone'), findsComponents);
    });

    testComponents('gives Android the Play link and the account caveat', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.text('Android'), findsOneComponent);
      expect(find.text('Join on Google Play'), findsOneComponent);
      // A closed track only admits the address we added, so the page says
      // so before the tester hits a page they cannot make sense of.
      expect(find.textContaining('Google account we invited'), findsComponents);
      expect(find.textContaining('reply to the invitation'), findsComponents);
    });

    testComponents('sets expectations for a beta rather than a release', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.text('What to expect'), findsOneComponent);
      expect(find.textContaining('may break'), findsComponents);
      expect(find.textContaining('new build'), findsComponents);
      expect(find.textContaining('private'), findsComponents);
      expect(find.textContaining('survey'), findsComponents);
    });

    // Merges land on the internal tracks only; a beta build is promoted by
    // hand (release-app skill), so the page must not promise otherwise. What
    // a tester does need to know is that an old build can be blocked by the
    // force-update screen.
    testComponents('promises no build per merge and warns of forced updates', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.textContaining('Every merge'), findsNothing);
      expect(find.textContaining('without warning'), findsNothing);
      expect(find.textContaining('ask you to update'), findsComponents);
    });

    testComponents('gives both feedback channels and asks for the version', (
      tester,
    ) {
      tester.pumpComponent(const Beta());

      expect(find.text('Feedback'), findsOneComponent);
      expect(find.textContaining('Send feedback'), findsComponents);
      expect(find.textContaining('More tab'), findsComponents);
      expect(find.textContaining('hello@getemotely.com'), findsComponents);
      expect(find.textContaining('app version'), findsComponents);
    });

    // The two links are the whole point of the page, and a placeholder that
    // ships silently is the failure mode worth its own test.
    test('the Play link opts in to the real package', () {
      expect(
        playTestingUrl,
        'https://play.google.com/apps/testing/de.emotely.emotely',
      );
    });

    test('the TestFlight link is a public join link', () {
      expect(
        testFlightJoinUrl,
        startsWith('https://testflight.apple.com/join/'),
      );
    });
  });

  group('Routing', () {
    // jaspr build generates sitemap.xml from the router's routes, so a page
    // that is not registered is a page the stores cannot fetch — which is
    // how the URL Google rejected came to be dead in the first place. The
    // route itself is proved end to end by the build (the page renders and
    // /app-privacy appears in sitemap.xml); what a component test can add
    // is that the link the stores and readers follow is really emitted.
    testComponents('the footer links to the app notice on every page', (
      tester,
    ) {
      tester.pumpComponent(const App());

      expect(find.text('App privacy'), findsOneComponent);
    });

    // /beta is unlisted: it reaches a tester through one invitation mail and
    // nowhere else. A link in the header or the footer would put it in front
    // of every visitor and every crawler, which is the one thing the page
    // must not be. The sitemap is kept clear of it by --sitemap-exclude in
    // the build, and robots.txt is deliberately left alone.
    testComponents('nothing on the site links to the beta page', (tester) {
      tester.pumpComponent(const App());

      expect(
        find.byComponentPredicate(
          (component) =>
              component is DomComponent &&
              component.attributes?['href'] == betaPath,
        ),
        findsNothing,
      );
      expect(find.textContaining('beta'), findsNothing);
    });
  });
}
