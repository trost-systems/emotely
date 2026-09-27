import 'package:emotely_web/components/delete_account_form.dart';
import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/delete-account`: how to delete an emotely account, both ways.
///
/// Google Play's account-deletion policy asks for a web page that works for
/// people who have already uninstalled the app, which the in-app path
/// cannot serve. The in-app route comes first because it is the shorter one
/// for anyone still holding the app; the form below is for everyone else.
class const DeleteAccount({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Delete your account')]),
    // Google asks the deletion resource to name the app and the developer
    // as they appear on the store listing. The Play record still carries
    // the legacy title until the first new version ships (ADR 0012), so
    // both names are given rather than only the one we use here.
    p(classes: 'delete-account-identity', [
      .text(
        'This page is for emotely (listed on Google Play as '
        '"Reflect Therapy AI: emotely"), by Peter Trost.',
      ),
    ]),
    p([
      .text(
        'Deleting is immediate: the account, every journal entry and '
        'session in it, and the email address itself are removed from the '
        'live database as soon as you confirm. There is no grace period '
        'and no archive to ask for afterwards.',
      ),
    ]),

    h2([.text('If you still have the app')]),
    p([
      .text(
        'This is the quickest way, and it needs no code: open emotely and '
        'go to ',
      ),
      strong([.text('More → Your account → Delete account')]),
      .text(', then confirm. The app signs you out as it finishes.'),
    ]),

    h2([.text('If you no longer have the app')]),
    p([
      .text(
        'Use the form below. It sends a six-digit code to your address to '
        'be sure the request comes from you — the same check the app makes '
        'when you sign in — and deletes the account once you type the code '
        'back in. It creates nothing: an address without an emotely '
        'account stays without one.',
      ),
    ]),
    DeleteAccountForm(),

    h2([.text('What gets deleted')]),
    ul([
      li([
        .text(
          'Your sign-in account, the email address on it and your profile '
          '(the name the app calls you).',
        ),
      ]),
      li([
        .text(
          'Every journal entry: the summaries, your answers and the '
          'questions as they were asked.',
        ),
      ]),
      li([
        .text(
          'Every session, finished or half-finished, and the transcript in '
          'it.',
        ),
      ]),
    ]),
    p([
      .text(
        'Journal content lives in one database and nowhere else — it is '
        'never sent to an analytics provider — so deleting the account '
        'deletes it everywhere it was stored.',
      ),
    ]),

    h2([.text('What is not deleted')]),
    p([
      .text(
        'Two things outlive the account, and neither contains your journal '
        'or your address.',
      ),
    ]),
    ul([
      li([
        strong([.text('Counting.')]),
        .text(
          ' The site and the app count things like how many people opened '
          'a page or finished a session. These records are pseudonymous '
          'rather than anonymous: the site groups visits by a hash that '
          'changes every day and never reaches your browser, and the app '
          'counts events against a random account identifier that carries '
          'no journal text and no email address. Deleting the account '
          'breaks the link between that identifier and you, but the counts '
          'themselves remain.',
        ),
      ]),
      li([
        strong([.text('Backups.')]),
        .text(
          ' Deletion takes effect in the live database immediately. '
          'Routine encrypted backups of the database as a whole may still '
          'hold a copy until they age out of the provider’s retention '
          'window, and they are never used to bring a deleted account '
          'back — only to recover the database after a failure.',
        ),
      ]),
    ]),
    p([
      .text(
        'If you also joined the waitlist with the same address, that is a '
        'separate list and the deletion above does not touch it; write to ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(' and it is removed too.'),
    ]),

    h2([.text('If something goes wrong')]),
    p([
      .text('Write to '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        ' from the address on the account and we will delete it by hand. '
        'You can also read exactly what the deletion does in the ',
      ),
      a(href: '$repositoryUrl/blob/main/supabase/migrations', [
        .text('database migrations'),
      ]),
      .text(' — the site and the app are open source.'),
    ]),
  ]);
}
