import 'package:emotely_web/components/waitlist_form.dart';
import 'package:emotely_web/environment.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// `/de`: the landing page in German, a translation of `Home` section for
/// section, under the same ids. emotely is the companion's name here too:
/// where the English says "the assistant", the German says "emotely"
/// (`CONTEXT.md`).
class const HomeDe({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) => main_(classes: 'page', [
    _hero(),
    _problem(),
    _howItWorks(),
    _whatYouGet(),
    _guarantee(),
    _builtInPublic(),
    _questions(),
    _finalCall(),
  ]);

  Component _hero() => const section(id: 'top', classes: 'hero', [
    p(classes: 'eyebrow', [.text('Früher Zugang · iOS und Android')]),
    h1([
      .text(
        'Wissen, was du heute wirklich gefühlt hast. '
        'In fünf Minuten, ohne vor einer leeren Seite zu sitzen.',
      ),
    ]),
    p(classes: 'lede', [
      .text(
        'emotely stellt dir jeden Abend eine Handvoll guter Fragen, hört zu '
        'und schreibt den Tagebucheintrag für dich. '
        'Open Source. Deine Worte bleiben deine.',
      ),
    ]),
    WaitlistForm(lang: 'de'),
  ]);

  Component _problem() => const section(classes: 'band', [
    h2([.text('Tagebuchschreiben wirkt. Leere Seiten nicht.')]),
    p([
      .text(
        'Alle, die beim Tagebuch bleiben, sagen dasselbe: Sie verstehen sich '
        'besser, sie schlafen besser, die schlechten Tage werden kleiner. '
        'Alle, die aufhören, sagen auch dasselbe: die leere Seite, das „Was '
        'soll ich überhaupt schreiben?“, der dritte verpasste Abend, aus dem '
        'ein verpasster Monat wird.',
      ),
    ]),
    p([
      .text(
        'emotely nimmt dir den Teil ab, an dem Leute aufgeben. Du schreibst '
        'nie aus dem Nichts. Du antwortest, und der Eintrag schreibt sich '
        'selbst.',
      ),
    ]),
  ]);

  Component _howItWorks() => section(id: 'how', [
    const h2([.text('So funktioniert’s')]),
    ol(classes: 'steps', [
      _step(
        'Such dir ein Fragenset aus',
        'Heute Abend: Dankbarkeit, ein schwerer Tag, eine Entscheidung oder '
            'der ganz normale Abendrückblick.',
      ),
      _step(
        'Antworte mit Tippen, nicht mit Aufsätzen',
        'Hier eine Bewertung, dort drei Wörter, ein ehrlicher Satz, wenn es '
            'darauf ankommt. Jede Antwort bekommt ein kleines eigenes '
            'Bedienelement, kein Chatfenster.',
      ),
      _step(
        'Lies deinen Eintrag',
        'emotely macht aus deinen Antworten einen echten Tagebucheintrag, in '
            'deinen Worten, abgelegt in einem Tagebuch, durch das du scrollen '
            'kannst.',
      ),
    ]),
  ]);

  Component _step(String title, String body) => li([
    h3([.text(title)]),
    p([.text(body)]),
  ]);

  Component _whatYouGet() => section(id: 'offer', classes: 'band', [
    const h2([.text('Was du bekommst')]),
    ul(classes: 'stack', [
      _item(
        'Geführte Abend-Sessions',
        'Jeden Abend eine strukturierte Reflexion, fünf Minuten, keine leere '
            'Seite.',
      ),
      _item(
        'Einträge, für dich geschrieben',
        'Beantworte die Fragen; der Eintrag entsteht aus genau dem, was du '
            'gesagt hast.',
      ),
      _item(
        'Ein Tagebuch, das du wirklich wieder liest',
        'Jeder Eintrag, der Reihe nach, auf deinem Handy, mit den Fragen, '
            'aus denen er entstanden ist.',
      ),
      _item(
        'Privat von Grund auf',
        'Dein Tagebuch liegt in einer Datenbank, die nur dein Konto lesen '
            'kann, auf Servern in der EU. Lösch dein Konto, und alles geht '
            'mit, mit einem Tippen.',
      ),
      _item(
        'Open Source, MIT',
        'Die App, der Server hinter den Fragen und die Regeln der Datenbank '
            'sind öffentlich. Du musst uns nichts davon einfach glauben.',
      ),
    ]),
  ]);

  Component _item(String title, String body) => li([
    strong([.text(title)]),
    span([.text(' – $body')]),
  ]);

  Component _guarantee() => const section(id: 'guarantee', [
    h2([.text('Kein Haken')]),
    p(classes: 'lede', [
      .text(
        'Kostenlos während des frühen Zugangs. Exportiere oder lösche alles, '
        'was du geschrieben hast, jederzeit. Keine Werbung, kein Verkauf '
        'deiner Daten, keine „Insights“, die mit irgendwem geteilt werden. '
        'Wenn emotely keine fünf Minuten deines Abends wert ist, verlierst '
        'du nichts außer den fünf Minuten.',
      ),
    ]),
  ]);

  Component _builtInPublic() => const section(classes: 'band', [
    h2([.text('Öffentlich gebaut')]),
    p([
      .text(
        'emotely wird von einer Person gemacht, die jeden Abend damit '
        'Tagebuch schreibt und jede Zeile davon veröffentlicht. Lies den '
        'Code, bevor du ihm vertraust: ',
      ),
      a(href: repositoryUrl, [.text('Den Code auf GitHub lesen')]),
      .text('.'),
    ]),
  ]);

  Component _questions() => section(id: 'faq', [
    const h2([.text('Fragen')]),
    dl(classes: 'faq', [
      _qa(
        'Ist das Therapie?',
        'Nein. emotely ist ein Werkzeug zum Tagebuchschreiben, kein Ersatz '
            'für Therapie oder medizinische Versorgung. Wenn du in einer '
            'Krise bist, wende dich bitte an eine Fachperson oder an deine '
            'örtliche Notrufnummer.',
      ),
      _qa(
        'Wird mein Tagebuch zum Trainieren von KI genutzt?',
        'Nein. Deine Einträge werden nie zum Trainieren von irgendetwas '
            'genutzt, und emotely sieht deine Antworten nur, während es '
            'deinen Eintrag schreibt. Die Produktanalyse hält fest, dass eine '
            'Session stattgefunden hat, nie, was gesagt wurde.',
      ),
      _qa(
        'Welche Geräte?',
        'iOS und Android. Zuerst Handys; Tablets und faltbare Geräte folgen. '
            'Der frühe Zugang öffnet sich in kleinen Gruppen, damit jede '
            'Person eine Antwort von einem Menschen bekommt.',
      ),
      _qa(
        'Was kostet es?',
        'Während des frühen Zugangs nichts. Von jeder Änderung erfährst du '
            'zuerst per E-Mail, mit Zeit zum Exportieren.',
      ),
      _qa(
        'Wer steckt dahinter?',
        'Peter Trost, ein Flutter-Entwickler in Deutschland, der emotely als '
            'Produkt baut und als öffentliches Vorzeigeprojekt für '
            'KI-Engineering.',
      ),
    ]),
  ]);

  Component _qa(String question, String answer) => div(classes: 'qa', [
    dt([.text(question)]),
    dd([.text(answer)]),
  ]);

  Component _finalCall() => const section(id: 'join', classes: 'final-call', [
    h2([.text('Dein erster Eintrag ist fünf Minuten entfernt')]),
    p([
      .text(
        'Hinterlass deine Adresse und sichere dir deinen Platz in der '
        'nächsten Gruppe.',
      ),
    ]),
    a(href: '#top', classes: 'cta', [.text('Frühen Zugang sichern')]),
  ]);
}
