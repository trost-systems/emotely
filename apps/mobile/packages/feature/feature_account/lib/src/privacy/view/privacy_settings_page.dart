import 'dart:async';

import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/consent/consent_text.dart';
import 'package:feature_account/src/navigator.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// Privacy settings: the two consents the app holds, one card and one
/// switch each (#204).
///
/// - **Journal sessions** is the explicit consent a session needs (ADR
///   0014). Turning it off asks first, then withdraws; turning it on opens
///   the full consent screen, because an explicit Art. 9 consent needs its
///   wording read, not a flick of a switch.
/// - **Usage analytics** flips both ways at once: allowing and refusing
///   are equally easy.
///
/// Reads the [ConsentBloc] and the [UsageAnalyticsBloc] its route provides.
class const PrivacySettingsPage({super.key}) extends StatelessWidget {
  static const journalKey = Key('privacy_settings.journal');
  static const journalRetryKey = Key('privacy_settings.journal_retry');
  static const usageAnalyticsKey = Key('privacy_settings.usage_analytics');
  static const confirmKey = Key('privacy_settings.confirm');
  static const cancelKey = Key('privacy_settings.cancel');
  static const noticeKey = Key('privacy_settings.notice');

  static const title = 'Privacy settings';

  static const journalLabel = 'Journal sessions';
  static const journalExplanation =
      'Your answers go to a language model to guide each session. Never '
      'used for training, never kept by the provider.';
  static const journalOnNote =
      'Turning this off stops new sessions; your entries stay.';
  static const journalOffNote =
      'Off: no new session can start. Turning it on shows you what you '
      'agree to first.';
  static const journalRetryLabel = 'Check again';

  /// When journal consent was given, on the device's calendar: "Given 20
  /// Sep 2026." English month names, like every other string here, until
  /// the app is localised.
  static String given(DateTime at) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = at.toLocal();
    return 'Given ${local.day} ${months[local.month - 1]} ${local.year}.';
  }

  static const confirmTitle = 'Turn off journal sessions?';
  static const confirmMessage = 'New sessions stop; your entries stay.';
  static const confirmLabel = 'Turn off';
  static const cancelLabel = 'Cancel';

  static const usageAnalyticsLabel = 'Usage analytics';
  static const usageAnalyticsExplanation =
      'Taps, screens and crash reports, so I can see what helps and where '
      'people get stuck. Never what you write.';
  static const usageAnalyticsNote = 'Stored with PostHog in the EU.';

  static const noticeLabel = 'Read the privacy notice';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(title)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            const _JournalCard(),
            const _UsageAnalyticsCard(),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: noticeKey,
                onPressed: () => unawaited(openPrivacyNotice()),
                child: const Text(noticeLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One consent: its switch, what it covers, and a note underneath.
class const _PrivacyCard({
  required final Key switchKey,
  required final String label,
  required final bool value,
  required final ValueChanged<bool>? onChanged,
  required final String explanation,
  required final Widget note,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            SwitchListTile(
              key: switchKey,
              title: Text(label, style: theme.textTheme.titleLarge),
              value: value,
              onChanged: onChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                explanation,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: note,
            ),
          ],
        ),
      ),
    );
  }
}

/// A card's note in the small print, or in the error colour when it
/// reports something that did not work.
class const _Note(final String text, {final bool failed = false})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: failed
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class const _JournalCard() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<ConsentBloc, ConsentState>(
    builder: (context, state) => _PrivacyCard(
      switchKey: PrivacySettingsPage.journalKey,
      label: PrivacySettingsPage.journalLabel,
      // Consent stands until the server says it no longer does: while a
      // withdrawal is written, and after one that failed.
      value: switch (state) {
        ConsentKnown(:final granted) => granted,
        ConsentBusy() || ConsentWithdrawFailure() => true,
        _ => false,
      },
      onChanged: switch (state) {
        ConsentKnown() || ConsentWriteFailure() || ConsentWithdrawFailure() => (
          on,
        ) => unawaited(on ? _giveAgain(context) : _confirmWithdrawal(context)),
        // Nothing to switch while the answer is not in hand.
        ConsentUnknown() || ConsentBusy() || ConsentFailure() => null,
      },
      explanation: PrivacySettingsPage.journalExplanation,
      note: _JournalNote(state),
    ),
  );

  /// The consent screen on its own route, which the app shows (ADR 0015);
  /// once it closes, the server is asked again rather than trusted from
  /// before — the record is what counts.
  static Future<void> _giveAgain(BuildContext context) async {
    final consent = context.read<ConsentBloc>();
    await GetIt.I<AccountNavigator>().requestConsent(context);
    consent.add(const ConsentEvent.loaded(withDate: true));
  }

  /// Asks once more before sessions stop. The dialog sits above this
  /// screen, outside the bloc's scope, so the bloc is captured first.
  static Future<void> _confirmWithdrawal(BuildContext context) async {
    final consent = context.read<ConsentBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ConfirmWithdrawal(),
    );
    if (confirmed ?? false) {
      consent.add(const ConsentEvent.withdrawn());
    }
  }
}

/// What the journal card says under its switch, by where consent stands.
class const _JournalNote(final ConsentState state) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (state) {
    ConsentKnown(granted: true, :final since?) => _Note(
      '${PrivacySettingsPage.given(since)} '
      '${PrivacySettingsPage.journalOnNote}',
    ),
    ConsentKnown(granted: true) ||
    ConsentBusy() => const _Note(PrivacySettingsPage.journalOnNote),
    ConsentKnown(granted: false) ||
    ConsentWriteFailure() => const _Note(PrivacySettingsPage.journalOffNote),
    ConsentWithdrawFailure() => const _Note(
      withdrawFailureMessage,
      failed: true,
    ),
    ConsentUnknown() => const LinearProgressIndicator(),
    // A failed read says nothing about whether consent stands, so the
    // switch is off-limits; say so and offer to look again.
    ConsentFailure() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Note(consentUnknownMessage, failed: true),
        TextButton(
          key: PrivacySettingsPage.journalRetryKey,
          onPressed: () => context.read<ConsentBloc>().add(
            const ConsentEvent.loaded(withDate: true),
          ),
          child: const Text(PrivacySettingsPage.journalRetryLabel),
        ),
      ],
    ),
  };
}

/// "New sessions stop; your entries stay." Turning off is one confirmation
/// away, never more: withdrawal must be as easy as giving (Art. 7 (3)).
class const _ConfirmWithdrawal() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(PrivacySettingsPage.confirmTitle),
    content: const Text(PrivacySettingsPage.confirmMessage),
    actions: [
      TextButton(
        key: PrivacySettingsPage.cancelKey,
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(PrivacySettingsPage.cancelLabel),
      ),
      TextButton(
        key: PrivacySettingsPage.confirmKey,
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text(PrivacySettingsPage.confirmLabel),
      ),
    ],
  );
}

class const _UsageAnalyticsCard() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<UsageAnalyticsBloc, UsageAnalyticsState>(
        builder: (context, state) => _PrivacyCard(
          switchKey: PrivacySettingsPage.usageAnalyticsKey,
          label: PrivacySettingsPage.usageAnalyticsLabel,
          value: state == UsageAnalyticsState.allowed,
          onChanged: state == UsageAnalyticsState.unknown
              ? null
              : (on) => context.read<UsageAnalyticsBloc>().add(
                  on
                      ? const UsageAnalyticsEvent.allowed()
                      : const UsageAnalyticsEvent.denied(),
                ),
          explanation: PrivacySettingsPage.usageAnalyticsExplanation,
          note: const _Note(PrivacySettingsPage.usageAnalyticsNote),
        ),
      );
}
