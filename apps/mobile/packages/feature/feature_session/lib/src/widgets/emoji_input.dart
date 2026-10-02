import 'dart:async';

import 'package:contract/contract.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:feature_session/src/l10n/l10n.dart';
import 'package:feature_session/src/widgets/emoji_search.dart';
import 'package:feature_session/src/widgets/submit_button.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

/// A row of emoji tiles, as the legacy app had it; submits [Answer.emoji]
/// in slot order.
///
/// There is always one empty slot at the end: tapping it opens the picker
/// and a chosen emoji fills it, so the row grows as emoji are picked.
/// Tapping a filled slot reopens the picker, to change it or clear it.
class const EmojiInput({
  required final ValueChanged<Answer> onSubmit,
  super.key,
}) extends StatefulWidget {
  static const submitKey = Key('emoji_input.submit');
  static const clearKey = Key('emoji_input.clear');

  /// Key of the [index]th slot; the last one is always empty.
  static Key slotKey(int index) => Key('emoji_input.slot.$index');

  @override
  State<EmojiInput> createState() => _EmojiInputState();
}

class _EmojiInputState() extends State<EmojiInput> {
  final _emoji = <String>[];

  Future<void> _open(int index) async {
    final current = index < _emoji.length ? _emoji[index] : null;
    final pick = await showModalBottomSheet<_EmojiPick>(
      context: context,
      builder: (_) => _EmojiSheet(canClear: current != null),
    );
    setState(() {
      switch (pick) {
        case null:
          break;
        case _Cleared():
          _emoji.removeAt(index);
        case _Picked(:final emoji) when current == null:
          _emoji.add(emoji);
        case _Picked(:final emoji):
          _emoji[index] = emoji;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (index, emoji) in _emoji.indexed)
            _Slot(
              key: EmojiInput.slotKey(index),
              emoji: emoji,
              onTap: () => unawaited(_open(index)),
            ),
          _Slot(
            key: EmojiInput.slotKey(_emoji.length),
            emoji: null,
            onTap: () => unawaited(_open(_emoji.length)),
          ),
        ],
      ),
      SubmitButton(
        buttonKey: EmojiInput.submitKey,
        onPressed: _emoji.isEmpty
            ? null
            : () => widget.onSubmit(Answer.emoji(List.of(_emoji))),
      ),
    ],
  );
}

/// One tile: a picked emoji, or the outlined "+" that picks the next.
class const _Slot({
  required final String? emoji,
  required final VoidCallback onTap,
  super.key,
}) extends StatelessWidget {
  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: emoji ?? context.l10n.emojiPickLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          width: _size,
          height: _size,
          decoration: ShapeDecoration(
            color: emoji == null ? null : scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: emoji == null
                  ? BorderSide(color: scheme.outline, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Center(
            child: ExcludeSemantics(
              child: emoji == null
                  ? Icon(Icons.add, color: scheme.onSurface)
                  : Text(emoji!, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the picker sheet came back with; dismissing it returns nothing.
sealed class const _EmojiPick();

class const _Picked(final String emoji) extends _EmojiPick;

class const _Cleared() extends _EmojiPick;

/// The legacy app's picker, themed like the rest of the screen. It opens on
/// the smileys rather than on recents, which are empty the first time.
class const _EmojiSheet({required final bool canClear})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    // The picker still builds on package:flutter/material.dart, so the
    // bridge hands it this app's material_ui theme and localizations; the
    // deprecation only says the bridge goes once packages have moved over,
    // at which point this wrapper goes with it.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: SafeArea(
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => navigator.pop(_Picked(emoji.emoji)),
          onBackspacePressed: canClear
              ? () => navigator.pop(const _Cleared())
              : null,
          config: _config(context),
        ),
      ),
    );
  }

  /// The picker in this screen's colors and language: search on top,
  /// categories below, and the clear button only when there is an emoji to
  /// clear. The locale picks the emoji names search matches against, so a
  /// German hint finds German words.
  Config _config(BuildContext context) {
    final strings = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = scheme.surfaceContainerLow;
    return Config(
      locale: Localizations.localeOf(context),
      viewOrderConfig: const ViewOrderConfig(
        top: EmojiPickerItem.searchBar,
        bottom: EmojiPickerItem.categoryBar,
      ),
      emojiViewConfig: EmojiViewConfig(
        backgroundColor: background,
        columns: 7,
        // Issue: https://github.com/flutter/flutter/issues/28894
        emojiSizeMax:
            28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1),
        buttonMode: defaultTargetPlatform == TargetPlatform.iOS
            ? ButtonMode.CUPERTINO
            : ButtonMode.MATERIAL,
        noRecents: Text(
          strings.emojiNoRecents,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      categoryViewConfig: CategoryViewConfig(
        initCategory: Category.SMILEYS,
        backgroundColor: background,
        indicatorColor: scheme.primary,
        iconColorSelected: scheme.primary,
        iconColor: scheme.outline,
        dividerColor: background,
      ),
      bottomActionBarConfig: BottomActionBarConfig(
        backgroundColor: background,
        buttonColor: background,
        buttonIconColor: scheme.primary,
        showBackspaceButton: canClear,
      ),
      customBackspaceIcon: Icon(
        Icons.clear,
        key: EmojiInput.clearKey,
        color: scheme.error,
        semanticLabel: strings.emojiClearLabel,
      ),
      // Search is ours: the picker's own fails without a legacy Material.
      searchViewConfig: SearchViewConfig(
        backgroundColor: background,
        buttonIconColor: scheme.primary,
        customSearchView: EmojiSearch.new,
      ),
    );
  }
}
