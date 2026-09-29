import 'package:feature_journal/src/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The part of the day a greeting names, by the phone's local hour: morning
/// from 5 to before 12, afternoon from 12 to before 18, and evening the
/// rest — a late night is still "evening" to someone reflecting on it.
enum PartOfDay() {
  morning,
  afternoon,
  evening;

  static PartOfDay at(DateTime time) => switch (time.hour) {
    >= 5 && < 12 => morning,
    >= 12 && < 18 => afternoon,
    _ => evening,
  };
}

/// "Good evening, Peter", or "Good evening" without a name, in the
/// language of [strings]. The part of the day is the messages' select key,
/// so the enum's names are the ARB files' cases; the name is the user's,
/// never translated.
String greeting(JournalLocalizations strings, PartOfDay part, String? name) =>
    name == null
    ? strings.greeting(part.name)
    : strings.greetingByName(part.name, name);

/// The top of the journal: today's date, and the user greeted by name
/// (#204).
class const JournalGreeting({
  required final DateTime now,
  final String? name,
  super.key,
}) extends StatelessWidget {
  static const titleKey = Key('journal_greeting.title');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          MaterialLocalizations.of(context).formatFullDate(now),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            greeting(context.l10n, PartOfDay.at(now), name),
            key: titleKey,
            // Never italic: it names the user.
            style: theme.textTheme.headlineMedium?.copyWith(
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
