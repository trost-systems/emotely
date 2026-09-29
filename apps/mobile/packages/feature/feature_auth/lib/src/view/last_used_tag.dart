import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// A small pill on the top edge of the button last used to sign in on
/// this phone (#204): a reminder of the way in, since most people forget
/// which one they picked.
///
/// The pill is laid out above [child], not over it, and only its lower
/// edge overlaps the button: at any text size it pushes the button down
/// rather than growing into it or into the button above. Screen readers
/// skip it; each button says "last used" in its own label instead
/// (`AuthLocalizations.lastUsedButton`), so the words arrive with the button
/// they describe.
class const LastUsedTag({required final Widget child, super.key})
    extends StatelessWidget {
  /// How far the pill reaches down over the button's edge.
  static const _overlap = 10.0;

  /// From the button's end edge to the pill's, as in the design.
  static const _inset = 18.0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    // Laid out bottom-up so the pill, the later child, paints over the
    // button it overlaps.
    verticalDirection: VerticalDirection.up,
    children: [
      child,
      Transform.translate(
        offset: const Offset(0, _overlap),
        child: const Padding(
          padding: EdgeInsetsDirectional.only(end: _inset),
          child: IgnorePointer(child: ExcludeSemantics(child: _Pill())),
        ),
      ),
    ],
  );
}

class const _Pill() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: theme.colorScheme.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Text(
          context.l10n.lastUsedTag,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
