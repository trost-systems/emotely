import 'package:agent_client/agent_client.dart';
import 'package:contract/contract.dart';
import 'package:design_system/src/color_text.dart';
import 'package:material_ui/material_ui.dart';

/// The finished journal entry under [title]: the agent's summary, then each
/// question with the answer that was recorded for it. The feature showing it
/// words the title in the user's language; design_system holds no strings
/// of its own (ADR 0020).
class const EntryView({
  required final String title,
  required final JournalEntry entry,
  required final Map<String, AskQuestion> questions,
  super.key,
}) extends StatelessWidget {
  static const summaryKey = Key('entry_view.summary');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(entry.summary, key: summaryKey, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        for (final MapEntry(key: questionId, value: answer)
            in entry.answers.entries) ...[
          Text(
            questions[questionId]?.question ?? questionId,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          AnswerText(answer: answer),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// One recorded answer, rendered per type.
class const AnswerText({required final Answer answer, super.key})
    extends StatelessWidget {
  static const _converter = HexColorConverter();

  @override
  Widget build(BuildContext context) => switch (answer) {
    ColorAnswer(:final value) => ColorText(
      value.map(_converter.toJson).join(' '),
    ),
    EmojiAnswer(:final value) => Text(value.join(' ')),
    LongtextAnswer(:final value) => Text(value),
    RatingAnswer(:final value) => Text('$value / $ratingMax'),
    TextListAnswer(:final value) => Text(value.map((v) => '• $v').join('\n')),
  };
}
