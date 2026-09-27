import 'package:feature_auth/src/navigator.dart';
import 'package:feature_auth/src/view/sign_in_page.dart';
import 'package:material_ui/material_ui.dart';

/// "Almost there, {name}" and why an account, or "Welcome back".
class const SignInHeading({
  required final SignInMode mode,
  final String? name,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = switch (mode) {
      SignInMode.signUp => (
        SignInPage.signUpTitle(name),
        SignInPage.signUpBody,
      ),
      SignInMode.signIn => (SignInPage.signInTitle, null),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            key: SignInPage.headingKey,
            // Never italic: it names the user (#204).
            style: theme.textTheme.headlineMedium?.copyWith(
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
        if (body case final body?)
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
