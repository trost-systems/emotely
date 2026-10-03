import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_bloc.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:feature_auth/src/view/password_field.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:feature_auth/src/view/sign_in_error.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The first step: Apple and Google, then the email and a password, in one
/// autofill group so a password manager fills both and offers to save
/// them. As [SignInMode.signUp] the password is a new one (at least
/// [minimumPasswordLength] characters) and the button creates the account;
/// as [SignInMode.signIn] it signs in. "Forgot password?" mails a reset
/// code to the address typed, in either mode. [email] fills the field when
/// the user comes back to it.
class const EmailForm({
  required final SignInMode mode,
  final String? email,
  final SignInProblem? problem,
  final bool busy = false,
  super.key,
}) extends StatefulWidget {
  @override
  State<EmailForm> createState() => _EmailFormState();
}

class _EmailFormState() extends State<EmailForm> {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();

  String get _address => _email.text.trim();

  // Good enough to stop typos before a round trip; Supabase validates the
  // address for real.
  bool get _plausible => _address.contains('@') && _address.contains('.');

  bool get _signingUp => widget.mode == SignInMode.signUp;

  bool get _complete =>
      _plausible &&
      (_signingUp ? longEnough(_password.text) : _password.text.isNotEmpty);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<AuthBloc>().add(
    _signingUp
        ? AuthEvent.signUpSubmitted(_address, _password.text)
        : AuthEvent.signInSubmitted(_address, _password.text),
  );

  void _changed(String _) => setState(() {});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      ProviderButtons(
        enabled: !widget.busy,
        lastUsed: context.watch<LastSignInBloc>().state,
      ),
      const OrWithEmail(),
      AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TextField(
              key: SignInPage.emailKey,
              controller: _email,
              enabled: !widget.busy,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.l10n.emailLabel,
                hintText: context.l10n.emailHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: _changed,
            ),
            PasswordField(
              fieldKey: SignInPage.passwordKey,
              controller: _password,
              label: context.l10n.passwordLabel,
              enabled: !widget.busy,
              choosing: _signingUp,
              onChanged: _changed,
              // The field is disabled while a check is in flight, so "done"
              // cannot submit twice.
              onSubmitted: (_) => _complete ? _submit() : null,
            ),
          ],
        ),
      ),
      SignInError(widget.problem),
      if (widget.busy)
        const StepBusy()
      else
        _FormActions(
          signingUp: _signingUp,
          onSubmit: _complete ? _submit : null,
          onForgot: _plausible
              ? () => context.read<AuthBloc>().add(
                  AuthEvent.resetRequested(_address),
                )
              : null,
        ),
    ],
  );
}

/// Sign in or create the account, tagged when the email was the way in last
/// time; and the way back in for a forgotten password.
class const _FormActions({
  required final bool signingUp,
  required final VoidCallback? onSubmit,
  required final VoidCallback? onForgot,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final label = signingUp
        ? strings.createAccountButton
        : strings.signInButton;
    final lastUsed =
        context.watch<LastSignInBloc>().state == SignInOption.email;
    final button = FilledButton(
      key: SignInPage.submitKey,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onSubmit,
      child: Text(
        label,
        semanticsLabel: lastUsed ? strings.lastUsedButton(label) : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (lastUsed) LastUsedTag(child: button) else button,
        TextButton(
          key: SignInPage.forgotPasswordKey,
          onPressed: onForgot,
          child: Text(strings.forgotPasswordButton),
        ),
      ],
    );
  }
}

/// A step's request is with Supabase.
class const StepBusy({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
