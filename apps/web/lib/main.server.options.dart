// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:emotely_web/components/confirm_waitlist.dart'
    as _confirm_waitlist;
import 'package:emotely_web/components/delete_account_form.dart'
    as _delete_account_form;
import 'package:emotely_web/components/waitlist_form.dart' as _waitlist_form;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _confirm_waitlist.ConfirmWaitlist:
        ClientTarget<_confirm_waitlist.ConfirmWaitlist>(
          'confirm_waitlist',
          params: __confirm_waitlistConfirmWaitlist,
        ),
    _delete_account_form.DeleteAccountForm:
        ClientTarget<_delete_account_form.DeleteAccountForm>(
          'delete_account_form',
          params: __delete_account_formDeleteAccountForm,
        ),
    _waitlist_form.WaitlistForm: ClientTarget<_waitlist_form.WaitlistForm>(
      'waitlist_form',
      params: __waitlist_formWaitlistForm,
    ),
  },
);

Map<String, Object?> __confirm_waitlistConfirmWaitlist(
  _confirm_waitlist.ConfirmWaitlist c,
) => {'lang': c.lang};
Map<String, Object?> __delete_account_formDeleteAccountForm(
  _delete_account_form.DeleteAccountForm c,
) => {'lang': c.lang};
Map<String, Object?> __waitlist_formWaitlistForm(
  _waitlist_form.WaitlistForm c,
) => {'lang': c.lang};
