import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/auth_localizations.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:material_ui/material_ui.dart';

/// Why the step's last try failed, in the user's language, or nothing. The
/// bloc hands over a [SignInProblem], never words (ADR 0020).
class const SignInError(final SignInProblem? problem, {super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (problem) {
    null => const SizedBox.shrink(),
    final problem => Text(
      _messageFor(problem, AuthLocalizations.of(context)),
      key: SignInPage.errorKey,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  };

  static String _messageFor(SignInProblem problem, AuthLocalizations strings) =>
      switch (problem) {
        SignInProblem.tooManyCodes => strings.tooManyCodesMessage,
        SignInProblem.tooManyAttempts => strings.tooManyAttemptsMessage,
        SignInProblem.couldNotSend => strings.couldNotSendMessage,
        SignInProblem.wrongCode => strings.wrongCodeMessage,
        SignInProblem.wrongPassword => strings.wrongPasswordMessage,
        SignInProblem.unreachable => strings.unreachableMessage,
        SignInProblem.noAccount => strings.noAccountMessage,
        SignInProblem.providerFailed => strings.providerFailedMessage,
      };
}
