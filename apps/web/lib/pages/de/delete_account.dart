import 'package:emotely_web/components/delete_account_form.dart';
import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/delete-account`: the German translation of `DeleteAccount`, claim
/// for claim, under the same headings. Google Play's deletion resource
/// requirement applies in every language the listing is shown in.
class const DeleteAccountDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Dein Konto löschen')]),
    p(classes: 'delete-account-identity', [
      .text(
        'Diese Seite gehört zu emotely (bei Google Play als '
        '„Reflect Therapy AI: emotely“ gelistet), von Peter Trost.',
      ),
    ]),
    p([
      .text(
        'Das Löschen geht sofort: Das Konto, jeder Tagebucheintrag und jede '
        'Session darin und die E-Mail-Adresse selbst werden aus der '
        'Live-Datenbank entfernt, sobald du bestätigst. Es gibt keine '
        'Karenzzeit und kein Archiv, das du danach anfordern könntest.',
      ),
    ]),

    h2([.text('Wenn du die App noch hast')]),
    p([
      .text(
        'Das ist der schnellste Weg, und er braucht keinen Code: Öffne '
        'emotely und geh zu ',
      ),
      strong([.text('Mehr → Konto löschen')]),
      .text(', dann bestätige. Die App meldet dich ab, sobald sie fertig ist.'),
    ]),

    h2([.text('Wenn du die App nicht mehr hast')]),
    p([
      .text(
        'Nutze das Formular unten. Es schickt einen sechsstelligen Code an '
        'deine Adresse, um sicherzugehen, dass die Anfrage von dir kommt – '
        'dieselbe Prüfung wie bei der Anmeldung in der App –, und löscht das '
        'Konto, sobald du den Code eingibst. Es legt nichts an: Eine Adresse '
        'ohne emotely-Konto bleibt ohne.',
      ),
    ]),
    DeleteAccountForm(lang: 'de'),

    h2([.text('Was gelöscht wird')]),
    ul([
      li([
        .text(
          'Dein Anmeldekonto, die E-Mail-Adresse darauf und dein Profil (der '
          'Name, mit dem die App dich anspricht).',
        ),
      ]),
      li([
        .text(
          'Jeder Tagebucheintrag: die Zusammenfassungen, deine Antworten und '
          'die Fragen, wie sie gestellt wurden.',
        ),
      ]),
      li([
        .text(
          'Jede Session, abgeschlossen oder halb fertig, und das Transkript '
          'darin.',
        ),
      ]),
    ]),
    p([
      .text(
        'Tagebuchinhalte liegen in einer Datenbank und nirgendwo sonst – sie '
        'werden nie an einen Analyseanbieter gesendet –, deshalb löscht das '
        'Löschen des Kontos sie überall, wo sie gespeichert waren.',
      ),
    ]),

    h2([.text('Was nicht gelöscht wird')]),
    p([
      .text(
        'Zwei Dinge überdauern das Konto, und keines davon enthält dein '
        'Tagebuch oder deine Adresse.',
      ),
    ]),
    ul([
      li([
        strong([.text('Zählungen.')]),
        .text(
          ' Die Website und die App zählen Dinge wie, wie viele Leute eine '
          'Seite geöffnet oder eine Session abgeschlossen haben. Diese '
          'Datensätze sind pseudonym statt anonym: Die Website fasst Besuche '
          'über einen Hash zusammen, der sich jeden Tag ändert und nie deinen '
          'Browser erreicht, und die App zählt Ereignisse gegen eine zufällige '
          'Kontokennung, die keinen Tagebuchtext und keine E-Mail-Adresse '
          'enthält. Das Löschen des Kontos trennt die Verbindung zwischen '
          'dieser Kennung und dir, aber die Zählungen selbst bleiben.',
        ),
      ]),
      li([
        strong([.text('Backups.')]),
        .text(
          ' Die Löschung wirkt in der Live-Datenbank sofort. Routinemäßige '
          'verschlüsselte Backups der gesamten Datenbank können noch eine '
          'Kopie enthalten, bis sie aus dem Aufbewahrungsfenster des '
          'Anbieters herausfallen, und sie werden nie genutzt, um ein '
          'gelöschtes Konto zurückzuholen – nur, um die Datenbank nach einem '
          'Ausfall wiederherzustellen.',
        ),
      ]),
    ]),
    p([
      .text(
        'Hast du dich mit derselben Adresse auch auf die Warteliste gesetzt, '
        'ist das eine eigene Liste, und die Löschung oben berührt sie nicht; '
        'schreib an ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(', und du wirst auch von ihr entfernt.'),
    ]),

    h2([.text('Wenn etwas schiefgeht')]),
    p([
      .text('Schreib an '),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        ' von der Adresse des Kontos aus, und wir löschen es von Hand. Was '
        'die Löschung genau tut, kannst du auch in den ',
      ),
      a(href: '$repositoryUrl/blob/main/supabase/migrations', [
        .text('Datenbank-Migrationen'),
      ]),
      .text(' nachlesen – die Website und die App sind Open Source.'),
    ]),
  ]);
}
