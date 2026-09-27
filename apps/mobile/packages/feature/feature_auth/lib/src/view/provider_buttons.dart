import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The quickest ways in, above the email: Continue with Apple (iOS only)
/// above Google. Each is the provider's own button, as its
/// guidelines require, and Apple's is no smaller than Google's.
class const ProviderButtons({super.key, final bool enabled = true})
    extends StatelessWidget {
  static const googleKey = Key('sign_in_page.google');
  static const appleKey = Key('sign_in_page.apple');

  void _select(BuildContext context, IdentityProvider provider) =>
      context.read<AuthBloc>().add(AuthEvent.providerSelected(provider));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      // Android has no native Apple sheet, and the rule that asks for Apple
      // wherever Google is offered is the App Store's.
      if (defaultTargetPlatform == TargetPlatform.iOS)
        _AppleButton(
          onPressed: enabled
              ? () => _select(context, IdentityProvider.apple)
              : null,
        ),
      Center(
        child: GoogleSignInButton(
          key: googleKey,
          onPressed: enabled
              ? () => _select(context, IdentityProvider.google)
              : null,
        ),
      ),
    ],
  );
}

/// Google's own rendering of its button — the standard "G" may not be
/// redrawn or recoloured — from Google's sign-in assets (Android + Web,
/// pill, light or dark with the theme).
class const GoogleSignInButton({
  required final VoidCallback? onPressed,
  super.key,
}) extends StatelessWidget {
  static const label = 'Sign in with Google';

  /// The assets' own size at 1x: fixed, so the button takes its place
  /// before the image has decoded, and never scales the "G".
  static const size = Size(180, 40);

  /// Around the 40-point image, so the tap target reaches Android's 48.
  static const _touchPadding = EdgeInsets.symmetric(vertical: 4);

  @override
  Widget build(BuildContext context) {
    final theme = switch (Theme.of(context).brightness) {
      Brightness.dark => 'dark',
      Brightness.light => 'light',
    };
    // One node for assistive technology: the ink well's tap and the
    // image's label, announced as a button.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: Opacity(
          opacity: onPressed == null ? 0.38 : 1,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: _touchPadding,
                child: Image.asset(
                  'assets/google/$theme.png',
                  package: 'feature_auth',
                  width: size.width,
                  height: size.height,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple's button, black on a light theme and white on a dark one, as tall
/// as Google's tap target (Android's 48, so never smaller than Google's, as
/// Apple asks) and pill-shaped like the email step's own buttons.
class const _AppleButton({required final VoidCallback? onPressed})
    extends StatelessWidget {
  static const height = 48.0;
  static const label = 'Continue with Apple';

  @override
  Widget build(BuildContext context) => SignInWithAppleButton(
    key: ProviderButtons.appleKey,
    text: label,
    onPressed: onPressed,
    height: height,
    borderRadius: const BorderRadius.all(Radius.circular(height / 2)),
    style: switch (Theme.of(context).brightness) {
      Brightness.dark => SignInWithAppleButtonStyle.white,
      Brightness.light => SignInWithAppleButtonStyle.black,
    },
  );
}

/// A rule with "or with your email" in it, between the providers and the
/// email.
class const OrWithEmail({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        const Expanded(child: Divider()),
        Text(
          'or with your email',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
