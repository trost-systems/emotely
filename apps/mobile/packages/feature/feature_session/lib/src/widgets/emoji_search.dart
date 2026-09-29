import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:feature_session/src/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The emoji picker's search, in place of the picker's own (#230).
///
/// The picker builds its search field and back arrow from
/// `package:flutter/material.dart`, whose widgets look for that library's
/// `Material` above them; the sheet provides a `material_ui` one, so a
/// debug build failed as soon as search opened. These two are `material_ui`
/// widgets, so the sheet's `Material` is the one they need, and they speak
/// the session's language. The results stay the picker's own emoji cells,
/// inside the picker's own container, which gives them the `Material` they
/// tap through.
///
/// The constructor matches `SearchViewConfig.customSearchView`, so it is
/// the builder itself.
class const EmojiSearch(
  super.config,
  super.state,
  super.showEmojiView, {
  super.key,
}) extends SearchView {
  @override
  State<EmojiSearch> createState() => _EmojiSearchState();
}

class _EmojiSearchState() extends SearchViewState<EmojiSearch> {
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return LayoutBuilder(
      builder: (context, constraints) {
        final emojiSize = config.emojiViewConfig.getEmojiSize(
          constraints.maxWidth,
        );
        final boxSize = config.emojiViewConfig.getEmojiBoxSize(
          constraints.maxWidth,
        );
        return ColoredBox(
          color: config.searchViewConfig.backgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmojiContainer(
                color: Colors.transparent,
                buttonMode: config.emojiViewConfig.buttonMode,
                child: SizedBox(
                  height: boxSize + 8,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    scrollDirection: Axis.horizontal,
                    itemCount: results.length,
                    itemBuilder: (_, index) =>
                        buildEmoji(results[index], emojiSize, boxSize),
                  ),
                ),
              ),
              _SearchField(
                onBack: widget.showEmojiView,
                onChanged: onTextInputChanged,
                focusNode: focusNode,
                iconColor: config.searchViewConfig.buttonIconColor,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The back arrow and the field the search words go into.
class const _SearchField({
  required final VoidCallback onBack,
  required final ValueChanged<String> onChanged,
  required final FocusNode focusNode,
  required final Color iconColor,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: strings.emojiSearchBackTooltip,
          color: iconColor,
          icon: const Icon(Icons.arrow_back),
        ),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: strings.emojiSearchHint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}
