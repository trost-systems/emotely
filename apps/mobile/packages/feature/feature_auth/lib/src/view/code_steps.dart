import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:feature_auth/src/view/email_form.dart';
import 'package:feature_auth/src/view/password_field.dart';
import 'package:feature_auth/src/view/sign_in_error.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The six digits a mail carries: the confirmation code that opens a new
/// account ([CodePurpose.confirmAccount]), or the reset code that, with a
/// new password beside it, lets an account back in
/// ([CodePurpose.resetPassword]). Either can be sent again, or the user
/// goes back to type another address.
class const CodeStep({
  required final String email,
  required final CodePurpose purpose,
  final SignInProblem? problem,
  final bool resent = false,
  final bool busy = false,
  super.key,
}) extends StatefulWidget {
  static const codeLength = 6;

  @override
  State<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState() extends State<CodeStep> {
  final _code = TextEditingController();
  final _password = TextEditingController();

  String get _typed => _code.text.trim();

  bool get _resetting => widget.purpose == CodePurpose.resetPassword;

  bool get _complete =>
      _typed.length == CodeStep.codeLength &&
      _typed.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39) &&
      (!_resetting || longEnough(_password.text));

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<AuthBloc>().add(
    _resetting
        ? AuthEvent.resetSubmitted(_typed, _password.text)
        : AuthEvent.confirmationSubmitted(_typed),
  );

  void _changed(String _) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          _resetting
              ? strings.resetSentMessage(widget.email)
              : strings.confirmationSentMessage(widget.email),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        TextField(
          key: SignInPage.codeKey,
          controller: _code,
          enabled: !widget.busy,
          autofillHints: const [AutofillHints.oneTimeCode],
          keyboardType: TextInputType.number,
          maxLength: CodeStep.codeLength,
          decoration: InputDecoration(labelText: strings.codeLabel),
          onChanged: _changed,
        ),
        if (_resetting)
          PasswordField(
            fieldKey: SignInPage.newPasswordKey,
            controller: _password,
            label: strings.newPasswordLabel,
            enabled: !widget.busy,
            choosing: true,
            onChanged: _changed,
            onSubmitted: (_) => _complete ? _submit() : null,
          ),
        if (widget.resent && widget.problem == null)
          Text(strings.codeResentMessage, key: SignInPage.codeResentKey),
        SignInError(widget.problem),
        if (widget.busy)
          const StepBusy()
        else
          _CodeActions(
            submitKey: _resetting
                ? SignInPage.savePasswordKey
                : SignInPage.confirmKey,
            submitLabel: _resetting
                ? strings.savePasswordButton
                : strings.confirmButton,
            onSubmit: _complete ? _submit : null,
          ),
      ],
    );
  }
}

/// Use the code, mail a new one, or go back for a different email.
class const _CodeActions({
  required final Key submitKey,
  required final String submitLabel,
  required final VoidCallback? onSubmit,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        FilledButton(
          key: submitKey,
          onPressed: onSubmit,
          child: Text(submitLabel),
        ),
        TextButton(
          key: SignInPage.resendCodeKey,
          onPressed: () => bloc.add(const AuthEvent.codeResendRequested()),
          child: Text(context.l10n.resendCodeButton),
        ),
        TextButton(
          key: SignInPage.changeEmailKey,
          onPressed: () => bloc.add(const AuthEvent.emailChangeRequested()),
          child: Text(context.l10n.changeEmailButton),
        ),
      ],
    );
  }
}

/// A reset code signed the account in, but its new password could not be
/// saved: the user chooses it once more, and is let in once it is.
class const NewPasswordStep({
  required final String email,
  final SignInProblem? problem,
  final bool busy = false,
  super.key,
}) extends StatefulWidget {
  @override
  State<NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState() extends State<NewPasswordStep> {
  final _password = TextEditingController();

  bool get _complete => longEnough(_password.text);

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<AuthBloc>().add(
    AuthEvent.newPasswordSubmitted(_password.text),
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          strings.newPasswordPrompt(widget.email),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        PasswordField(
          fieldKey: SignInPage.newPasswordKey,
          controller: _password,
          label: strings.newPasswordLabel,
          enabled: !widget.busy,
          choosing: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _complete ? _submit() : null,
        ),
        SignInError(widget.problem),
        if (widget.busy)
          const StepBusy()
        else
          FilledButton(
            key: SignInPage.savePasswordKey,
            onPressed: _complete ? _submit : null,
            child: Text(strings.savePasswordButton),
          ),
      ],
    );
  }
}
