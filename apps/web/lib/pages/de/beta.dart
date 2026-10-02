import 'package:emotely_web/beta_links.dart';
import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_shell.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/beta`: the German translation of `Beta`, unlisted like it: nothing
/// but the English beta page's language switch links here, the sitemap
/// leaves it out (`--sitemap-exclude`), and it asks crawlers to stay away.
class const BetaDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    Document.head(
      meta: {
        'robots': 'noindex, nofollow',
        'description':
            'Installiere die emotely-Beta auf dem iPhone oder unter Android. '
            'Nur mit Einladung.',
      },
    ),
    h1([.text('emotely-Beta')]),
    p([
      .text(
        'Du wurdest eingeladen, emotely vor dem Start zu testen. '
        'Installationen gibt es nur mit Einladung, deshalb bitten wir dich, '
        'diese Seite nicht weiterzugeben – jede Einladung, die wir '
        'verschicken, gehört zu einer Person, die testet.',
      ),
    ]),

    h2([.text('iPhone')]),
    p([
      a(href: testFlightJoinUrl, classes: 'cta', [
        .text('Bei TestFlight mitmachen'),
      ]),
    ]),
    ol(classes: 'steps', [
      li([
        .text(
          'Installiere Apples kostenlose TestFlight-App aus dem App Store.',
        ),
      ]),
      li([
        .text(
          'Öffne den Link oben auf dem iPhone, auf dem du Tagebuch schreiben '
          'willst. TestFlight übernimmt den Rest.',
        ),
      ]),
    ]),

    h2([.text('Android')]),
    p([
      a(href: playTestingUrl, classes: 'cta', [
        .text('Bei Google Play mitmachen'),
      ]),
    ]),
    p([
      .text(
        'Der Test ist auf das Google-Konto beschränkt, das wir eingeladen '
        'haben, also öffne den Link mit diesem Konto. Ist auf dem Handy ein '
        'anderes Konto angemeldet, antworte auf die Einladung mit der '
        'Adresse, die du nutzen möchtest, und wir fügen sie hinzu.',
      ),
    ]),

    h2([.text('Was dich erwartet')]),
    ul(classes: 'stack', [
      li([
        .text(
          'Das ist eine Beta, also kann etwas kaputtgehen. Genau danach '
          'suchen wir.',
        ),
      ]),
      li([
        .text(
          'Ab und zu kommt ein neuer Build, mit Korrekturen für das, was '
          'Testende gefunden haben. Installiere ihn, wenn TestFlight oder '
          'Play ihn anbieten: Ein alter Build kann dich bitten, zu '
          'aktualisieren, bevor du weiter Tagebuch schreiben kannst.',
        ),
      ]),
      li([
        .text('Deine Einträge bleiben privat, genau wie in der '),
        PageLink('/app-privacy', 'Datenschutzerklärung der App', locale: .de),
        .text(' beschrieben.'),
      ]),
      li([
        .text(
          'Die App stellt gelegentlich eine kurze Umfrage. Die Antwort ist '
          'freiwillig.',
        ),
      ]),
    ]),

    h2([.text('Feedback')]),
    p([
      .text('Nutze '),
      strong([.text('Feedback senden')]),
      .text(' im Tab „Mehr“ der App, oder schreib an '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. Bei einem Fehler hilft die App-Version am meisten – die '
        'Feedback-Zeile trägt sie für dich ein.',
      ),
    ]),
  ]);
}
