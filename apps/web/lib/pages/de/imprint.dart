import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/imprint`: the German imprint, a translation of `Imprint` claim for
/// claim (§ 5 DDG).
class const ImprintDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Impressum')]),
    p([.text('Angaben gemäß § 5 DDG (Deutschland).')]),
    p([
      .text('Peter Trost'),
      br(),
      .text('Yalovastr. 5'),
      br(),
      .text('72108 Rottenburg am Neckar'),
      br(),
      .text('Deutschland'),
    ]),
    p([
      .text('E-Mail: '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
    ]),
    p([
      .text(
        'Umsatzsteuer-Identifikationsnummer (USt-IdNr.) gemäß § 27a UStG: '
        'DE369514299',
      ),
    ]),
    p([
      .text('Verantwortlich für den Inhalt: Peter Trost, Anschrift wie oben.'),
    ]),
    h2([.text('Quellcode')]),
    p([
      .text('emotely ist Open Source unter der MIT-Lizenz: '),
      a(href: repositoryUrl, [.text(repositoryUrl)]),
    ]),
  ]);
}
