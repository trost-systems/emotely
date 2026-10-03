import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// What this site does with data: the notice Art. 13 GDPR asks for, in the
/// order a reader asks the questions. The site stores one thing, an
/// address someone typed into the waitlist form; everything else here is
/// the machinery around that.
class const Privacy({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Privacy')]),
    p([
      .text('This page covers getemotely.com, the web site. The app has its '),
      a(href: '/app-privacy', [.text('own privacy notice')]),
      .text('. Last updated 3 October 2026.'),
    ]),

    h2(id: 'stores', [.text('What the site stores')]),
    p([
      .text(
        'Nothing, unless you join the waitlist. Then it stores the email '
        'address you typed, the moment you sent it, a "source" tag (the '
        'campaign tags in the link you used, or the site that linked here), '
        'the language of the page you signed up on (English or German, so '
        'the confirmation email comes in it), a random token that the '
        'confirmation link carries, and the IP address of the request. The '
        'IP address exists only to limit abuse of the form: it is erased '
        'after one day, before it could be linked to anything. An address '
        'that never clicks its confirmation link is deleted after a week.',
      ),
    ]),

    h2(id: 'basis', [.text('Why, and on what basis')]),
    ul([
      li([
        strong([.text('Your address')]),
        .text(
          ' is kept so we can tell you when early access opens for you. '
          'Basis: your consent (Art. 6 (1) (a) GDPR), given by submitting '
          'the form. Giving the address is neither a legal nor a '
          'contractual requirement and you are under no obligation to give '
          'it; the only consequence of not doing so is that there is no '
          'spot to hold, and the rest of the site works either way. You '
          'can withdraw the consent at any time, which does not affect '
          'what happened before.',
        ),
      ]),
      li([
        strong([.text('Abuse limits and server logs')]),
        .text(
          ": the IP check on the form and the hosting provider's "
          'short-lived request logs. Basis: our legitimate interest in '
          'keeping the site and the list working (Art. 6 (1) (f) GDPR).',
        ),
      ]),
      li([
        strong([.text('Visit counts')]),
        .text(
          ': how many people visit and sign up, per page and per link. '
          'Basis: our legitimate interest in knowing whether the site works '
          '(Art. 6 (1) (f) GDPR). The counting stores nothing on your '
          'device and reads nothing from it, so no consent under § 25 '
          'TDDDG is needed and there is no cookie banner.',
        ),
      ]),
      li([
        strong([.text('Email you send us')]),
        .text(
          ': if you write to us, your message and address are kept for as '
          'long as it takes to answer, and afterwards only where the law '
          'requires it (Art. 6 (1) (b) and (f) GDPR).',
        ),
      ]),
    ]),

    h2(id: 'processors', [.text('Who handles it')]),
    p([
      .text(
        'Four providers process data for us under data processing '
        "agreements (Art. 28 GDPR). Where a provider's parent company sits "
        'outside the EU, the transfer rests on the EU standard contractual '
        'clauses (Art. 46 GDPR).',
      ),
    ]),
    ul([
      li([
        strong([.text('Supabase')]),
        .text(
          ' stores the waitlist in a Postgres database in Frankfurt, '
          'Germany (EU).',
        ),
      ]),
      li([
        strong([.text('Resend')]),
        .text(
          ' sends two emails from servers in the EU: the one asking you to '
          'confirm your address, and later the one that tells you your spot '
          'is open.',
        ),
      ]),
      li([
        strong([.text('Vercel')]),
        .text(
          ' serves the site from its edge network and keeps ordinary '
          'request logs for a short time.',
        ),
      ]),
      li([
        strong([.text('PostHog')]),
        .text(
          ' counts visits and waitlist sign-ups on servers in the EU, '
          'without cookies or any identifier stored in your browser: visits '
          'are grouped by a hash that changes daily, and your IP address is '
          'discarded before anything is kept. It sees which page you '
          'viewed and where the link came from, never your email address.',
        ),
      ]),
    ]),
    p([
      .text(
        'The fonts, icons and images are served from this site itself, not '
        'from Google or any other third party; the only outside script is '
        "PostHog's, loaded from its EU servers. No cookies, no tracking "
        'pixels and nothing stored in your browser are used on this site.',
      ),
    ]),

    h2(id: 'retention', [.text('For how long')]),
    p([
      .text(
        'Your address stays on the list until early access is over or you '
        'ask for it to be removed, whichever comes first; unconfirmed, it '
        'is gone after a week. The IP address is '
        'gone after a day. Request logs are gone after a short time. Visit '
        'counts are aggregated and cannot be traced back to you.',
      ),
    ]),
    p([
      .text(
        'An account in the app is a different thing from this list, and it '
        'is deleted whenever you say so: in the app under More → Delete '
        'account, or, if you no longer have the app, on ',
      ),
      a(href: '/delete-account', [.text('the deletion page')]),
      .text(
        '. Deleting removes the account, every journal entry and session '
        'in it, and the address itself from the live database immediately. '
        'Routine encrypted backups of the database may still hold a copy '
        'until they age out of the provider’s retention window; they '
        'are only ever used to recover from a failure, never to restore a '
        'deleted account.',
      ),
    ]),

    h2(id: 'security', [.text('Keeping it safe')]),
    p([
      .text(
        'The site is served over an encrypted HTTPS connection and makes no '
        'unencrypted one. The waitlist sits in a Postgres database that only '
        'the site’s own server can reach, never the browser. If a breach '
        'ever did put your address at risk, the supervisory authority named '
        'below is told within 72 hours of us becoming aware of it '
        '(Art. 33 GDPR), and you are told directly where the risk to you is '
        'high (Art. 34 GDPR).',
      ),
    ]),

    h2(id: 'rights', [.text('Your rights')]),
    p([
      .text(
        'You can ask what is stored about you, have it corrected or '
        'deleted, have its processing restricted, receive it in a portable '
        'form, object to processing based on legitimate interest, or '
        'withdraw your consent at any time by writing to ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. You also have the right to complain to a data protection '
        'authority. The one responsible for us is Der Landesbeauftragte für '
        'den Datenschutz und die Informationsfreiheit Baden-Württemberg, '
        'Lautenschlagerstraße 20, 70173 Stuttgart, poststelle@lfdi.bwl.de.',
      ),
    ]),

    h2(id: 'changes', [.text('Changes to this notice')]),
    p([
      .text(
        'Changes are published here with a new date at the top, and every '
        'version of this page is in the public repository, so what changed '
        'and when is a matter of record. If something material changes about '
        'what happens to your address, you are told by email before it takes '
        'effect rather than being left to notice it here.',
      ),
    ]),

    h2(id: 'responsible', [.text('Responsible')]),
    p([
      .text('Peter Trost, Yalovastr. 5, 72108 Rottenburg am Neckar, Germany, '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. Sole controller, answering privacy questions personally; there is '
        'no company, no co-controller and no data protection officer, since '
        'none of the Art. 37 GDPR triggers applies to a waitlist this size. '
        'See the imprint.',
      ),
    ]),
  ]);
}
