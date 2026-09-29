import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleLogoPainter;

/// The quickest ways in, above the email: Continue with Apple (iOS only)
/// above Continue with Google, one [ProviderButton] each, the same size, so
/// Apple's is no smaller than Google's and Google's no less prominent than
/// Apple's. The one last used on this phone, if either, wears the "Last
/// used" tag.
class const ProviderButtons({
  super.key,
  final bool enabled = true,
  final SignInOption? lastUsed,
}) extends StatelessWidget {
  static const googleKey = Key('sign_in_page.google');
  static const appleKey = Key('sign_in_page.apple');

  Widget _button(BuildContext context, IdentityProvider provider, Key key) {
    final tagged = lastUsed == provider.option;
    final button = ProviderButton(
      key: key,
      provider: provider,
      lastUsed: tagged,
      onPressed: enabled
          ? () => context.read<AuthBloc>().add(
              AuthEvent.providerSelected(provider),
            )
          : null,
    );
    // The tag sits over the button's edge, the same way for both.
    return tagged ? LastUsedTag(child: button) : button;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      // Android has no native Apple sheet, and the rule that asks for
      // Apple wherever Google is offered is the App Store's.
      if (defaultTargetPlatform == TargetPlatform.iOS)
        _button(context, IdentityProvider.apple, appleKey),
      _button(context, IdentityProvider.google, googleKey),
    ],
  );
}

/// One provider's way in, drawn by us so that its title speaks the app's
/// language (#217), within what both providers allow a custom button:
///
/// - **Only the provider's own title**, localized: "Continue with Apple",
///   "Continue with Google", in the words Apple and Google use themselves.
/// - **Only the provider's own logo**, leading: Google's "G" from its
///   branding assets at its 20 points, never scaled or recoloured; Apple's
///   logo as `sign_in_with_apple` paints it for Apple's own button.
/// - **White, with Google's grey outline, on either theme.** The "G" must
///   sit on white, and Apple allows black or white with logo and title in
///   the other; a black button may not sit on a dark background, a white
///   one may. Google's light theme is the one both allow.
/// - **The app's shape and font**: a pill as tall as the email's button
///   below it, its title in the app's typeface at the proportion Apple
///   sets for any font, 43% of the height.
class const ProviderButton({
  required final IdentityProvider provider,
  required final VoidCallback? onPressed,
  super.key,
  final bool lastUsed = false,
}) extends StatelessWidget {
  /// As tall as the sign-in screen's own buttons; Apple asks for at least
  /// 30 and recommends 44, Google's own is 40.
  static const height = 52.0;

  /// Apple's proportion of title to button, for any font.
  static const _titleSize = height * 0.43;

  /// Google's light theme: the fill the "G" needs, and its outline.
  static const _fill = Color(0xFFFFFFFF);
  static const _outline = Color(0xFF747775);

  /// Between the logo and the title, and inside the ends of the pill:
  /// Google's padding for iOS, the larger of its two.
  static const _gap = 12.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  /// The title's colour: black with Apple's black logo, as Apple asks,
  /// and Google's own near-black for its label.
  Color get _ink => switch (provider) {
    IdentityProvider.apple => const Color(0xFF000000),
    IdentityProvider.google => const Color(0xFF1F1F1F),
  };

  Widget get _logo => switch (provider) {
    IdentityProvider.apple => _AppleLogo(color: _ink, size: _titleSize),
    IdentityProvider.google => const _GoogleG(),
  };

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final title = switch (provider) {
      IdentityProvider.apple => strings.appleButton,
      IdentityProvider.google => strings.googleButton,
    };
    return Opacity(
      opacity: onPressed == null ? 0.38 : 1,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(height),
          padding: _padding,
          shape: const StadiumBorder(),
          side: const BorderSide(color: _outline),
          // The same while disabled: the fade above says so, and neither
          // provider allows its colours to change.
          backgroundColor: _fill,
          disabledBackgroundColor: _fill,
          foregroundColor: _ink,
          disabledForegroundColor: _ink,
          textStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontSize: _titleSize),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: _gap,
          children: [
            _logo,
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                // One node with the tap: the title, and the tag's words when
                // it wears the tag.
                semanticsLabel: lastUsed ? strings.lastUsedButton(title) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google's standard "G", cropped pixel for pixel from the icon-only light
/// button in Google's branding assets (the 20-point "G" of its 40-point
/// square), 2.0x-4.0x beside it. A bitmap: the "G" is a conic gradient,
/// which no vector renderer in the app draws.
class const _GoogleG() extends StatelessWidget {
  static const size = 20.0;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/google/g.png',
    package: 'feature_auth',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// Apple's logo, as `sign_in_with_apple` draws it on Apple's own button:
/// as tall as the title's font size, and lifted by 4/44 of the button's
/// height so it sits level with the title.
class const _AppleLogo({required final Color color, required final double size})
    extends StatelessWidget {
  /// The logo's own width to height.
  static const _aspect = 25 / 31;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: ProviderButton.height * 4 / 44),
    child: SizedBox(
      width: size * _aspect,
      height: size,
      child: CustomPaint(painter: AppleLogoPainter(color: color)),
    ),
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
          context.l10n.orWithEmail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
