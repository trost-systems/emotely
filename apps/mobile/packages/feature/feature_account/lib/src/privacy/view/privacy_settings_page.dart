import 'dart:async';

import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/l10n/l10n.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.privacySettingsTitle)),
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
                child: Text(context.l10n.privacyNoticeLink),
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
      label: context.l10n.privacyJournalLabel,
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
      explanation: context.l10n.privacyJournalExplanation,
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
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return switch (state) {
      // When it was given, on the device's calendar, in the user's language.
      ConsentKnown(granted: true, :final since?) => _Note(
        '${strings.privacyJournalGiven(since.toLocal())} '
        '${strings.privacyJournalOnNote}',
      ),
      ConsentKnown(granted: true) ||
      ConsentBusy() => _Note(strings.privacyJournalOnNote),
      ConsentKnown(granted: false) ||
      ConsentWriteFailure() => _Note(strings.privacyJournalOffNote),
      ConsentWithdrawFailure() => _Note(
        strings.consentWithdrawFailureMessage,
        failed: true,
      ),
      ConsentUnknown() => const LinearProgressIndicator(),
      // A failed read says nothing about whether consent stands, so the
      // switch is off-limits; say so and offer to look again.
      ConsentFailure() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Note(strings.consentUnknownMessage, failed: true),
          TextButton(
            key: PrivacySettingsPage.journalRetryKey,
            onPressed: () => context.read<ConsentBloc>().add(
              const ConsentEvent.loaded(withDate: true),
            ),
            child: Text(strings.privacyJournalRetryButton),
          ),
        ],
      ),
    };
  }
}

/// "New sessions stop; your entries stay." Turning off is one confirmation
/// away, never more: withdrawal must be as easy as giving (Art. 7 (3)).
class const _ConfirmWithdrawal() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return AlertDialog(
      title: Text(strings.privacyConfirmTitle),
      content: Text(strings.privacyConfirmMessage),
      actions: [
        TextButton(
          key: PrivacySettingsPage.cancelKey,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.privacyCancelButton),
        ),
        TextButton(
          key: PrivacySettingsPage.confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.privacyConfirmButton),
        ),
      ],
    );
  }
}

class const _UsageAnalyticsCard() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<UsageAnalyticsBloc, UsageAnalyticsState>(
        builder: (context, state) => _PrivacyCard(
          switchKey: PrivacySettingsPage.usageAnalyticsKey,
          label: context.l10n.privacyUsageAnalyticsLabel,
          value: state == UsageAnalyticsState.allowed,
          onChanged: state == UsageAnalyticsState.unknown
              ? null
              : (on) => context.read<UsageAnalyticsBloc>().add(
                  on
                      ? const UsageAnalyticsEvent.allowed()
                      : const UsageAnalyticsEvent.denied(),
                ),
          explanation: context.l10n.privacyUsageAnalyticsExplanation,
          note: _Note(context.l10n.privacyUsageAnalyticsNote),
        ),
      );
}
