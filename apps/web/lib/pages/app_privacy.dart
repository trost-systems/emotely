import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/app-privacy`: what the **app** does with data, as Art. 13 GDPR and both
/// stores ask for it. Sibling of the site notice at `/privacy`.
///
/// Google Play rejected the 2026-09-13 update because the privacy URL on the
/// listing did not resolve to a policy covering the app; `/privacy` opens by
/// disclaiming the app, so a reviewer reading it would reject again. Both
/// store listings point here from now on.
///
/// Every claim below is traceable to a migration, an ADR, the app's code or a
/// vendor's published policy — an unknown is written as an unknown rather
/// than smoothed over, because this is a text the controller signs off on.
/// It stays high level: per kind of data, what, where, why, basis and how
/// long — the event names live in the code (ADR 0005), not here (#204).
class const AppPrivacy({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    // A store reviewer arrives here cold, from a link in the listing, with
    // no idea what emotely is; the site-wide description sells the product
    // instead of saying what this page is.
    Document.head(
      meta: {
        'description':
            'How the emotely app collects, uses and shares data: the '
            'account, your name, journal entries, the AI conversation, '
            'analytics, deletion and your GDPR rights.',
      },
    ),
    h1([.text('App privacy notice')]),
    // Google asks the policy to name the app as the listing has it; the
    // Play record keeps the legacy title until the first new version
    // ships (ADR 0012), so both names are given.
    p([
      .text(
        'This notice covers the emotely mobile app (listed on Google Play as '
        '"Reflect Therapy AI: emotely") for iOS and Android. The web site at '
        'getemotely.com and its waitlist have a separate notice. Last '
        'updated 2 October 2026.',
      ),
    ]),

    // Eleven sections is more than a reader should have to scroll blind,
    // and a store reviewer is looking for one specific thing.
    nav(classes: 'toc', [
      h2([.text('On this page')]),
      ul([
        li([
          a(href: '#responsible', [.text('Who is responsible')]),
        ]),
        li([
          a(href: '#collects', [.text('What the app collects, and why')]),
        ]),
        li([
          a(href: '#recipients', [.text('Who else sees any of it')]),
        ]),
        li([
          a(href: '#deletion', [.text('Deleting your account')]),
        ]),
        li([
          a(href: '#breach', [.text('If something goes wrong')]),
        ]),
        li([
          a(href: '#rights', [.text('Your rights')]),
        ]),
        li([
          a(href: '#automated', [.text('Automated decisions')]),
        ]),
        li([
          a(href: '#children', [.text('Children')]),
        ]),
        li([
          a(href: '#not-medical', [.text('Not a medical service')]),
        ]),
        li([
          a(href: '#web-site', [.text('The web site')]),
        ]),
        li([
          a(href: '#changes', [.text('Changes to this notice')]),
        ]),
      ]),
    ]),

    h2(id: 'responsible', [.text('Who is responsible')]),
    p([
      .text('Peter Trost, Yalovastr. 5, 72108 Rottenburg am Neckar, Germany, '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. Sole controller for everything below; there is no company and no '
        'co-controller. Full details in the ',
      ),
      a(href: '/imprint', [.text('imprint')]),
      .text('.'),
    ]),

    h2(id: 'collects', [.text('What the app collects, and why')]),

    h3([.text('Your email address')]),
    p([
      .text(
        'Signing in needs an email address, given one of three ways: the '
        'app mails you a six-digit code to type back in (no password, no '
        'link), or Sign in with Google (iOS and Android) or Sign in with '
        'Apple (iPhone) confirms who you are and passes your address on. '
        'The address and the sign-in records live in Supabase Auth on '
        'servers in Frankfurt, Germany (EU). The app never asks for a phone '
        'number, a date of birth, contacts, photos, location or an '
        'advertising identifier.',
      ),
    ]),
    // #51. What each provider's token carries is what Supabase keeps, so
    // the notice names it — including the name Google sends unasked.
    p([
      .text(
        'Google and Apple also pass on an identifier for your account with '
        'them, which is how the next sign-in finds the same account. Google '
        'adds the name and profile picture link of your Google account, and '
        'Supabase keeps them with the sign-in records; the app does not use '
        'them. It does not take a name from Google or Apple at all — it asks '
        'you (below). Apple can pass on a name too, but the app does not '
        'ask it to. With Apple’s Hide My Email we receive a relay address '
        'that forwards to yours. An address that matches an account you '
        'already have lands you in that account; a relay address never '
        'matches, so it starts a new one. We never see your Google or Apple '
        'password. The provider learns that you signed in to emotely — as a '
        'controller in its own right, under its own privacy policy — and '
        'nothing about your journal.',
      ),
    ]),
    // #229: the sign-in mail template reads user_metadata.app_locale.
    p([
      .text(
        'With the sign-in records, Supabase Auth also keeps the language the '
        'app is shown in (English or German), so that your sign-in code '
        'mails come in that language.',
      ),
    ]),
    p([
      .text(
        'While you are signed in, every request to our own server carries '
        'your sign-in token, which holds your account identifier and your '
        'address. It stops at our server and is never passed on to the '
        'gateway or the model provider.',
      ),
    ]),
    p([
      .text(
        'Basis: the contract you asked for (Art. 6 (1) (b) GDPR). Giving the '
        'address is not a statutory duty, but without one there is no '
        'account and so nothing to journal into. Kept until you delete the '
        'account.',
      ),
    ]),

    // #204: onboarding asks for a name before the account exists.
    h3([.text('Your name')]),
    p([
      .text(
        'The app asks what to call you, normally before you sign up. '
        'Answering is optional: if you skip, it picks a placeholder '
        'name and tells you so. Until your account exists the name '
        'stays on your phone; then it moves to your profile in the same '
        'Supabase database in Frankfurt, with a note of whether you chose it '
        'or the app did. The app uses it to greet you, and the assistant '
        'uses it to address you (see the conversation, below). Change it '
        'any time in Profile, from the More tab. Basis: the personalised '
        'service you asked for (Art. 6 (1) (b) GDPR). Kept until you delete '
        'the account.',
      ),
    ]),

    h3([.text('Your journal entries and sessions')]),
    p([
      .text(
        'A session is one guided conversation: the assistant asks a '
        'question, you answer, and at the end it writes the entry. Besides '
        'your profile, three kinds of record are stored for you:',
      ),
    ]),
    ul([
      li([
        strong([.text('Sessions')]),
        .text(
          ' — the full transcript of the conversation, every question and '
          'every answer as the model saw them, plus where you are in it, '
          'which question set you picked, whether it is finished and the '
          'app version that wrote it. This is what lets a closed or crashed '
          'app pick a session back up.',
        ),
      ]),
      li([
        strong([.text('Entries')]),
        .text(
          ' — the finished entry: the summary the assistant wrote, your '
          'answers and the questions as they were asked.',
        ),
      ]),
      li([
        strong([.text('Consents')]),
        .text(
          ' — each time you give or withdraw a consent (to sending sessions '
          'to a model provider, and to usage analytics), when, and which '
          'version of the wording you were shown. Records are only ever '
          'added, never changed. The wording itself is not copied for each '
          'person; the record names its version.',
        ),
      ]),
    ]),
    p([
      .text(
        'All of it lives in one Postgres database at Supabase in Frankfurt, '
        'Germany (EU), readable only by your account. The database enforces '
        'that on every query (row-level security), not the app: a query for '
        'somebody else’s rows comes back empty, whoever sends it. The '
        'rules are in the open-source ',
      ),
      a(href: '$repositoryUrl/blob/main/supabase/migrations', [
        .text('database migrations'),
      ]),
      .text(', and a test suite proves them on every change.'),
    ]),
    p([
      strong([.text('This is sensitive data, and it is treated as such.')]),
      .text(
        ' An entry can say how you felt or slept, what a diagnosis or a '
        'medication is doing to you, how things stand with someone close to '
        'you, or what you believe. Entries can therefore hold health data '
        'and other special categories under Art. 9 GDPR. The basis is your '
        'explicit consent (Art. 9 (2) (a) GDPR), alongside the contract '
        '(Art. 6 (1) (b) GDPR).',
      ),
    ]),
    p([
      .text(
        'Before your first session the app asks for that consent: it says '
        'what is sent, to whom, and what it can contain, and nothing is sent '
        'until you tick the box and start. Declining is a real choice — '
        'nothing is sent, and your existing entries stay readable. You can '
        'withdraw it at any time under More → Privacy settings: one switch, '
        'which does not require deleting anything and does not affect what '
        'happened before. Taking it back is as easy as giving it '
        '(Art. 7 (3) GDPR). Because the assistant writes your entry, no new '
        'session can start while it is withdrawn; turning it back on shows '
        'you the full consent screen again.',
      ),
    ]),
    p([
      .text(
        'Entries are kept until you delete them or the account. There is no '
        'automatic expiry: a journal that quietly erased last year would not '
        'be a journal.',
      ),
    ]),

    h3([.text('The conversation with the assistant')]),
    p([
      .text(
        'This is the part that leaves your phone. Each round of a session '
        'sends the emotely agent — a small server of ours — the transcript '
        'so far, the name the app calls you (yours or the placeholder), '
        'the language the app is set to (so the questions and your entry '
        'come in it), the app version, your sign-in token, and a signature '
        'proving the '
        'transcript is one the server itself produced. The agent adds the '
        'assistant’s instructions and hands the conversation to a language '
        'model through the ',
      ),
      strong([.text('Vercel AI Gateway')]),
      .text(
        ', which passes it to whichever provider serves the model. The '
        'gateway and the provider receive the conversation, the '
        'instructions, the name the app calls you and its language — no '
        'email address and '
        'no sign-in token. The reply comes back the same way and becomes the '
        'next question, or your entry.',
      ),
    ]),
    ul([
      li([
        strong([.text('The agent keeps no copy.')]),
        .text(
          ' It has no database: each request carries the whole transcript, '
          'is answered, and is forgotten, and nothing that was said is '
          'written to a log. It does send PostHog a technical record of each '
          'round — how long it took, how many tokens it used, what it cost, '
          'which version of the instructions ran — with the content '
          'suppressed at the source. That record runs on our server, stores '
          'nothing on your phone and is not part of the usage analytics you '
          'choose in the app; it is how we keep the service working and its '
          'cost in check (legitimate interest, Art. 6 (1) (f) GDPR).',
        ),
      ]),
      li([
        strong([.text('Where it runs.')]),
        .text(
          ' The agent runs on Vercel’s servers in Frankfurt, Germany (EU), '
          'next to the database. The gateway and the model providers can sit '
          'outside the EU; which provider answers, and where, depends on '
          'where the gateway routes at that moment. Those transfers rest on '
          'the EU standard contractual clauses (Art. 46 GDPR), and for the '
          'providers on the two routing guarantees below.',
        ),
      ]),
      li([
        strong([.text('Which model.')]),
        .text(
          ' Today openai/gpt-oss-120b, an open-weights model chosen by a '
          'benchmark rather than by brand. It can change without a new app '
          'release; the default is in the public repository, and this notice '
          'names the model in use.',
        ),
      ]),
      li([
        strong([.text('It is not training data, and it is not kept.')]),
        .text(
          ' Vercel states that the gateway itself neither retains prompts or '
          'responses nor trains on them. For the providers behind it, every '
          'round tells the gateway to route only to providers contractually '
          'bound not to train on prompts and bound by a zero-retention '
          'agreement, so the transcript is not kept on their side either. '
          'The gateway enforces both per request and both fail closed: with '
          'no qualifying provider the round fails rather than falling back to '
          'one that does not qualify. Checked against the live gateway on 15 '
          'September 2026, all eight providers serving the current model '
          'qualified. The provider still processes the transcript to answer '
          'it.',
        ),
      ]),
    ]),
    p([
      .text(
        'Basis: the contract (Art. 6 (1) (b) GDPR) and, because the '
        'transcript can carry the special-category data described above, '
        'your explicit consent (Art. 9 (2) (a) GDPR). Vercel and the model '
        'provider act as our processors (Art. 28 GDPR). The assistant is the '
        'product: there is no version of it that does not send your answers '
        'to a model, which is why the app asks before the first session '
        'rather than after.',
      ),
    ]),
    // EU AI Act Art. 50, in force since 2 August 2026: a person must be told
    // they are interacting with an AI system. The exemption is for cases
    // where it is obvious, and it arguably is here — but "arguably obvious"
    // is not a thing to rest a disclosure obligation on.
    p([
      .text(
        'Said plainly: the questions you are asked and the entry that gets '
        'written are produced by an AI system, not by a person. Nobody reads '
        'along, and there is no human on the other end of a session.',
      ),
    ]),

    // #204: high level on purpose — what, where, why, basis, how long. The
    // event names live in the code, and a list here went stale with every
    // new event.
    h3([.text('Usage analytics and crash reports')]),
    p([
      .text(
        'If you allow it, the app counts how it is used — screens, taps, '
        'timings and crashes — so we can see what works and fix what does '
        'not. It never sends what you write in your journal, your name or '
        'your email address: the reporting code never receives them, and a '
        'test drives a whole session with planted marker text to prove none '
        'escapes. Crash reports keep the error’s type, code and stack frames '
        'but lose its message, because a message can quote what it failed '
        'on; the only messages let through are wording we wrote ourselves or '
        'the name of a host. No session replay '
        'and no screen recording is used. The data goes to PostHog, on '
        'servers in the EU.',
      ),
    ]),
    p([
      .text(
        'Now and then the app may ask for feedback in a short survey. '
        'Answering is optional; if you answer, what you write is sent to '
        'PostHog.',
      ),
    ]),
    p([
      .text(
        'The records are tied to a random device identifier the analytics '
        'library keeps on your phone and, once you sign in, to your account '
        'identifier (a random ID, not your address); what was counted before '
        'you signed in is then linked to your account too. That makes them '
        'pseudonymous, not anonymous.',
      ),
    ]),
    p([
      .text(
        'The app asks on first launch, with Don’t allow and Allow given '
        'equal weight. Nothing is set up before you tap Allow: no identifier '
        'exists and nothing is sent. Change your mind any time under More → '
        'Privacy settings; switching off stops all reporting from then on. '
        'Signing out resets the choice and the device identifier, and you '
        'are asked again — the choice belongs to a person, not a phone. '
        'Basis: your consent, both to storing and reading the identifier on '
        'your phone (§ 25 (1) TDDDG) and to processing the records '
        '(Art. 6 (1) (a) GDPR). Withdrawing does not affect what was sent '
        'before. Kept no longer than PostHog’s retention window for the '
        'project, then deleted or aggregated past the point of tracing back '
        'to a person.',
      ),
    ]),

    h3([.text('What stays on your phone')]),
    p([
      .text(
        'Some things the app keeps only on the phone, because it cannot work '
        'without them: your sign-in session, your analytics choice, how far '
        'you got in the steps before sign-up, the name you gave until your '
        'account exists, and the sign-in method you last used, so the '
        'sign-in screen can mark it. The last used method is never sent '
        'anywhere; it survives signing out and is cleared when you delete '
        'the account. Storing these needs no consent, because each is '
        'strictly necessary for the service you asked for '
        '(§ 25 (2) no. 2 TDDDG).',
      ),
    ]),
    p([
      .text(
        'Everything that does leave the phone — to our server, the database '
        'and the analytics provider — travels over an encrypted HTTPS '
        'connection; the app makes no unencrypted connection at all.',
      ),
    ]),

    h3([.text('The store reviewer accounts')]),
    p([
      .text(
        'Two fixed accounts sign in with a password instead of a code, '
        'because Apple’s and Google’s reviewers have no mailbox to read a '
        'code from. They belong to the review process, and nothing in the '
        'app can create one.',
      ),
    ]),

    h2(id: 'recipients', [.text('Who else sees any of it')]),
    ul([
      li([
        strong([.text('Supabase')]),
        .text(
          ' — the database and the sign-in system, Frankfurt, Germany (EU). '
          'Holds your address, your profile, your sessions, your entries and '
          'your consent records.',
        ),
      ]),
      li([
        strong([.text('Vercel')]),
        .text(
          ' — runs the emotely agent in Frankfurt, Germany (EU), and the AI '
          'Gateway the conversation passes through. Stores no journal of '
          'ours. Its firewall also counts requests per internet address and '
          'refuses more than thirty a minute to the session endpoint, which '
          'keeps a public endpoint from being abused; that check uses the '
          'address and nothing else, on our legitimate interest in keeping '
          'the service working (Art. 6 (1) (f) GDPR).',
        ),
      ]),
      li([
        strong([.text('The model provider')]),
        .text(
          ' — whoever serves the current model through the gateway, for the '
          'moment it takes to answer. See above for what is and is not '
          'promised there.',
        ),
      ]),
      li([
        strong([.text('PostHog')]),
        .text(
          ' — usage analytics and crash reports if you allow them, survey '
          'answers if you give them, and the agent’s technical record of each '
          'round; EU servers. Never your journal, your name or your email '
          'address.',
        ),
      ]),
      li([
        strong([.text('Apple and Google')]),
        .text(
          ' — distribute the app and, independently of us, collect their own '
          'download and crash statistics under their own privacy policies. If '
          'you sign in with one of them, it confirms who you are, as described '
          'under your email address above.',
        ),
      ]),
    ]),
    p([
      .text(
        'Nothing is sold, nothing is shared for advertising, and there are '
        'no ad networks, no trackers and no third-party software development '
        'kits in the app beyond the ones named here.',
      ),
    ]),
    // Apple Guideline 5.1.1(i) asks the policy to confirm that third
    // parties receiving user data provide equal protection of it — a
    // separate statement from naming them, and one a reviewer looks for.
    p([
      .text(
        'Every one of them except Apple and Google handles this data only on '
        'our instructions, as a processor under a data processing agreement '
        '(Art. 28 GDPR) that binds them to protect it to the same standard '
        'described here and forbids them using it for their own purposes. '
        'Apple and Google are not our processors: what they collect when '
        'they distribute the app, they collect as controllers in their own '
        'right, under their own policies and outside our reach.',
      ),
    ]),

    h2(id: 'deletion', [.text('Deleting your account')]),
    p([
      .text(
        'In the app: More → Delete account, then confirm. '
        'Without the app: the ',
      ),
      a(href: '/delete-account', [.text('deletion page')]),
      .text(
        ', which mails you a code and deletes the account once you type it '
        'back in.',
      ),
    ]),
    p([
      .text(
        'Either way the account, your profile, every entry, every session '
        'and the consent records leave the live database as soon as the '
        'deletion goes through. There is no grace period and no archive to '
        'ask for afterwards. Three things outlive it:',
      ),
    ]),
    ul([
      li([
        strong([.text('Analytics.')]),
        .text(
          ' The pseudonymous records described above, if you allowed them. '
          'Deleting the account breaks the link between their identifiers '
          'and you, but the counts remain. They hold no journal text, no '
          'name and no address.',
        ),
      ]),
      li([
        strong([.text('Backups.')]),
        .text(
          ' Routine encrypted backups of the database as a whole may still '
          'hold a copy until they age out of the provider’s retention '
          'window. They are only ever used to recover the database after a '
          'failure, never to bring a deleted account back.',
        ),
      ]),
      li([
        strong([.text('The waitlist, if you joined it.')]),
        .text(
          ' That is a separate list behind the web site, and deleting your '
          'app account does not touch it. Write to ',
        ),
        a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
        .text(' and it is removed too.'),
      ]),
    ]),

    // Art. 33/34 GDPR. The legacy lawyer-drafted policy said this and the
    // rewrite dropped it; for a journal that can carry Art. 9 data, what
    // happens when the measures fail is not an optional paragraph.
    h2(id: 'breach', [.text('If something goes wrong')]),
    p([
      .text(
        'The measures above are meant to stop a breach, not to promise one '
        'is impossible. If personal data here is ever exposed, lost or '
        'reached by someone who should not have it, the supervisory '
        'authority named below is told without undue delay and within 72 '
        'hours of us becoming aware of it (Art. 33 GDPR). Where the breach '
        'is likely to put you at high risk — and for journal entries it '
        'would be — you are told directly, in plain language, without '
        'waiting to be asked (Art. 34 GDPR).',
      ),
    ]),

    h2(id: 'rights', [.text('Your rights')]),
    p([
      .text(
        'You can ask what is stored about you, have it corrected or deleted, '
        'have its processing restricted, receive it in a portable form, '
        'object to processing based on legitimate interest, and withdraw any '
        'consent at any time — which does not affect what happened before. '
        'Deleting the account does most of this at once; for anything else, '
        'write to ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        ' — the address for any privacy question, answered by Peter Trost '
        'personally. You will have an answer within one month of asking '
        '(Art. 12 (3) GDPR); if a request is genuinely complicated we will '
        'say so within that month, and why. You may also complain to a data '
        'protection authority. The one responsible for us is Der '
        'Landesbeauftragte für den Datenschutz und die Informationsfreiheit '
        'Baden-Württemberg, Lautenschlagerstraße 20, 70173 Stuttgart, '
        'poststelle@lfdi.bwl.de.',
      ),
    ]),

    h2(id: 'automated', [.text('Automated decisions')]),
    p([
      .text(
        'The assistant works automatically: it picks the next question and '
        'writes the summary of your entry without anyone reading along. That '
        'is the only automated processing here. No decision is made about '
        'you that has legal effects or similarly significantly affects you — '
        'nothing is scored, ranked, or passed to anyone who decides '
        'something about you — so Art. 22 (1) GDPR on automated individual '
        'decision-making does not apply.',
      ),
    ]),

    h2(id: 'children', [.text('Children')]),
    p([
      .text(
        'emotely is for people aged 16 and over. It is not made for or '
        'directed at children: it collects nothing for advertising and shows '
        'no ads. Sixteen is the age from which you can consent to this '
        'processing on your own in Germany (Art. 8 GDPR), and because the '
        'product runs on your consent, it is the minimum the app assumes. We '
        'do not verify age, and the store age ratings are still being set as '
        'part of the release; once they are, this section will name them. '
        'If you believe a child has written entries here, write to ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(' and the account will be deleted.'),
    ]),

    h2(id: 'not-medical', [.text('Not a medical service')]),
    p([
      .text(
        'emotely is a journaling tool. It is not therapy, not a medical '
        'device and not a substitute for professional care, and the '
        'assistant does not diagnose or treat anything. If you are in '
        'crisis, please contact a professional or your local emergency '
        'number.',
      ),
    ]),

    h2(id: 'web-site', [.text('The web site')]),
    p([
      .text('getemotely.com and the early-access waitlist are covered by the '),
      a(href: '/privacy', [.text('site privacy notice')]),
      .text(', a separate text about separate data.'),
    ]),

    h2(id: 'changes', [.text('Changes to this notice')]),
    p([
      .text(
        'Changes are published here with a new date at the top, and every '
        'version is in the public repository, so what changed and when is a '
        'matter of record. Anything that materially changes what happens to '
        'your journal will be told to you in the app or by email before it '
        'takes effect. emotely is open source under the MIT licence: you '
        'never have to take our word for any of this — ',
      ),
      a(href: repositoryUrl, [.text('read the code')]),
      .text('.'),
    ]),
  ]);
}
