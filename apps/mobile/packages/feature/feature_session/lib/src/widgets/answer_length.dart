import 'package:contract/contract.dart';
import 'package:feature_session/src/l10n/session_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// How much room [answer] has left before the agent refuses it
/// ([maxAnswerLength]). Silent until the answer nears the limit, then counts
/// down, then says how far over it is — the input disables its submit on
/// [AnswerX.fits], so an answer the agent would refuse is never sent and the
/// user is never stuck resending it.
///
/// The count is the agent's own measure, so a line break or an emoji counts
/// as two; close enough to "characters" to act on, and exact where it
/// matters, at the limit.
class const AnswerLength({required final Answer answer, super.key})
    extends StatelessWidget {
  static const noteKey = Key('answer_length.note');

  /// The count stays hidden below this, so short answers carry no clutter.
  static const shownFrom = maxAnswerLength * 9 ~/ 10;

  @override
  Widget build(BuildContext context) {
    final length = answer.wireLength;
    if (length < shownFrom) {
      return const SizedBox.shrink();
    }
    final strings = SessionLocalizations.of(context);
    final theme = Theme.of(context);
    final fits = length <= maxAnswerLength;
    return Semantics(
      liveRegion: true,
      child: Text(
        fits
            ? strings.answerLengthLeft(maxAnswerLength - length)
            : strings.answerLengthOver(length - maxAnswerLength),
        key: noteKey,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fits
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.error,
        ),
      ),
    );
  }
}
