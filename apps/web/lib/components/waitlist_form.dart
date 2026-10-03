import 'dart:async';

import 'package:emotely_web/analytics.dart';
import 'package:emotely_web/attribution.dart';
import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_locale.dart';
import 'package:emotely_web/waitlist.dart';
import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:universal_web/web.dart' as web;

/// The one interactive island on the site: an address in, a thank-you out.
///
/// `@client` components take only serializable parameters, so the HTTP
/// client is not injected; `http.Client()` honors `http.runWithClient`,
/// which is how tests put a fake behind it. For the same reason the
/// language comes in as [lang], a [SiteLocale]'s code.
//
// jaspr_builder parses @client files with analyzer 12, which cannot read a
// primary constructor yet, so this one file keeps the classic form.
// ignore_for_file: use_primary_constructors
// The classic form repeats the type name in the constructor; the fix this
// rule proposes is the primary constructor the builder cannot parse.
// ignore_for_file: unnecessary_type_name_in_constructor
@client
class WaitlistForm extends StatefulComponent {
  const WaitlistForm({this.lang = 'en', super.key});

  /// The code of the [SiteLocale] the form speaks.
  final String lang;

  @override
  State<WaitlistForm> createState() => _WaitlistFormState();
}

/// Everything the form says, in one language.
class _Words {
  const _Words({
    required this.invalid,
    required this.tooMany,
    required this.rejected,
    required this.failed,
    required this.thanks,
    required this.label,
    required this.placeholder,
    required this.sending,
    required this.join,
    required this.consent,
  });

  final String invalid;
  final String tooMany;
  final String rejected;
  final String failed;
  final String thanks;
  final String label;
  final String placeholder;
  final String sending;
  final String join;
  final String consent;
}

const _english = _Words(
  invalid: "That doesn't look like an email address.",
  tooMany:
      'Too many sign-ups from your network right now. Try again in an hour.',
  rejected: 'That address was refused. Check it and try again.',
  failed: 'Something went wrong. Try again in a moment.',
  thanks:
      'Check your inbox: one click on the link there and your spot is held.',
  label: 'Email address',
  placeholder: 'you@example.com',
  sending: 'Saving your spot…',
  join: 'Get early access',
  consent:
      'One email when your spot opens, nothing else. Delete your address any '
      'time by writing to ',
);

const _german = _Words(
  invalid: 'Das sieht nicht nach einer E-Mail-Adresse aus.',
  tooMany:
      'Gerade kommen zu viele Anmeldungen aus deinem Netzwerk. Versuch es in '
      'einer Stunde noch einmal.',
  rejected:
      'Diese Adresse wurde abgelehnt. Prüf sie und versuch es noch '
      'einmal.',
  failed: 'Etwas ist schiefgegangen. Versuch es gleich noch einmal.',
  thanks:
      'Schau in dein Postfach: ein Klick auf den Link darin, und dein Platz '
      'ist reserviert.',
  label: 'E-Mail-Adresse',
  placeholder: 'du@example.com',
  sending: 'Dein Platz wird gespeichert …',
  join: 'Frühen Zugang sichern',
  consent:
      'Eine E-Mail, wenn dein Platz frei wird, sonst nichts. Löschen lassen '
      'kannst du deine Adresse jederzeit: schreib an ',
);

enum _Phase { idle, sending, joined }

class _WaitlistFormState extends State<WaitlistForm> {
  var _email = '';
  // A field no person sees or fills; bots fill everything.
  var _website = '';
  _Phase _phase = .idle;
  String? _message;

  SiteLocale get _locale => SiteLocale.values.byName(component.lang);

  _Words get _words => switch (_locale) {
    .en => _english,
    .de => _german,
  };

  Future<void> _submit() async {
    final source = sourceFrom(
      query: web.window.location.search,
      referrer: web.document.referrer,
    );
    if (_website.isNotEmpty) {
      setState(() => _phase = .joined);
      return;
    }
    final email = _email.trim();
    if (!looksLikeEmail(email)) {
      track('waitlist_refused', {'source': source, 'reason': 'invalid'});
      setState(() => _message = _words.invalid);
      return;
    }
    setState(() {
      _phase = .sending;
      _message = null;
    });
    final client = http.Client();
    try {
      final outcome = await joinWaitlist(
        client,
        email: email,
        source: source,
        locale: _locale,
        supabaseUrl: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      if (outcome == .joined) {
        track('waitlist_joined', {'source': source});
      } else {
        track('waitlist_refused', {'source': source, 'reason': outcome.name});
      }
      setState(() {
        switch (outcome) {
          case .joined:
            _phase = .joined;
          case .tooMany:
            _phase = .idle;
            _message = _words.tooMany;
          case .rejected:
            _phase = .idle;
            _message = _words.rejected;
          case .failed:
            _phase = .idle;
            _message = _words.failed;
        }
      });
    } finally {
      client.close();
    }
  }

  @override
  Component build(BuildContext context) {
    final words = _words;
    if (_phase == .joined) {
      return div(classes: 'waitlist waitlist-done', [
        p(classes: 'waitlist-thanks', [.text(words.thanks)]),
      ]);
    }
    return form(
      classes: 'waitlist',
      noValidate: true,
      events: {
        'submit': (event) {
          event.preventDefault();
          unawaited(_submit());
        },
      },
      [
        label(htmlFor: 'waitlist-email', classes: 'sr-only', [
          .text(words.label),
        ]),
        input<String>(
          key: const Key('email'),
          id: 'waitlist-email',
          type: .email,
          name: 'email',
          value: _email,
          onInput: (value) => _email = value,
          attributes: {
            'placeholder': words.placeholder,
            'autocomplete': 'email',
            'inputmode': 'email',
          },
        ),
        input<String>(
          key: const Key('website'),
          classes: 'hp',
          type: .text,
          name: 'website',
          value: _website,
          onInput: (value) => _website = value,
          attributes: const {
            'tabindex': '-1',
            'autocomplete': 'off',
            'aria-hidden': 'true',
          },
        ),
        button(
          key: const Key('join'),
          type: .submit,
          classes: 'cta',
          disabled: _phase == .sending,
          [.text(_phase == .sending ? words.sending : words.join)],
        ),
        if (_message case final message?)
          p(classes: 'waitlist-message', [.text(message)]),
        p(classes: 'waitlist-consent', [
          .text(words.consent),
          const a(href: 'mailto:$contactEmail', [.text(contactEmail)]),
          const .text('.'),
        ]),
      ],
    );
  }
}
