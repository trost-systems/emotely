import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_shell.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de/app-privacy`: the German translation of `AppPrivacy`, where the
/// app's German consent and privacy screens link (#229).
///
/// A translation, not a second text: every claim of the English notice and
/// nothing else, under the same section ids, so a link to `#rights` lands
/// in the same place in either language. A change to one is made to both
/// in the same pull request; `test/pages_test.dart` holds each to the same
/// claims and `test/site_test.dart` to the same shape.
///
/// It says "du", like the app, and uses `CONTEXT.md`'s German terms: the
/// companion is "emotely", never "Assistent"; a session is "Session",
/// never "Sitzung"; an entry is "Eintrag".
class const AppPrivacyDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => const main_(classes: 'page prose', [
    Document.head(
      meta: {
        'description':
            'Wie die emotely-App Daten erhebt, nutzt und weitergibt: das '
            'Konto, dein Name, Tagebucheinträge, das KI-Gespräch, '
            'Nutzungsanalyse, Löschung und deine Rechte nach der DSGVO.',
      },
    ),
    h1([.text('Datenschutzerklärung der App')]),
    p([
      .text(
        'Diese Datenschutzerklärung gilt für die emotely-App für iOS und '
        'Android (bei Google Play als „Reflect Therapy AI: emotely“ '
        'gelistet). Für die Website getemotely.com und ihre Warteliste gibt '
        'es eine eigene Datenschutzerklärung. Zuletzt aktualisiert am 3. '
        'Oktober 2026.',
      ),
    ]),

    nav(classes: 'toc', [
      h2([.text('Auf dieser Seite')]),
      ul([
        li([
          a(href: '#responsible', [.text('Wer verantwortlich ist')]),
        ]),
        li([
          a(href: '#collects', [.text('Was die App erhebt, und warum')]),
        ]),
        li([
          a(href: '#recipients', [.text('Wer sonst etwas davon sieht')]),
        ]),
        li([
          a(href: '#deletion', [.text('Dein Konto löschen')]),
        ]),
        li([
          a(href: '#breach', [.text('Wenn etwas schiefgeht')]),
        ]),
        li([
          a(href: '#rights', [.text('Deine Rechte')]),
        ]),
        li([
          a(href: '#automated', [.text('Automatisierte Entscheidungen')]),
        ]),
        li([
          a(href: '#children', [.text('Kinder')]),
        ]),
        li([
          a(href: '#not-medical', [.text('Kein medizinisches Angebot')]),
        ]),
        li([
          a(href: '#web-site', [.text('Die Website')]),
        ]),
        li([
          a(href: '#changes', [
            .text('Änderungen dieser Datenschutzerklärung'),
          ]),
        ]),
      ]),
    ]),

    h2(id: 'responsible', [.text('Wer verantwortlich ist')]),
    p([
      .text(
        'Peter Trost, Yalovastr. 5, 72108 Rottenburg am Neckar, '
        'Deutschland, ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        '. Alleiniger Verantwortlicher für alles, was folgt; es gibt kein '
        'Unternehmen und keinen gemeinsam Verantwortlichen. Alle Angaben im ',
      ),
      PageLink('/imprint', 'Impressum', locale: .de),
      .text('.'),
    ]),

    h2(id: 'collects', [.text('Was die App erhebt, und warum')]),

    h3([.text('Deine E-Mail-Adresse')]),
    p([
      .text(
        'Zum Anmelden braucht es eine E-Mail-Adresse, auf einem von drei '
        'Wegen: deine Adresse und ein Passwort, das du wählst, oder „Mit '
        'Google anmelden“ (iOS und Android) bzw. „Mit Apple anmelden“ '
        '(iPhone), das bestätigt, wer du bist, und deine Adresse '
        'weitergibt. Ein neues Konto mit Passwort öffnet sich erst, wenn '
        'du den sechsstelligen Code eintippst, den die App an die Adresse '
        'schickt, und ein vergessenes Passwort setzt du mit so einem Code '
        'zurück (ein Code, nie ein Link). Wird das Passwort geändert, '
        'bekommt die Adresse eine Mail darüber, falls du es nicht warst. '
        'Supabase Auth speichert das '
        'Passwort nur als Einweg-Hash, nie so, wie du es getippt hast, '
        'sodass niemand es zurücklesen kann. Die Adresse, der Passwort-Hash '
        'und die Anmeldedaten liegen bei Supabase Auth auf Servern in '
        'Frankfurt, Deutschland (EU). Die App fragt nie nach einer '
        'Telefonnummer, einem '
        'Geburtsdatum, Kontakten, Fotos, deinem Standort oder einer '
        'Werbe-ID.',
      ),
    ]),
    p([
      .text(
        'Google und Apple geben außerdem eine Kennung deines Kontos bei '
        'ihnen weiter; daran findet die nächste Anmeldung dasselbe Konto '
        'wieder. Google fügt den Namen und den Link zum Profilbild deines '
        'Google-Kontos hinzu, und Supabase speichert beides mit den '
        'Anmeldedaten; die App nutzt sie nicht. Einen Namen übernimmt sie '
        'weder von Google noch von Apple – sie fragt dich (siehe unten). '
        'Apple kann ebenfalls einen Namen weitergeben, aber die App fordert '
        'ihn nicht an. Mit Apples „E-Mail-Adresse verbergen“ erhalten wir '
        'eine Weiterleitungsadresse, die an deine Adresse weiterleitet. Eine '
        'Adresse, die zu einem Konto passt, das du schon hast, führt dich in '
        'dieses Konto; eine Weiterleitungsadresse passt nie, sie legt also '
        'ein neues an. Dein Google- oder Apple-Passwort sehen wir nie. Der '
        'Anbieter erfährt, dass du dich bei emotely angemeldet hast – als '
        'eigenständiger Verantwortlicher, nach seiner eigenen '
        'Datenschutzerklärung – und nichts über dein Tagebuch.',
      ),
    ]),
    p([
      .text(
        'Bevor die App ein Konto anlegt, ein Passwort prüft oder einen Code '
        'anfordert, prüft Cloudflare Turnstile in einer verborgenen '
        'Web-Ansicht, dass ein Mensch und kein Skript fragt. Es liest, was '
        'es braucht, um beides zu unterscheiden – deine IP-Adresse, den '
        'TLS-Fingerabdruck und den User-Agent dieser Web-Ansicht und dass '
        'die Anfrage von emotely kommt –, und antwortet mit einem '
        'Einmal-Token, das Supabase bei Cloudflare bestätigt. Deine '
        'E-Mail-Adresse sieht es nie. Rechtsgrundlage: unser berechtigtes '
        'Interesse, Skripte davon abzuhalten, Fremden Codes zu schicken und '
        'die Anmelde-E-Mails aufzubrauchen, auf die alle echten Nutzer '
        'angewiesen sind (Art. 6 Abs. 1 lit. f DSGVO). „Mit Google '
        'anmelden“ und „Mit Apple anmelden“ brauchen keine solche Prüfung.',
      ),
    ]),
    p([
      .text(
        'Mit den Anmeldedaten speichert Supabase Auth außerdem die Sprache, '
        'in der die App angezeigt wird (Englisch oder Deutsch), damit die '
        'E-Mails mit deinen Codes in dieser Sprache kommen.',
      ),
    ]),
    p([
      .text(
        'Solange du angemeldet bist, trägt jede Anfrage an unseren eigenen '
        'Server dein Anmelde-Token, das deine Kontokennung und deine Adresse '
        'enthält. Es endet bei unserem Server und wird nie an das Gateway '
        'oder den Modellanbieter weitergegeben.',
      ),
    ]),
    p([
      .text(
        'Rechtsgrundlage: der Vertrag über den Dienst, den du nutzen '
        'möchtest (Art. 6 Abs. 1 lit. b DSGVO). Die Adresse anzugeben ist '
        'keine gesetzliche Pflicht, aber ohne sie gibt es kein Konto und '
        'damit nichts, in das du Tagebuch schreiben könntest. Gespeichert, '
        'bis du das Konto löschst.',
      ),
    ]),

    h3([.text('Dein Name')]),
    p([
      .text(
        'Die App fragt, wie sie dich nennen soll, normalerweise bevor du '
        'dich registrierst. Die Antwort ist freiwillig: Überspringst du, '
        'sucht sie einen Platzhalternamen aus und sagt dir das. Solange dein '
        'Konto noch nicht existiert, bleibt der Name auf deinem Handy; danach '
        'wandert er in dein Profil in derselben Supabase-Datenbank in '
        'Frankfurt, mit einem Vermerk, ob du ihn gewählt hast oder die App. '
        'Die App begrüßt dich damit, und emotely spricht dich damit an '
        '(siehe das Gespräch, unten). Ändern kannst du ihn jederzeit unter '
        'Profil, im Tab „Mehr“. Rechtsgrundlage: der personalisierte Dienst, '
        'den du nutzen möchtest (Art. 6 Abs. 1 lit. b DSGVO). Gespeichert, '
        'bis du das Konto löschst.',
      ),
    ]),

    h3([.text('Deine Tagebucheinträge und Sessions')]),
    p([
      .text(
        'Eine Session ist ein geführtes Gespräch: emotely stellt eine Frage, '
        'du antwortest, und am Ende schreibt emotely den Eintrag. Neben '
        'deinem Profil werden drei Arten von Datensätzen für dich '
        'gespeichert:',
      ),
    ]),
    ul([
      li([
        strong([.text('Sessions')]),
        .text(
          ' – das vollständige Transkript des Gesprächs, jede Frage und jede '
          'Antwort so, wie das Modell sie gesehen hat, dazu, wo du gerade '
          'stehst, welches Fragenset du gewählt hast, ob die Session '
          'abgeschlossen ist und welche App-Version sie geschrieben hat. So '
          'kann eine geschlossene oder abgestürzte App eine Session wieder '
          'aufnehmen.',
        ),
      ]),
      li([
        strong([.text('Einträge')]),
        .text(
          ' – der fertige Eintrag: die Zusammenfassung, die emotely '
          'geschrieben hat, deine Antworten und die Fragen, wie sie gestellt '
          'wurden.',
        ),
      ]),
      li([
        strong([.text('Einwilligungen')]),
        .text(
          ' – jedes Mal, wenn du eine Einwilligung erteilst oder widerrufst '
          '(in das Senden von Sessions an einen Modellanbieter und in die '
          'Nutzungsanalyse), wann, und welche Fassung des Wortlauts dir '
          'gezeigt wurde. Datensätze werden nur hinzugefügt, nie geändert. '
          'Der Wortlaut selbst wird nicht für jede Person kopiert; der '
          'Datensatz nennt seine Fassung.',
        ),
      ]),
    ]),
    p([
      .text(
        'All das liegt in einer Postgres-Datenbank bei Supabase in '
        'Frankfurt, Deutschland (EU), lesbar nur für dein Konto. Das '
        'erzwingt die Datenbank bei jeder Abfrage (Row-Level Security), '
        'nicht die App: Eine Abfrage nach den Zeilen eines anderen Menschen '
        'kommt leer zurück, egal wer sie schickt. Die Regeln stehen in den '
        'quelloffenen ',
      ),
      a(href: '$repositoryUrl/blob/main/supabase/migrations', [
        .text('Datenbank-Migrationen'),
      ]),
      .text(', und eine Testsuite belegt sie bei jeder Änderung.'),
    ]),
    p([
      strong([.text('Das sind sensible Daten, und sie werden so behandelt.')]),
      .text(
        ' Ein Eintrag kann sagen, wie du dich gefühlt oder wie du geschlafen '
        'hast, was eine Diagnose oder ein Medikament mit dir macht, wie es '
        'zwischen dir und einem nahestehenden Menschen steht oder woran du '
        'glaubst. Einträge können daher Gesundheitsdaten und andere '
        'besondere Kategorien nach Art. 9 DSGVO enthalten. Rechtsgrundlage '
        'ist deine ausdrückliche Einwilligung (Art. 9 Abs. 2 lit. a DSGVO), '
        'neben dem Vertrag (Art. 6 Abs. 1 lit. b DSGVO).',
      ),
    ]),
    p([
      .text(
        'Vor deiner ersten Session fragt die App nach dieser Einwilligung: '
        'Sie sagt, was gesendet wird, an wen und was es enthalten kann, und '
        'nichts wird gesendet, bevor du das Häkchen setzt und beginnst. '
        'Ablehnen ist eine echte Wahl – nichts wird gesendet, und deine '
        'bisherigen Einträge bleiben lesbar. Du kannst die Einwilligung '
        'jederzeit unter Mehr → Datenschutzeinstellungen widerrufen: ein '
        'Schalter, für den du nichts löschen musst und der nicht berührt, '
        'was vorher geschah. Der Widerruf ist so einfach wie die Erteilung '
        '(Art. 7 Abs. 3 DSGVO). Weil emotely deinen Eintrag schreibt, kann '
        'keine neue Session beginnen, solange die Einwilligung widerrufen '
        'ist; schaltest du sie wieder ein, siehst du noch einmal den '
        'vollständigen Einwilligungsbildschirm.',
      ),
    ]),
    p([
      .text(
        'Einträge werden gespeichert, bis du sie oder das Konto löschst. Sie '
        'laufen nicht automatisch ab: Ein Tagebuch, das still das letzte '
        'Jahr löscht, wäre kein Tagebuch.',
      ),
    ]),

    h3([.text('Das Gespräch mit emotely')]),
    p([
      .text(
        'Das ist der Teil, der dein Handy verlässt. Jede Runde einer Session '
        'schickt dem emotely-Agenten – einem kleinen Server von uns – das '
        'bisherige Transkript, den Namen, mit dem die App dich anspricht '
        '(deinen oder den Platzhalter), die Sprache, auf die die App '
        'eingestellt ist (damit die Fragen und dein Eintrag in dieser Sprache '
        'kommen), die App-Version, dein Anmelde-Token '
        'und eine Signatur, die belegt, dass der Server dieses Transkript '
        'selbst erzeugt hat. Der Agent fügt die Anweisungen für emotely '
        'hinzu und übergibt das Gespräch über das ',
      ),
      strong([.text('Vercel AI Gateway')]),
      .text(
        ' an ein Sprachmodell; das Gateway reicht es an den Anbieter weiter, '
        'der das Modell gerade bereitstellt. Das Gateway und der Anbieter '
        'erhalten das Gespräch, die Anweisungen, den Namen, mit dem die App '
        'dich anspricht, und die Sprache der App – keine E-Mail-Adresse und '
        'kein Anmelde-Token. '
        'Die Antwort kommt auf demselben Weg zurück und wird zur nächsten '
        'Frage oder zu deinem Eintrag.',
      ),
    ]),
    ul([
      li([
        strong([.text('Der Agent behält keine Kopie.')]),
        .text(
          ' Er hat keine Datenbank: Jede Anfrage trägt das ganze Transkript, '
          'wird beantwortet und vergessen, und nichts von dem Gesagten wird '
          'in ein Log geschrieben. Er schickt PostHog allerdings einen '
          'technischen Datensatz zu jeder Runde – wie lange sie gedauert hat, '
          'wie viele Tokens sie verbraucht hat, was sie gekostet hat, welche '
          'Fassung der Anweisungen lief –, wobei der Inhalt schon an der '
          'Quelle unterdrückt wird. Dieser Datensatz entsteht auf unserem '
          'Server, speichert nichts auf deinem Handy und gehört nicht zur '
          'Nutzungsanalyse, die du in der App wählst; so halten wir den '
          'Dienst am Laufen und seine Kosten im Griff (berechtigtes '
          'Interesse, Art. 6 Abs. 1 lit. f DSGVO).',
        ),
      ]),
      li([
        strong([.text('Wo er läuft.')]),
        .text(
          ' Der Agent läuft auf Vercels Servern in Frankfurt, Deutschland '
          '(EU), neben der Datenbank. Das Gateway und die Modellanbieter '
          'können außerhalb der EU sitzen; welcher Anbieter antwortet, und '
          'wo, hängt davon ab, wohin das Gateway in diesem Moment leitet. '
          'Diese Übermittlungen stützen sich auf die Standardvertragsklauseln '
          'der EU (Art. 46 DSGVO), bei den Anbietern außerdem auf die beiden '
          'Routing-Zusagen unten.',
        ),
      ]),
      li([
        strong([.text('Welches Modell.')]),
        .text(
          ' Derzeit openai/gpt-oss-120b, ein Modell mit offenen Gewichten, '
          'ausgewählt per Benchmark statt nach Marke. Es kann sich ohne neue '
          'App-Version ändern; die Voreinstellung steht im öffentlichen '
          'Repository, und diese Datenschutzerklärung nennt das Modell, das '
          'im Einsatz ist.',
        ),
      ]),
      li([
        strong([.text('Kein Trainingsmaterial, und nicht aufbewahrt.')]),
        .text(
          ' Vercel erklärt, dass das Gateway selbst Prompts und Antworten '
          'weder aufbewahrt noch damit trainiert. Für die Anbieter dahinter '
          'weist jede Runde das Gateway an, nur an Anbieter zu leiten, denen '
          'vertraglich untersagt ist, mit Prompts zu trainieren, und die an '
          'eine Vereinbarung ohne Datenaufbewahrung (Zero Data Retention) '
          'gebunden sind; auch bei ihnen wird das Transkript also nicht '
          'aufbewahrt. Das Gateway erzwingt beides bei jeder Anfrage, und '
          'beides schlägt sicher fehl (fail closed): Gibt es keinen passenden '
          'Anbieter, scheitert die Runde, statt auf einen Anbieter '
          'auszuweichen, der die Bedingungen nicht erfüllt. Geprüft am 15. '
          'September 2026 gegen das laufende Gateway: Alle acht Anbieter des '
          'aktuellen Modells erfüllten sie. Der Anbieter verarbeitet das '
          'Transkript trotzdem, um es zu beantworten.',
        ),
      ]),
    ]),
    p([
      .text(
        'Rechtsgrundlage: der Vertrag (Art. 6 Abs. 1 lit. b DSGVO) und, weil '
        'das Transkript die oben beschriebenen besonderen Kategorien von '
        'Daten enthalten kann, deine ausdrückliche Einwilligung (Art. 9 Abs. '
        '2 lit. a DSGVO). Vercel und der Modellanbieter sind unsere '
        'Auftragsverarbeiter (Art. 28 DSGVO). Das Gespräch mit emotely ist '
        'das Produkt: Es gibt keine Version davon, die deine Antworten nicht '
        'an ein Modell schickt, deshalb fragt die App vor der ersten Session '
        'und nicht danach.',
      ),
    ]),
    p([
      .text(
        'Ganz deutlich gesagt: Die Fragen, die dir gestellt werden, und der '
        'Eintrag, der geschrieben wird, werden von einem KI-System erzeugt, '
        'nicht von einem Menschen. Niemand liest mit, und am anderen Ende '
        'einer Session sitzt kein Mensch.',
      ),
    ]),

    h3([.text('Nutzungsanalyse und Absturzberichte')]),
    p([
      .text(
        'Wenn du es erlaubst, zählt die App, wie sie genutzt wird – '
        'Bildschirme, Antippen, Zeiten und Abstürze –, damit wir sehen, was '
        'funktioniert, und beheben können, was nicht funktioniert. Sie sendet '
        'nie, was du in dein Tagebuch schreibst, deinen Namen oder deine '
        'E-Mail-Adresse: Der Code, der berichtet, bekommt sie nie, und ein '
        'Test spielt eine ganze Session mit eingeschleustem Markierungstext '
        'durch, um zu belegen, dass nichts davon nach außen dringt. '
        'Absturzberichte behalten Typ, Code und Stack-Frames des Fehlers, '
        'verlieren aber seine Meldung, weil eine Meldung zitieren kann, '
        'woran sie gescheitert ist; durchgelassen werden nur Meldungen, deren '
        'Wortlaut wir selbst geschrieben haben, oder der Name eines Hosts. Es '
        'gibt keine Aufzeichnung deiner Nutzung (Session Replay) und keine '
        'Bildschirmaufnahme. Die Daten gehen an PostHog, auf Servern in der '
        'EU.',
      ),
    ]),
    p([
      .text(
        'Ab und zu bittet die App in einer kurzen Umfrage um Feedback. Die '
        'Antwort ist freiwillig; wenn du antwortest, wird das, was du '
        'schreibst, an PostHog gesendet.',
      ),
    ]),
    p([
      .text(
        'Die Datensätze sind an eine zufällige Gerätekennung gebunden, die '
        'die Analysebibliothek auf deinem Handy speichert, und sobald du '
        'dich anmeldest, an deine Kontokennung (eine zufällige ID, nicht '
        'deine Adresse); was vor deiner Anmeldung gezählt wurde, wird dann '
        'ebenfalls mit deinem Konto verknüpft. Damit sind sie pseudonym, '
        'nicht anonym.',
      ),
    ]),
    p([
      .text(
        'Die App fragt beim ersten Start, mit „Nicht erlauben“ und '
        '„Erlauben“ gleich gewichtet. Bevor du „Erlauben“ antippst, wird '
        'nichts eingerichtet: Es gibt keine Kennung, und nichts wird '
        'gesendet. Du kannst es dir jederzeit unter Mehr → '
        'Datenschutzeinstellungen anders überlegen; ausschalten beendet ab '
        'dann jede Übermittlung. Abmelden setzt die Wahl und die '
        'Gerätekennung zurück, und du wirst erneut gefragt – die Wahl gehört '
        'einer Person, nicht einem Handy. Rechtsgrundlage: deine '
        'Einwilligung, sowohl in das Speichern und Auslesen der Kennung auf '
        'deinem Handy (§ 25 Abs. 1 TDDDG) als auch in die Verarbeitung der '
        'Datensätze (Art. 6 Abs. 1 lit. a DSGVO). Der Widerruf berührt '
        'nicht, was vorher gesendet wurde. Gespeichert höchstens so lange '
        'wie das Aufbewahrungsfenster von PostHog für das Projekt, danach '
        'gelöscht oder so weit zusammengefasst, dass sich nichts mehr auf '
        'eine Person zurückführen lässt.',
      ),
    ]),

    h3([.text('Was auf deinem Handy bleibt')]),
    p([
      .text(
        'Manches speichert die App nur auf dem Handy, weil sie ohne es nicht '
        'funktioniert: deine Anmeldung, deine Wahl zur Nutzungsanalyse, wie '
        'weit du in den Schritten vor der Registrierung gekommen bist, den '
        'Namen, den du angegeben hast, bis dein Konto existiert, und die '
        'Anmeldemethode, die du zuletzt verwendet hast, damit der '
        'Anmeldebildschirm sie markieren kann. Die zuletzt verwendete '
        'Methode wird nirgendwohin gesendet; sie übersteht das Abmelden und '
        'wird gelöscht, wenn du das Konto löschst. Die Web-Ansicht, in der '
        'die Prüfung von Cloudflare läuft, kann behalten, was die Prüfung '
        'zum Funktionieren braucht. Für das Speichern braucht '
        'es keine Einwilligung, weil jedes davon für den Dienst, den du '
        'nutzen möchtest, unbedingt erforderlich ist (§ 25 Abs. 2 Nr. 2 '
        'TDDDG).',
      ),
    ]),
    p([
      .text(
        'Alles, was das Handy verlässt – zu unserem Server, zur Datenbank, '
        'zum Analyseanbieter und zu Cloudflare –, läuft über eine '
        'verschlüsselte '
        'HTTPS-Verbindung; unverschlüsselte Verbindungen baut die App '
        'überhaupt nicht auf.',
      ),
    ]),

    h3([.text('Die Konten für die Store-Prüfung')]),
    p([
      .text(
        'Zwei feste Konten, die wir bestätigt anlegen statt über die App, '
        'lassen die Prüferinnen und Prüfer von Apple und Google sich wie '
        'alle anderen mit E-Mail-Adresse und Passwort anmelden, ohne ein '
        'Postfach, aus dem sie einen Code lesen müssten. Sie gehören zum '
        'Prüfverfahren.',
      ),
    ]),

    h2(id: 'recipients', [.text('Wer sonst etwas davon sieht')]),
    ul([
      li([
        strong([.text('Supabase')]),
        .text(
          ' – die Datenbank und das Anmeldesystem, Frankfurt, Deutschland '
          '(EU). Speichert deine Adresse, dein Profil, deine Sessions, deine '
          'Einträge und deine Einwilligungsnachweise.',
        ),
      ]),
      li([
        strong([.text('Vercel')]),
        .text(
          ' – betreibt den emotely-Agenten in Frankfurt, Deutschland (EU), '
          'und das AI Gateway, durch das das Gespräch läuft. Speichert nichts '
          'aus deinem Tagebuch. Seine Firewall zählt außerdem Anfragen '
          'pro Internetadresse und lehnt am Session-Endpunkt mehr als '
          'dreißig pro Minute ab, damit ein öffentlicher Endpunkt nicht '
          'missbraucht wird; diese Prüfung nutzt die Adresse und sonst '
          'nichts, gestützt auf unser berechtigtes Interesse, den Dienst '
          'funktionsfähig zu halten (Art. 6 Abs. 1 lit. f DSGVO).',
        ),
      ]),
      li([
        strong([.text('Der Modellanbieter')]),
        .text(
          ' – wer das aktuelle Modell über das Gateway bereitstellt, für die '
          'Zeit, die die Antwort braucht. Was dort zugesagt ist und was '
          'nicht, steht oben.',
        ),
      ]),
      li([
        strong([.text('PostHog')]),
        .text(
          ' – Nutzungsanalyse und Absturzberichte, wenn du sie erlaubst, '
          'Umfrageantworten, wenn du sie gibst, und der technische Datensatz '
          'des Agenten zu jeder Runde; Server in der EU. Nie dein Tagebuch, '
          'dein Name oder deine E-Mail-Adresse.',
        ),
      ]),
      li([
        strong([.text('Cloudflare')]),
        .text(
          ' – führt die Prüfung vor einem Code oder einer Anmeldung mit '
          'Passwort durch (Turnstile), wie oben unter deiner E-Mail-Adresse '
          'beschrieben. Es nutzt diese Signale außerdem als eigener '
          'Verantwortlicher, um seine Bot-Erkennung zu verbessern, wie es '
          'sein ',
        ),
        a(href: 'https://www.cloudflare.com/turnstile-privacy-policy/', [
          .text('Turnstile-Datenschutzzusatz'),
        ]),
        .text(' beschreibt. Nie dein Tagebuch, dein Name oder deine Adresse.'),
      ]),
      li([
        strong([.text('Apple und Google')]),
        .text(
          ' – vertreiben die App und erheben, unabhängig von uns, eigene '
          'Download- und Absturzstatistiken nach ihren eigenen '
          'Datenschutzerklärungen. Meldest du dich mit einem von beiden an, '
          'bestätigt er, wer du bist, wie oben unter deiner E-Mail-Adresse '
          'beschrieben.',
        ),
      ]),
    ]),
    p([
      .text(
        'Nichts wird verkauft, nichts für Werbung weitergegeben, und es gibt '
        'in der App keine Werbenetzwerke, keine Tracker und keine '
        'Software-Development-Kits von Dritten außer den hier genannten.',
      ),
    ]),
    p([
      .text(
        'Supabase, Vercel, der Modellanbieter und PostHog verarbeiten diese '
        'Daten nur auf unsere Weisung, als Auftragsverarbeiter nach einem '
        'Auftragsverarbeitungsvertrag (Art. 28 DSGVO), der sie verpflichtet, '
        'die Daten nach demselben Standard zu schützen, der hier beschrieben '
        'ist, und ihnen verbietet, sie für eigene Zwecke zu nutzen. '
        'Cloudflare führt die Prüfung zu denselben Bedingungen durch, nur '
        'dass es mit ihren Signalen auch seine Bot-Erkennung verbessert, '
        'wie oben beschrieben. Apple '
        'und Google sind nicht unsere Auftragsverarbeiter: Was sie beim '
        'Vertrieb der App erheben, erheben sie als eigenständige '
        'Verantwortliche, nach ihren eigenen Richtlinien und außerhalb '
        'unseres Einflusses.',
      ),
    ]),

    h2(id: 'deletion', [.text('Dein Konto löschen')]),
    p([
      .text(
        'In der App: Mehr → Konto löschen, dann bestätigen. Ohne die App: '
        'die ',
      ),
      PageLink('/delete-account', 'Löschseite', locale: .de),
      .text(
        ', die dir einen Code schickt und das Konto löscht, sobald du ihn '
        'eingibst.',
      ),
    ]),
    p([
      .text(
        'Auf beiden Wegen verlassen das Konto, dein Profil, jeder Eintrag, '
        'jede Session und die Einwilligungsnachweise die Live-Datenbank, '
        'sobald die Löschung durchgeführt ist. Es gibt keine Karenzzeit und '
        'kein Archiv, das du danach anfordern könntest. Drei Dinge '
        'überdauern sie:',
      ),
    ]),
    ul([
      li([
        strong([.text('Analysedaten.')]),
        .text(
          ' Die oben beschriebenen pseudonymen Datensätze, wenn du sie '
          'erlaubt hast. Das Löschen des Kontos trennt die Verbindung '
          'zwischen ihren Kennungen und dir, aber die Zählungen bleiben. Sie '
          'enthalten keinen Tagebuchtext, keinen Namen und keine Adresse.',
        ),
      ]),
      li([
        strong([.text('Backups.')]),
        .text(
          ' Routinemäßige verschlüsselte Backups der gesamten Datenbank '
          'können noch eine Kopie enthalten, bis sie aus dem '
          'Aufbewahrungsfenster des Anbieters herausfallen. Sie werden nur '
          'genutzt, um die Datenbank nach einem Ausfall wiederherzustellen, '
          'nie, um ein gelöschtes Konto zurückzuholen.',
        ),
      ]),
      li([
        strong([.text('Die Warteliste, falls du dich eingetragen hast.')]),
        .text(
          ' Das ist eine eigene Liste hinter der Website, und das Löschen '
          'deines App-Kontos berührt sie nicht. Schreib an ',
        ),
        a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
        .text(', und du wirst auch von ihr entfernt.'),
      ]),
    ]),

    h2(id: 'breach', [.text('Wenn etwas schiefgeht')]),
    p([
      .text(
        'Die Maßnahmen oben sollen eine Datenpanne verhindern, nicht '
        'versprechen, dass sie unmöglich ist. Werden personenbezogene Daten '
        'hier jemals offengelegt, gehen sie verloren oder gelangen sie an '
        'jemanden, der sie nicht haben sollte, wird die unten genannte '
        'Aufsichtsbehörde unverzüglich und innerhalb von 72 Stunden '
        'benachrichtigt, nachdem uns die Verletzung bekannt geworden ist '
        '(Art. 33 DSGVO). Birgt die Verletzung voraussichtlich ein hohes '
        'Risiko für dich – und bei Tagebucheinträgen wäre das so –, wirst du '
        'direkt benachrichtigt, in klarer und einfacher Sprache, ohne dass '
        'du danach fragen musst (Art. 34 DSGVO).',
      ),
    ]),

    h2(id: 'rights', [.text('Deine Rechte')]),
    p([
      .text(
        'Du kannst Auskunft darüber verlangen, was über dich gespeichert ist, '
        'es berichtigen oder löschen lassen, seine Verarbeitung einschränken '
        'lassen, es in einem übertragbaren Format erhalten, einer '
        'Verarbeitung auf Grundlage berechtigter Interessen widersprechen '
        'und jede Einwilligung jederzeit widerrufen – was nicht berührt, was '
        'vorher geschah. Das Löschen des Kontos erledigt das meiste davon auf '
        'einmal; für alles andere schreib an ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(
        ' – die Adresse für jede Datenschutzfrage, beantwortet von Peter '
        'Trost persönlich. Du bekommst innerhalb eines Monats nach deiner '
        'Anfrage eine Antwort (Art. 12 Abs. 3 DSGVO); ist eine Anfrage '
        'wirklich kompliziert, sagen wir dir das innerhalb dieses Monats, und '
        'warum. Du kannst dich außerdem bei einer Datenschutzaufsichtsbehörde '
        'beschweren. Für uns zuständig ist der Landesbeauftragte für den '
        'Datenschutz und die Informationsfreiheit Baden-Württemberg, '
        'Lautenschlagerstraße 20, 70173 Stuttgart, poststelle@lfdi.bwl.de.',
      ),
    ]),

    h2(id: 'automated', [.text('Automatisierte Entscheidungen')]),
    p([
      .text(
        'emotely arbeitet automatisch: Es wählt die nächste Frage und '
        'schreibt die Zusammenfassung deines Eintrags, ohne dass jemand '
        'mitliest. Das ist die einzige automatisierte Verarbeitung hier. '
        'Über dich wird keine Entscheidung getroffen, die dir gegenüber '
        'rechtliche Wirkung entfaltet oder dich in ähnlicher Weise erheblich '
        'beeinträchtigt – nichts wird bewertet, in eine Rangfolge gebracht '
        'oder an jemanden weitergegeben, der etwas über dich entscheidet –, '
        'daher ist Art. 22 Abs. 1 DSGVO über automatisierte Entscheidungen '
        'im Einzelfall nicht anwendbar.',
      ),
    ]),

    h2(id: 'children', [.text('Kinder')]),
    p([
      .text(
        'emotely ist für Menschen ab 16 Jahren. Es ist nicht für Kinder '
        'gemacht oder an sie gerichtet: Es erhebt nichts für Werbung und '
        'zeigt keine Werbung. Ab 16 kannst du in Deutschland selbst in diese '
        'Verarbeitung einwilligen (Art. 8 DSGVO), und weil das Produkt auf '
        'deiner Einwilligung beruht, ist das das Mindestalter, von dem die '
        'App ausgeht. Wir prüfen das Alter nicht, und die Altersfreigaben in '
        'den Stores werden im Zuge der Veröffentlichung noch festgelegt; '
        'sobald sie feststehen, nennt dieser Abschnitt sie. Wenn du glaubst, '
        'dass ein Kind hier Einträge geschrieben hat, schreib an ',
      ),
      a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
      .text(', und das Konto wird gelöscht.'),
    ]),

    h2(id: 'not-medical', [.text('Kein medizinisches Angebot')]),
    p([
      .text(
        'emotely ist ein Werkzeug zum Tagebuchschreiben. Es ist keine '
        'Therapie, kein Medizinprodukt und kein Ersatz für professionelle '
        'Hilfe, und emotely stellt keine Diagnosen und behandelt nichts. '
        'Wenn du in einer Krise bist, wende dich bitte an eine Fachperson '
        'oder an deine örtliche Notrufnummer.',
      ),
    ]),

    h2(id: 'web-site', [.text('Die Website')]),
    p([
      .text(
        'getemotely.com und die Warteliste für den frühen Zugang fallen '
        'unter die ',
      ),
      PageLink('/privacy', 'Datenschutzerklärung der Website', locale: .de),
      .text(', einen eigenen Text über eigene Daten.'),
    ]),

    h2(id: 'changes', [.text('Änderungen dieser Datenschutzerklärung')]),
    p([
      .text(
        'Änderungen werden hier mit neuem Datum oben veröffentlicht, und '
        'jede Fassung liegt im öffentlichen Repository, sodass nachvollziehbar '
        'bleibt, was sich wann geändert hat. Alles, was wesentlich verändert, '
        'was mit deinem Tagebuch geschieht, erfährst du in der App oder per '
        'E-Mail, bevor es wirksam wird. emotely ist Open Source unter der '
        'MIT-Lizenz: Du musst uns nichts davon einfach glauben – ',
      ),
      a(href: repositoryUrl, [.text('lies den Code')]),
      .text('.'),
    ]),
  ]);
}
