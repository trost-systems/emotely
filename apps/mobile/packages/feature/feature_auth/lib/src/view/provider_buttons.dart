import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/auth_localizations.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The quickest ways in, above the email: Continue with Apple (iOS only)
/// above Google. Each is the provider's own button, as its
/// guidelines require, and Apple's is no smaller than Google's. The one
/// last used on this phone, if either, wears the "Last used" tag.
class const ProviderButtons({
  super.key,
  final bool enabled = true,
  final SignInOption? lastUsed,
}) extends StatelessWidget {
  static const googleKey = Key('sign_in_page.google');
  static const appleKey = Key('sign_in_page.apple');

  VoidCallback? _select(BuildContext context, IdentityProvider provider) =>
      enabled
      ? () => context.read<AuthBloc>().add(AuthEvent.providerSelected(provider))
      : null;

  @override
  Widget build(BuildContext context) {
    final apple = _AppleButton(
      onPressed: _select(context, IdentityProvider.apple),
      lastUsed: lastUsed == SignInOption.apple,
    );
    // The tag sits over the button's own box, never inside Google's image.
    final google = GoogleSignInButton(
      key: googleKey,
      onPressed: _select(context, IdentityProvider.google),
      lastUsed: lastUsed == SignInOption.google,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        // Android has no native Apple sheet, and the rule that asks for
        // Apple wherever Google is offered is the App Store's.
        if (defaultTargetPlatform == TargetPlatform.iOS)
          if (apple.lastUsed) LastUsedTag(child: apple) else apple,
        Center(child: google.lastUsed ? LastUsedTag(child: google) : google),
      ],
    );
  }
}

/// Google's own rendering of its button — the standard "G" may not be
/// redrawn or recoloured — from Google's sign-in assets (Android + Web,
/// pill, light or dark with the theme).
///
/// The image says "Sign in with Google" in English whatever the locale;
/// only what a screen reader announces follows the user's language (#217).
class const GoogleSignInButton({
  required final VoidCallback? onPressed,
  super.key,
  final bool lastUsed = false,
}) extends StatelessWidget {
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
    final strings = AuthLocalizations.of(context);
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
                  semanticLabel: lastUsed
                      ? strings.lastUsedButton(strings.googleButton)
                      : strings.googleButton,
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
///
/// Its label is set here, as one node with the tap, so that a "Last used"
/// tag can be part of it; the plugin's button has no say in its semantics.
class const _AppleButton({
  required final VoidCallback? onPressed,
  final bool lastUsed = false,
}) extends StatelessWidget {
  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final strings = AuthLocalizations.of(context);
    final label = strings.appleButton;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      label: lastUsed ? strings.lastUsedButton(label) : label,
      excludeSemantics: true,
      child: SignInWithAppleButton(
        key: ProviderButtons.appleKey,
        text: label,
        onPressed: onPressed,
        height: height,
        borderRadius: const BorderRadius.all(Radius.circular(height / 2)),
        style: switch (Theme.of(context).brightness) {
          Brightness.dark => SignInWithAppleButtonStyle.white,
          Brightness.light => SignInWithAppleButtonStyle.black,
        },
      ),
    );
  }
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
          AuthLocalizations.of(context).orWithEmail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
