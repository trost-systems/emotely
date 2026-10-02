import 'dart:async';

import 'package:emotely_web/analytics.dart';
import 'package:emotely_web/delete_account.dart';
import 'package:emotely_web/environment.dart';
import 'package:emotely_web/site_locale.dart';
import 'package:emotely_web/waitlist.dart' show looksLikeEmail;
import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// The deletion form, for people who no longer have the app installed: an
/// address, the six-digit code that proves the mailbox is theirs, and the
/// account is gone. The same proof the app asks for, and the same
/// `delete_account()` call it makes.
///
/// Two states worth knowing about:
///
/// * An address with no account is answered exactly like one that has, so
///   the form cannot be used to find out who has an emotely account. The
///   copy on the code step is conditional for that reason ("if that
///   address has an account").
/// * Nothing is stored anywhere: the access token lives for the length of
///   the delete call and the page keeps no session, so there is nothing to
///   sign back in with when it is done.
//
// jaspr_builder parses @client files with analyzer 12, which cannot read a
// primary constructor yet, so this one file keeps the classic form.
// ignore_for_file: use_primary_constructors
// The classic form repeats the type name in the constructor; the fix this
// rule proposes is the primary constructor the builder cannot parse.
// ignore_for_file: unnecessary_type_name_in_constructor
@client
class DeleteAccountForm extends StatefulComponent {
  const DeleteAccountForm({this.lang = 'en', super.key});

  /// The code of the [SiteLocale] the form speaks.
  final String lang;

  @override
  State<DeleteAccountForm> createState() => _DeleteAccountFormState();
}

/// Everything the form says, in one language.
class _Words {
  const _Words({
    required this.invalid,
    required this.tooMany,
    required this.failed,
    required this.codeShape,
    required this.tickFirst,
    required this.badCode,
    required this.doneTitle,
    required this.doneBody,
    required this.addressLabel,
    required this.placeholder,
    required this.sendingCode,
    required this.sendCode,
    required this.codeIntro,
    required this.codeLabel,
    required this.understood,
    required this.deleting,
    required this.delete,
    required this.startOver,
  });

  final String invalid;
  final String tooMany;
  final String failed;
  final String codeShape;
  final String tickFirst;
  final String badCode;
  final String doneTitle;
  final String doneBody;
  final String addressLabel;
  final String placeholder;
  final String sendingCode;
  final String sendCode;
  final String codeIntro;
  final String codeLabel;
  final String understood;
  final String deleting;
  final String delete;
  final String startOver;
}

const _english = _Words(
  invalid: "That doesn't look like an email address.",
  tooMany:
      'Too many requests from your network right now. Try again in an hour.',
  failed: 'Something went wrong. Try again in a moment.',
  codeShape: 'The code is six digits.',
  tickFirst: 'Tick the box first: this cannot be undone once it runs.',
  badCode:
      'That code did not match, or it is older than ten minutes. Check the '
      'newest email and try again.',
  doneTitle: 'Your account is gone',
  doneBody:
      'The account and everything in it — every entry, every session, the '
      'address itself — was deleted just now. Nothing is kept, so there is '
      'nothing left to undo and nothing to sign in to. If you come back one '
      'day, you start fresh.',
  addressLabel: 'The email address of the account',
  placeholder: 'you@example.com',
  sendingCode: 'Sending the code…',
  sendCode: 'Send me a code',
  // Conditional on purpose: saying "we sent you a code" would tell a
  // stranger that this address has an emotely account.
  codeIntro:
      'If that address has an account, a six-digit code is on its way to '
      'it. Type the code below, confirm that you mean it, and the account is '
      'deleted.',
  codeLabel: 'The six-digit code',
  understood:
      ' I understand this deletes my account and everything in it, and that '
      'it cannot be undone.',
  deleting: 'Deleting…',
  delete: 'Delete my account for good',
  startOver: 'Start over with a different address',
);

const _german = _Words(
  invalid: 'Das sieht nicht nach einer E-Mail-Adresse aus.',
  tooMany:
      'Gerade kommen zu viele Anfragen aus deinem Netzwerk. Versuch es in '
      'einer Stunde noch einmal.',
  failed: 'Etwas ist schiefgegangen. Versuch es gleich noch einmal.',
  codeShape: 'Der Code hat sechs Ziffern.',
  tickFirst:
      'Setz zuerst das Häkchen: Sobald es läuft, lässt es sich nicht '
      'rückgängig machen.',
  badCode:
      'Dieser Code passt nicht, oder er ist älter als zehn Minuten. Nimm den '
      'aus der neuesten E-Mail und versuch es noch einmal.',
  doneTitle: 'Dein Konto ist gelöscht',
  doneBody:
      'Das Konto und alles darin – jeder Eintrag, jede Session, die Adresse '
      'selbst – wurde eben gelöscht. Nichts wird aufbewahrt, es gibt also '
      'nichts rückgängig zu machen und nichts, womit du dich anmelden '
      'könntest. Kommst du eines Tages zurück, fängst du neu an.',
  addressLabel: 'Die E-Mail-Adresse des Kontos',
  placeholder: 'du@example.com',
  sendingCode: 'Der Code wird gesendet …',
  sendCode: 'Schick mir einen Code',
  // Conditional on purpose, as in English.
  codeIntro:
      'Wenn zu dieser Adresse ein Konto gehört, ist ein sechsstelliger Code '
      'dorthin unterwegs. Gib den Code unten ein, bestätige, dass du es '
      'ernst meinst, und das Konto wird gelöscht.',
  codeLabel: 'Der sechsstellige Code',
  understood:
      ' Ich verstehe, dass damit mein Konto und alles darin gelöscht wird '
      'und dass sich das nicht rückgängig machen lässt.',
  deleting: 'Wird gelöscht …',
  delete: 'Mein Konto endgültig löschen',
  startOver: 'Mit einer anderen Adresse neu beginnen',
);

enum _Step { address, code, done }

class _DeleteAccountFormState extends State<DeleteAccountForm> {
  var _email = '';
  var _code = '';
  // A field no person sees or fills; bots fill everything. Same trick as
  // the waitlist form, and this form is the more sensitive of the two.
  var _website = '';
  var _understood = false;
  _Step _step = .address;
  var _busy = false;
  String? _message;

  _Words get _words => switch (SiteLocale.values.byName(component.lang)) {
    .en => _english,
    .de => _german,
  };

  /// Back to the start: a mistyped address, or a code that went stale
  /// (GoTrue expires them after ten minutes) needs a fresh one.
  void _startOver() {
    setState(() {
      _step = .address;
      _code = '';
      _understood = false;
      _message = null;
    });
  }

  Future<void> _sendCode() async {
    if (_website.isNotEmpty) {
      // Answer a bot exactly like a person, without spending a mail on it.
      setState(() => _step = .code);
      return;
    }
    final email = _email.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _message = _words.invalid);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final client = http.Client();
    try {
      final outcome = await requestDeletionCode(
        client,
        email: email,
        supabaseUrl: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      // No `source`, no address, no code: a deletion is not a campaign and
      // the event must not say whose account it was (ADR 0005).
      track('delete_code_requested', {'outcome': outcome.name});
      setState(() {
        _busy = false;
        switch (outcome) {
          // `sent` covers "no such account" too, on purpose.
          case .sent:
            _step = .code;
          case .tooMany:
            _message = _words.tooMany;
          case .failed:
            _message = _words.failed;
        }
      });
    } finally {
      client.close();
    }
  }

  Future<void> _delete() async {
    // Pasting from a mail app brings spaces along ("12 34 56"); a correct
    // code should not be refused for how it travelled.
    final code = normaliseCode(_code);
    if (!looksLikeCode(code)) {
      setState(() => _message = _words.codeShape);
      return;
    }
    if (!_understood) {
      setState(() => _message = _words.tickFirst);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final client = http.Client();
    try {
      final outcome = await deleteAccountWithCode(
        client,
        email: _email.trim(),
        code: code,
        supabaseUrl: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      track('delete_account_web', {'outcome': outcome.name});
      setState(() {
        _busy = false;
        switch (outcome) {
          case .deleted:
            _step = .done;
          case .badCode:
            _message = _words.badCode;
          case .failed:
            _message = _words.failed;
        }
      });
    } finally {
      client.close();
    }
  }

  @override
  Component build(BuildContext context) => switch (_step) {
    .address => _addressStep(_words),
    .code => _codeStep(_words),
    .done => div(classes: 'delete-account delete-account-done', [
      h2([.text(_words.doneTitle)]),
      p([.text(_words.doneBody)]),
    ]),
  };

  Component _addressStep(_Words words) => form(
    classes: 'delete-account',
    noValidate: true,
    events: {
      'submit': (event) {
        event.preventDefault();
        unawaited(_sendCode());
      },
    },
    [
      label(htmlFor: 'delete-email', [.text(words.addressLabel)]),
      input<String>(
        key: const Key('email'),
        id: 'delete-email',
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
        key: const Key('send-code'),
        type: .submit,
        classes: 'cta',
        disabled: _busy,
        [.text(_busy ? words.sendingCode : words.sendCode)],
      ),
      if (_message case final message?) _alert(message),
    ],
  );

  /// The one place a message is rendered, so every one of them announces
  /// itself to a screen reader where it stands.
  Component _alert(String message) => p(
    key: const Key('message'),
    classes: 'delete-account-message',
    attributes: const {'role': 'alert'},
    [.text(message)],
  );

  Component _codeStep(_Words words) => form(
    classes: 'delete-account',
    noValidate: true,
    events: {
      'submit': (event) {
        event.preventDefault();
        unawaited(_delete());
      },
    },
    [
      p([.text(words.codeIntro)]),
      label(htmlFor: 'delete-code', [.text(words.codeLabel)]),
      input<String>(
        key: const Key('code'),
        id: 'delete-code',
        type: .text,
        name: 'code',
        value: _code,
        onInput: (value) => _code = value,
        attributes: const {
          'placeholder': '123456',
          'autocomplete': 'one-time-code',
          'inputmode': 'numeric',
          // Spaces are stripped before the check, so a pasted "12 34 56"
          // must be allowed to land in the field first.
          'maxlength': '8',
          // The step just changed under the reader; put them in the field.
          'autofocus': '',
        },
      ),
      label(classes: 'delete-account-consent', htmlFor: 'delete-understood', [
        input<bool>(
          key: const Key('understood'),
          id: 'delete-understood',
          type: .checkbox,
          name: 'understood',
          checked: _understood,
          onInput: (value) => setState(() => _understood = value),
        ),
        .text(words.understood),
      ]),
      button(
        key: const Key('delete'),
        type: .submit,
        classes: 'cta delete-account-confirm',
        disabled: _busy,
        [.text(_busy ? words.deleting : words.delete)],
      ),
      if (_message case final message?) _alert(message),
      p(classes: 'delete-account-restart', [
        button(
          key: const Key('start-over'),
          type: .button,
          classes: 'linklike',
          onClick: _startOver,
          [.text(words.startOver)],
        ),
      ]),
    ],
  );
}
