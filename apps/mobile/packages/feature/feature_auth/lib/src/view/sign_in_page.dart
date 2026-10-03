import 'dart:async';

import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_bloc.dart';
import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/code_steps.dart';
import 'package:feature_auth/src/view/email_form.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:feature_auth/src/view/sign_in_heading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// The account, at the last possible moment (#204, ADR 0019): as the last
/// step of onboarding ([SignInMode.signUp], "Almost there, {name}") or
/// behind "I have an account" ([SignInMode.signIn], "Welcome back").
///
/// Apple (on iOS) and Google first, in one step each; then the email and a
/// password ([EmailForm]). A new account opens once the code mailed to its
/// address is typed in, and a forgotten password is reset with a mailed
/// code and a new password ([CodeStep]) — codes, never links, so nothing
/// leaves the app (#187).
class const SignInPage({final SignInMode mode = SignInMode.signIn, super.key})
    extends StatelessWidget {
  static const emailKey = Key('sign_in_page.email');
  static const passwordKey = Key('sign_in_page.password');
  static const submitKey = Key('sign_in_page.submit');
  static const forgotPasswordKey = Key('sign_in_page.forgot_password');
  static const codeKey = Key('sign_in_page.code');
  static const confirmKey = Key('sign_in_page.confirm');
  static const newPasswordKey = Key('sign_in_page.new_password');
  static const savePasswordKey = Key('sign_in_page.save_password');
  static const resendCodeKey = Key('sign_in_page.resend_code');
  static const codeResentKey = Key('sign_in_page.code_resent');
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
        child: _MailLanguage(
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
                      onPressed: () => unawaited(
                        openPrivacyNotice(Localizations.localeOf(context)),
                      ),
                      child: Text(context.l10n.privacyNoticeButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells the auth bloc the language the screen is shown in, when it first
/// shows and whenever that changes: the language of the account's mails.
/// The one place that knows it, since the bloc lives above the app's
/// localizations.
class const _MailLanguage({required final Widget child})
    extends StatefulWidget {
  @override
  State<_MailLanguage> createState() => _MailLanguageState();
}

class _MailLanguageState() extends State<_MailLanguage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<AuthBloc>().add(
      AuthEvent.languageShown(Localizations.localeOf(context).languageCode),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The one step the sign-in state asks for.
class const _Step({required final SignInMode mode}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) => switch (state) {
      AuthSignedOut(:final email, :final problem) => EmailForm(
        mode: mode,
        email: email,
        problem: problem,
      ),
      AuthChecking(:final email) => EmailForm(
        mode: mode,
        email: email,
        busy: true,
      ),
      AuthSigningInWith() => EmailForm(mode: mode, busy: true),
      AuthCodeSent(
        :final email,
        :final purpose,
        :final problem,
        :final resent,
      ) =>
        CodeStep(
          email: email,
          purpose: purpose,
          problem: problem,
          resent: resent,
        ),
      AuthCheckingCode(:final email, :final purpose) => CodeStep(
        email: email,
        purpose: purpose,
        busy: true,
      ),
      AuthNewPasswordRequired(:final email, :final problem) => NewPasswordStep(
        email: email,
        problem: problem,
      ),
      AuthSavingPassword(:final email) => NewPasswordStep(
        email: email,
        busy: true,
      ),
      AuthSignedIn() => const SizedBox.shrink(),
    },
  );
}
