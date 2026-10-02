import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The imprint German law requires of any business web site (§ 5 DDG).
class const Imprint({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Imprint')]),
    p([.text('Information according to § 5 DDG (Germany).')]),
    p([
      .text('Peter Trost'),
      br(),
      .text('Yalovastr. 5'),
      br(),
      .text('72108 Rottenburg am Neckar'),
      br(),
      .text('Germany'),
    ]),
    p([
      .text('Email: '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
    ]),
    p([.text('VAT ID (USt-IdNr. according to § 27a UStG): DE369514299')]),
    p([.text('Responsible for content: Peter Trost, address as above.')]),
    h2([.text('Source code')]),
    p([
      .text('emotely is open source under the MIT license: '),
      a(href: repositoryUrl, [.text(repositoryUrl)]),
    ]),
  ]);
}
