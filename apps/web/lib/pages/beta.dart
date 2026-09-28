import 'package:emotely_web/beta_links.dart';
import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/beta`: the one link an invitation mail carries, holding both store
/// links so a tester never has to be told which one applies to their phone.
///
/// The page is unlisted, not secret. Nothing links to it — not the header,
/// not the footer, not the sitemap (`--sitemap-exclude` in the build) — and
/// it asks crawlers to keep it out of the index. robots.txt is deliberately
/// left alone: a `Disallow: /beta` line would publish the path to anyone who
/// reads it, which is the opposite of what an unlisted page wants.
class const Beta({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    // A crawler that reaches this URL anyway — from a forwarded mail, a
    // pasted link, a referrer header — gets its only instruction here.
    Document.head(
      meta: {
        'robots': 'noindex, nofollow',
        'description':
            'Install the emotely beta on iPhone or Android. Invitation only.',
      },
    ),
    h1([.text('emotely beta')]),
    p([
      .text(
        'You were invited to test emotely before it launches. Installs are '
        'by invitation only, so we ask you not to share this page — every '
        'invitation we send out is tied to one tester.',
      ),
    ]),

    h2([.text('iPhone')]),
    p([
      a(href: testFlightJoinUrl, classes: 'cta', [.text('Join on TestFlight')]),
    ]),
    ol(classes: 'steps', [
      li([.text('Install Apple’s free TestFlight app from the App Store.')]),
      li([
        .text(
          'Open the link above on the iPhone you want to journal on. '
          'TestFlight takes it from there.',
        ),
      ]),
    ]),

    h2([.text('Android')]),
    p([
      a(href: playTestingUrl, classes: 'cta', [.text('Join on Google Play')]),
    ]),
    p([
      .text(
        'The test is limited to the Google account we invited, so open the '
        'link with that account. If a different account is signed in on the '
        'phone, reply to the invitation with the address you want to use '
        'and we will add it.',
      ),
    ]),

    h2([.text('What to expect')]),
    ul(classes: 'stack', [
      li([
        .text(
          'This is a beta, so things may break. That is what we are looking '
          'for.',
        ),
      ]),
      li([
        .text(
          'A new build arrives every so often, with fixes for what testers '
          'found. Install it when TestFlight or Play offers it: an old '
          'build may ask you to update before it lets you journal.',
        ),
      ]),
      li([
        .text('Your entries stay private, exactly as described in the '),
        a(href: '/app-privacy', [.text('app privacy notice')]),
        .text('.'),
      ]),
      li([
        .text(
          'The app occasionally asks a short survey. Answering is optional.',
        ),
      ]),
    ]),

    h2([.text('Feedback')]),
    p([
      .text('Use '),
      strong([.text('Send feedback')]),
      .text(' on the More tab of the app, or write to '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. For a bug, the app version helps most — the feedback row fills '
        'it in for you.',
      ),
    ]),
  ]);
}
