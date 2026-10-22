import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_shell.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/privacy`: the German translation of `Privacy`, the notice for the
/// web site and its waitlist (#253).
///
/// A translation, not a second text: every claim of the English notice and
/// nothing else, under the same section ids. A change to one is made to
/// both in the same pull request; `test/pages_test.dart` holds each to the
/// same claims and `test/site_test.dart` to the same shape.
///
/// It says "du" and uses `CONTEXT.md`'s German terms: a privacy notice is a
/// „Datenschutzerklärung“, never „Datenschutzhinweise“; a session is a
/// „Session“; an entry is a „Eintrag“.
class const PrivacyDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    h1([.text('Datenschutzerklärung')]),
    p([
      .text('Diese Seite gilt für getemotely.com, die Website. Die App hat '),
      PageLink('/app-privacy', 'eigene Datenschutzerklärung', locale: .de),
      .text('. Zuletzt aktualisiert am 3. Oktober 2026.'),
    ]),

    h2(id: 'stores', [.text('Was die Website speichert')]),
    p([
      .text(
        'Nichts, solange du dich nicht auf die Warteliste einträgst. Dann '
        'speichert sie die E-Mail-Adresse, die du eingegeben hast, den '
        'Zeitpunkt, zu dem du sie abgeschickt hast, einen Herkunftsvermerk '
        '(„source“: die Kampagnen-Tags im Link, über den du gekommen bist, '
        'oder die Website, die hierher verlinkt hat), die Sprache der Seite, '
        'auf der du dich eingetragen hast (Englisch oder Deutsch, damit die '
        'Bestätigungs-E-Mail in ihr kommt), ein zufälliges Token, '
        'das der Bestätigungslink trägt, und die IP-Adresse der Anfrage. Die '
        'IP-Adresse dient nur dazu, Missbrauch des Formulars zu begrenzen: '
        'Sie wird nach einem Tag gelöscht, bevor sie mit irgendetwas '
        'verknüpft werden könnte. Eine Adresse, deren Bestätigungslink nie '
        'angeklickt wird, wird nach einer Woche gelöscht.',
      ),
    ]),

    h2(id: 'basis', [.text('Warum, und auf welcher Rechtsgrundlage')]),
    ul([
      li([
        strong([.text('Deine Adresse')]),
        .text(
          ' wird gespeichert, damit wir dir sagen können, wann der frühe '
          'Zugang für dich öffnet. Rechtsgrundlage: deine Einwilligung (Art. '
          '6 Abs. 1 lit. a DSGVO), die du mit dem Absenden des Formulars '
          'gibst. Die Adresse anzugeben ist weder gesetzlich noch vertraglich '
          'vorgeschrieben, und du bist nicht verpflichtet, sie anzugeben; '
          'die einzige Folge, wenn du es nicht tust, ist, dass es keinen '
          'Platz gibt, den wir dir freihalten, und der Rest der Website '
          'funktioniert so oder so. Du kannst die Einwilligung jederzeit '
          'widerrufen; das berührt nicht, was vorher geschah.',
        ),
      ]),
      li([
        strong([.text('Missbrauchsgrenzen und Serverprotokolle')]),
        .text(
          ': die IP-Prüfung am Formular und die kurzlebigen '
          'Anfrageprotokolle des Hosting-Anbieters. Rechtsgrundlage: unser '
          'berechtigtes Interesse, die Website und die Liste funktionsfähig '
          'zu halten (Art. 6 Abs. 1 lit. f DSGVO).',
        ),
      ]),
      li([
        strong([.text('Die Prüfung auf der Löschseite')]),
        .text(
          ': nur auf der Löschseite, und dort erst, sobald du einen Code '
          'anforderst, prüft Cloudflare Turnstile im Hintergrund, dass ein '
          'Mensch und kein Skript fragt, bevor ein Code verschickt wird. '
          'Rechtsgrundlage: unser berechtigtes Interesse, Skripte davon '
          'abzuhalten, Fremden Codes zu schicken und die Anmelde-E-Mails '
          'aufzubrauchen, auf die alle echten Nutzer angewiesen sind (Art. 6 '
          'Abs. 1 lit. f DSGVO). Was die Prüfung in deinem Browser liest, ist '
          'für die Löschung, um die du gebeten hast, unbedingt erforderlich '
          'und braucht daher keine Einwilligung (§ 25 Abs. 2 Nr. 2 TDDDG).',
        ),
      ]),
      li([
        strong([.text('Besuchszählung')]),
        .text(
          ': wie viele Menschen die Website besuchen und sich eintragen, pro '
          'Seite und pro Link. Rechtsgrundlage: unser berechtigtes Interesse '
          'zu wissen, ob die Website funktioniert (Art. 6 Abs. 1 lit. f '
          'DSGVO). Die Zählung speichert nichts auf deinem Gerät und liest '
          'nichts von dort aus, daher ist keine Einwilligung nach § 25 TDDDG '
          'nötig, und es gibt kein Cookie-Banner.',
        ),
      ]),
      li([
        strong([.text('E-Mails, die du uns schickst')]),
        .text(
          ': Wenn du uns schreibst, werden deine Nachricht und deine Adresse '
          'so lange aufbewahrt, wie es dauert, sie zu beantworten, und '
          'danach nur, wo das Gesetz es verlangt (Art. 6 Abs. 1 lit. b und f '
          'DSGVO).',
        ),
      ]),
    ]),

    h2(id: 'processors', [.text('Wer die Daten verarbeitet')]),
    p([
      .text(
        'Fünf Anbieter verarbeiten Daten für uns nach '
        'Auftragsverarbeitungsverträgen (Art. 28 DSGVO). Wo die '
        'Muttergesellschaft eines Anbieters außerhalb der EU sitzt, stützt '
        'sich die Übermittlung auf die Standardvertragsklauseln der EU (Art. '
        '46 DSGVO).',
      ),
    ]),
    ul([
      li([
        strong([.text('Supabase')]),
        .text(
          ' speichert die Warteliste in einer Postgres-Datenbank in '
          'Frankfurt, Deutschland (EU).',
        ),
      ]),
      li([
        strong([.text('Resend')]),
        .text(
          ' verschickt von Servern in der EU zwei E-Mails: die, in der du '
          'deine Adresse bestätigen sollst, und später die, die dir sagt, '
          'dass dein Platz frei ist.',
        ),
      ]),
      li([
        strong([.text('Vercel')]),
        .text(
          ' liefert die Website über sein Edge-Netzwerk aus und bewahrt '
          'gewöhnliche Anfrageprotokolle für kurze Zeit auf.',
        ),
      ]),
      li([
        strong([.text('PostHog')]),
        .text(
          ' zählt Besuche und Eintragungen in die Warteliste auf Servern in '
          'der EU, ohne Cookies und ohne eine in deinem Browser gespeicherte '
          'Kennung: Besuche werden über einen Hash gruppiert, der sich '
          'täglich ändert, und deine IP-Adresse wird verworfen, bevor '
          'irgendetwas gespeichert wird. PostHog sieht, welche Seite du '
          'aufgerufen hast und woher der Link kam, nie deine E-Mail-Adresse.',
        ),
      ]),
      li([
        strong([.text('Cloudflare')]),
        .text(
          ' führt die Prüfung auf der Löschseite durch (Turnstile). Es liest, '
          'was es braucht, um einen Menschen von einem Skript zu '
          'unterscheiden – deine IP-Adresse, den TLS-Fingerabdruck und den '
          'User-Agent deines Browsers und welche Website fragt –, und '
          'antwortet mit einem Einmal-Token, das unser Anmeldesystem bei '
          'Cloudflare bestätigt. Cloudflare nutzt diese Signale außerdem als '
          'eigener Verantwortlicher, um seine Bot-Erkennung zu verbessern, '
          'wie es sein ',
        ),
        a(href: 'https://www.cloudflare.com/turnstile-privacy-policy/', [
          .text('Turnstile-Datenschutzzusatz'),
        ]),
        .text(' beschreibt. Deine E-Mail-Adresse sieht es nie.'),
      ]),
    ]),
    p([
      .text(
        'Die Schriften, Icons und Bilder werden von dieser Website selbst '
        'ausgeliefert, nicht von Google oder einem anderen Dritten. Zwei '
        'fremde Skripte werden geladen: das von PostHog, von dessen Servern '
        'in der EU, und das von Cloudflare, nur auf der Löschseite, sobald '
        'du einen Code anforderst. Die Website selbst setzt keine Cookies '
        'und verwendet keine Tracking-Pixel; gespeichert werden kann in '
        'deinem Browser nur, was die Prüfung von Cloudflare dort braucht, '
        'auf der Löschseite.',
      ),
    ]),

    h2(id: 'retention', [.text('Wie lange')]),
    p([
      .text(
        'Deine Adresse bleibt auf der Liste, bis der frühe Zugang vorbei ist '
        'oder du verlangst, dass sie entfernt wird, je nachdem, was zuerst '
        'eintritt; unbestätigt ist sie nach einer Woche weg. Die IP-Adresse '
        'ist nach einem Tag weg. Anfrageprotokolle sind nach kurzer Zeit '
        'weg. Besuchszählungen sind zusammengefasst und lassen sich nicht '
        'auf dich zurückführen. Das Token aus der Prüfung auf der Löschseite '
        'ist nach wenigen Minuten verbraucht, und was Cloudflare von einer '
        'Prüfung behält, behält es so, wie sein Zusatz es beschreibt.',
      ),
    ]),
    p([
      .text(
        'Ein Konto in der App ist etwas anderes als diese Liste, und es wird '
        'gelöscht, wann immer du das willst: in der App unter Mehr → Konto '
        'löschen oder, wenn du die App nicht mehr hast, auf ',
      ),
      PageLink('/delete-account', 'der Löschseite', locale: .de),
      .text(
        '. Das Löschen entfernt das Konto, jeden Eintrag und jede Session '
        'darin und die Adresse selbst sofort aus der Live-Datenbank. '
        'Routinemäßige verschlüsselte Backups der Datenbank können noch eine '
        'Kopie enthalten, bis sie aus dem Aufbewahrungsfenster des Anbieters '
        'herausfallen; sie werden nur genutzt, um nach einem Ausfall '
        'wiederherzustellen, nie, um ein gelöschtes Konto zurückzuholen.',
      ),
    ]),

    h2(id: 'security', [.text('Wie die Daten geschützt sind')]),
    p([
      .text(
        'Die Website wird über eine verschlüsselte HTTPS-Verbindung '
        'ausgeliefert und baut keine unverschlüsselte auf. Die Warteliste '
        'liegt in einer Postgres-Datenbank. Ein Browser kann dort eine '
        'Adresse eintragen und eine Adresse mit ihrem Bestätigungslink '
        'bestätigen, sonst nichts: Die Liste selbst lässt sich von einem '
        'Browser aus nie lesen. Sollte eine Datenpanne deine '
        'Adresse je gefährden, wird die unten genannte Aufsichtsbehörde '
        'innerhalb von 72 Stunden benachrichtigt, nachdem uns die Verletzung '
        'bekannt geworden ist (Art. 33 DSGVO), und du wirst direkt '
        'benachrichtigt, wo das Risiko für dich hoch ist (Art. 34 DSGVO).',
      ),
    ]),

    h2(id: 'rights', [.text('Deine Rechte')]),
    p([
      .text(
        'Du kannst Auskunft darüber verlangen, was über dich gespeichert ist, '
        'es berichtigen oder löschen lassen, seine Verarbeitung einschränken '
        'lassen, es in einem übertragbaren Format erhalten, einer '
        'Verarbeitung auf Grundlage berechtigter Interessen widersprechen '
        'oder deine Einwilligung jederzeit widerrufen, indem du an ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        ' schreibst. Du hast außerdem das Recht, dich bei einer '
        'Datenschutzaufsichtsbehörde zu beschweren. Für uns zuständig ist '
        'der Landesbeauftragte für den Datenschutz und die '
        'Informationsfreiheit Baden-Württemberg, Lautenschlagerstraße 20, '
        '70173 Stuttgart, poststelle@lfdi.bwl.de.',
      ),
    ]),

    h2(id: 'changes', [.text('Änderungen dieser Datenschutzerklärung')]),
    p([
      .text(
        'Änderungen werden hier mit neuem Datum oben veröffentlicht, und '
        'jede Fassung dieser Seite liegt im öffentlichen Repository, sodass '
        'nachvollziehbar bleibt, was sich wann geändert hat. Ändert sich '
        'etwas Wesentliches daran, was mit deiner Adresse geschieht, '
        'erfährst du es per E-Mail, bevor es wirksam wird, statt es hier '
        'selbst bemerken zu müssen.',
      ),
    ]),

    h2(id: 'responsible', [.text('Verantwortlich')]),
    p([
      .text(
        'Peter Trost, Yalovastr. 5, 72108 Rottenburg am Neckar, '
        'Deutschland, ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. Alleiniger Verantwortlicher, der Datenschutzfragen persönlich '
        'beantwortet; es gibt kein Unternehmen, keinen gemeinsam '
        'Verantwortlichen und keinen Datenschutzbeauftragten, da keiner der '
        'Auslöser des Art. 37 DSGVO auf eine Warteliste dieser Größe '
        'zutrifft. Siehe Impressum.',
      ),
    ]),
  ]);
}
