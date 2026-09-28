import 'dart:async';

import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/auth_localizations.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_bloc.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:feature_auth/src/view/sign_in_error.dart';
import 'package:feature_auth/src/view/sign_in_heading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// The account, at the last possible moment (#204, ADR 0019): as the last
/// step of onboarding ([SignInMode.signUp], "Almost there, {name}") or
/// behind "I have an account" ([SignInMode.signIn], "Welcome back").
///
/// Apple (on iOS) and Google first, in one step each; then an email code in
/// two steps: the email, then the six-digit code Supabase sent to it.
/// Nothing to remember, nothing to leave the app for. The second step is a
/// password instead for the accounts the bloc knows to ask one of (the app
/// stores' reviewers). From sign-in, an email code never creates an
/// account.
class const SignInPage({final SignInMode mode = SignInMode.signIn, super.key})
    extends StatelessWidget {
  static const emailKey = Key('sign_in_page.email');
  static const sendCodeKey = Key('sign_in_page.send_code');
  static const codeKey = Key('sign_in_page.code');
  static const signInKey = Key('sign_in_page.sign_in');
  static const passwordKey = Key('sign_in_page.password');
  static const passwordSignInKey = Key('sign_in_page.password_sign_in');
  static const changeEmailKey = Key('sign_in_page.change_email');
  static const errorKey = Key('sign_in_page.error');
  static const privacyNoticeKey = Key('sign_in_page.privacy_notice');
  static const backKey = Key('sign_in_page.back');
  static const headingKey = Key('sign_in_page.heading');
  static const googleKey = ProviderButtons.googleKey;
  static const appleKey = ProviderButtons.appleKey;

  @override
  Widget build(BuildContext context) {
    final navigator = GetIt.I<SignInNavigator>();
    void leave() => navigator.leave(context, mode);
    // The screen is where the redirect put the user, with nothing under it
    // to pop to: back, by gesture or by arrow, is the flow's way back.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : leave(),
      child: BlocProvider(
        create: (_) => GetIt.I<LastSignInBloc>(),
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(key: backKey, onPressed: leave),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  // The providers' buttons make the first step taller than a
                  // small phone in landscape, or at a large text size.
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 32,
                        children: [
                          SignInHeading(
                            mode: mode,
                            name: navigator.signUpName(),
                          ),
                          _Step(mode: mode),
                        ],
                      ),
                    ),
                  ),
                  // Reachable before an account exists, and before an address
                  // has been typed: Play's disclosure expectations are
                  // stricter than Apple's about a policy that lives only
                  // behind a menu.
                  TextButton(
                    key: privacyNoticeKey,
                    onPressed: () => unawaited(openPrivacyNotice()),
                    child: Text(
                      AuthLocalizations.of(context).privacyNoticeButton,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one step the sign-in state asks for.
class const _Step({required final SignInMode mode}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) => switch (state) {
      AuthSignedOut(:final problem) => _EmailStep(mode: mode, problem: problem),
      AuthRequestingCode() => _EmailStep(mode: mode, busy: true),
      AuthSigningInWith() => _EmailStep(mode: mode, busy: true),
      AuthCodeSent(:final email, :final problem) => _CodeStep(
        email: email,
        problem: problem,
      ),
      AuthVerifying(:final email) => _CodeStep(email: email, busy: true),
      AuthPasswordRequired(:final email, :final problem) => _PasswordStep(
        email: email,
        problem: problem,
      ),
      AuthCheckingPassword(:final email) => _PasswordStep(
        email: email,
        busy: true,
      ),
      AuthSignedIn() => const SizedBox.shrink(),
    },
  );
}

class const _EmailStep({
  required final SignInMode mode,
  final SignInProblem? problem,
  final bool busy = false,
}) extends StatefulWidget {
  @override
  State<_EmailStep> createState() => _EmailStepState();
}

class _EmailStepState() extends State<_EmailStep> {
  final _controller = TextEditingController();

  String get _email => _controller.text.trim();

  // Good enough to stop typos before a round trip; Supabase validates the
  // address for real.
  bool get _plausible => _email.contains('@') && _email.contains('.');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
      TextField(
        key: SignInPage.emailKey,
        controller: _controller,
        enabled: !widget.busy,
        autofillHints: const [AutofillHints.email],
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: AuthLocalizations.of(context).emailLabel,
          hintText: AuthLocalizations.of(context).emailHint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      SignInError(widget.problem),
      if (widget.busy)
        const _Busy()
      else
        _SendCode(
          onPressed: _plausible
              ? () => context.read<AuthBloc>().add(
                  AuthEvent.emailSubmitted(
                    _email,
                    createAccount: widget.mode == SignInMode.signUp,
                  ),
                )
              : null,
        ),
    ],
  );
}

/// The email's way on, tagged when the email was the way in last time.
class const _SendCode({required final VoidCallback? onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = AuthLocalizations.of(context);
    final label = strings.sendCodeButton;
    final lastUsed =
        context.watch<LastSignInBloc>().state == SignInOption.emailCode;
    final button = FilledButton.tonal(
      key: SignInPage.sendCodeKey,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onPressed,
      child: Text(
        label,
        semanticsLabel: lastUsed ? strings.lastUsedButton(label) : null,
      ),
    );
    return lastUsed ? LastUsedTag(child: button) : button;
  }
}

class const _CodeStep({
  required final String email,
  final SignInProblem? problem,
  final bool busy = false,
}) extends StatefulWidget {
  static const codeLength = 6;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState() extends State<_CodeStep> {
  final _controller = TextEditingController();

  String get _code => _controller.text.trim();

  bool get _complete =>
      _code.length == _CodeStep.codeLength &&
      _code.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        AuthLocalizations.of(context).codeSentMessage(widget.email),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      TextField(
        key: SignInPage.codeKey,
        controller: _controller,
        enabled: !widget.busy,
        autofillHints: const [AutofillHints.oneTimeCode],
        keyboardType: TextInputType.number,
        maxLength: _CodeStep.codeLength,
        decoration: InputDecoration(
          labelText: AuthLocalizations.of(context).codeLabel,
        ),
        onChanged: (_) => setState(() {}),
      ),
      SignInError(widget.problem),
      if (widget.busy)
        const _Busy()
      else
        _StepActions(
          signInKey: SignInPage.signInKey,
          onSignIn: _complete
              ? () =>
                    context.read<AuthBloc>().add(AuthEvent.codeSubmitted(_code))
              : null,
        ),
    ],
  );
}

/// The password for an account that signs in with one. Obscured, never
/// suggested or corrected, and submitted from the keyboard's "done" too.
class const _PasswordStep({
  required final String email,
  final SignInProblem? problem,
  final bool busy = false,
}) extends StatefulWidget {
  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState() extends State<_PasswordStep> {
  final _controller = TextEditingController();

  String get _password => _controller.text;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() =>
      context.read<AuthBloc>().add(AuthEvent.passwordSubmitted(_password));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        AuthLocalizations.of(context).passwordPrompt(widget.email),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      TextField(
        key: SignInPage.passwordKey,
        controller: _controller,
        enabled: !widget.busy,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: AuthLocalizations.of(context).passwordLabel,
        ),
        onChanged: (_) => setState(() {}),
        // The field is disabled while a check is in flight, so "done"
        // cannot submit twice.
        onSubmitted: (_) => _password.isEmpty ? null : _submit(),
      ),
      SignInError(widget.problem),
      if (widget.busy)
        const _Busy()
      else
        _StepActions(
          signInKey: SignInPage.passwordSignInKey,
          onSignIn: _password.isEmpty ? null : _submit,
        ),
    ],
  );
}

/// Sign in with what the step asked for, or go back for a different email.
class const _StepActions({
  required final Key signInKey,
  required final VoidCallback? onSignIn,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      FilledButton(
        key: signInKey,
        onPressed: onSignIn,
        child: Text(AuthLocalizations.of(context).signInButton),
      ),
      TextButton(
        key: SignInPage.changeEmailKey,
        onPressed: () => context.read<AuthBloc>().add(
          const AuthEvent.emailChangeRequested(),
        ),
        child: Text(AuthLocalizations.of(context).changeEmailButton),
      ),
    ],
  );
}

class const _Busy() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
