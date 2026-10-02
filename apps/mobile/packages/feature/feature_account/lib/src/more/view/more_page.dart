import 'dart:async';

import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/l10n/l10n.dart';
import 'package:feature_account/src/more/view/profile_card.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:feature_account/src/routes.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// The More tab: everything that is not the journal — the profile card on
/// top, then sections of rows with a heading each: privacy, about, and the
/// account at the very bottom, where deleting it sits alone (#204).
/// Signing out lives on the Profile screen.
///
/// Reads the [ConsentBloc] the route provides, and brings three blocs of
/// its own: an [AccountBloc] for the feedback mail, which carries the build
/// the app runs and so goes through a bloc rather than being launched from
/// here (ADR 0015), a [UsageAnalyticsBloc] for the status line under
/// Privacy settings, and a [ProfileBloc] for the card.
class const MorePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => GetIt.I<AccountBloc>()),
      BlocProvider(
        create: (_) =>
            GetIt.I<UsageAnalyticsBloc>()
              ..add(const UsageAnalyticsEvent.started()),
      ),
      BlocProvider(
        create: (_) => GetIt.I<ProfileBloc>()..add(const ProfileEvent.loaded()),
      ),
    ],
    child: const MoreView(),
  );
}

/// The sections themselves.
class const MoreView({super.key}) extends StatelessWidget {
  static const privacySettingsKey = Key('more_view.privacy_settings');
  static const privacyNoticeKey = Key('more_view.privacy_notice');
  static const feedbackKey = Key('more_view.feedback');
  static const imprintKey = Key('more_view.imprint');
  static const accountKey = Key('more_view.account');
  static const profileKey = ProfileCard.tileKey;

  /// The gap above every section heading: what tells one section from the
  /// next at a glance.
  static const sectionGap = 24.0;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(strings.moreTitle)),
      body: SafeArea(
        // A handful of rows, all built at once rather than as they scroll
        // into view: a screen reader, and a test, can reach every row
        // without scrolling first.
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: sectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileCard(),
              // The privacy notice and the imprint are required to be
              // reachable from inside the app — Apple guideline 5.1.1 (i)
              // and Google Play's User Data policy for the notice, § 5 DDG
              // for the imprint of a German provider.
              _Section(
                title: strings.morePrivacySection,
                children: const [_PrivacySettingsRow(), _PrivacyNoticeRow()],
              ),
              _Section(
                title: strings.moreAboutSection,
                children: const [_FeedbackRow(), _ImprintRow()],
              ),
              // Last, alone, below everything the user might want first.
              _Section(
                title: strings.moreAccountSection,
                children: const [_AccountRow()],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Privacy settings, with where both consents stand in one line.
class const _PrivacySettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final journal = context.select<ConsentBloc, String?>(
      (bloc) => _journalStatus(bloc.state, strings),
    );
    final usage = context.select<UsageAnalyticsBloc, String?>(
      (bloc) => _usageAnalyticsStatus(bloc.state, strings),
    );
    return ListTile(
      key: MoreView.privacySettingsKey,
      title: Text(strings.morePrivacySettingsRow),
      subtitle: Text([?journal, ?usage].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(_open(context)),
    );
  }

  /// Privacy settings on the feature's own route (ADR 0016). This tab's
  /// consent bloc reads the record again once it closes, since the switch
  /// may have moved there.
  static Future<void> _open(BuildContext context) async {
    final consent = context.read<ConsentBloc>();
    await const PrivacySettingsRoute().push<void>(context);
    consent.add(const ConsentEvent.loaded());
  }
}

/// The journal consent in a word, or nothing while it is not in hand.
String? _journalStatus(ConsentState state, AccountLocalizations strings) =>
    switch (state) {
      ConsentKnown(:final granted) =>
        granted
            ? strings.moreJournalAllowedStatus
            : strings.moreJournalOffStatus,
      ConsentWithdrawFailure() => strings.moreJournalAllowedStatus,
      ConsentWriteFailure() => strings.moreJournalOffStatus,
      ConsentUnknown() || ConsentBusy() || ConsentFailure() => null,
    };

/// Usage analytics in a word, or nothing while the choice is not read.
String? _usageAnalyticsStatus(
  UsageAnalyticsState state,
  AccountLocalizations strings,
) => switch (state) {
  UsageAnalyticsState.allowed => strings.moreUsageAnalyticsOnStatus,
  UsageAnalyticsState.denied ||
  UsageAnalyticsState.undecided => strings.moreUsageAnalyticsOffStatus,
  UsageAnalyticsState.unknown => null,
};

/// The privacy notice, opened in the browser.
class const _PrivacyNoticeRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: MoreView.privacyNoticeKey,
    title: Text(context.l10n.morePrivacyNoticeRow),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => unawaited(openPrivacyNotice(Localizations.localeOf(context))),
  );
}

/// The imprint, opened in the browser.
class const _ImprintRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: MoreView.imprintKey,
    title: Text(context.l10n.moreImprintRow),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => unawaited(openImprint(Localizations.localeOf(context))),
  );
}

/// The feedback mail, which the [AccountBloc] composes because it carries
/// the build the app runs. The line under it says what the mail already
/// contains, so nobody has to wonder whether tapping it sends anything they
/// wrote.
class const _FeedbackRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    return ListTile(
      key: MoreView.feedbackKey,
      title: Text(strings.moreFeedbackRow),
      subtitle: Text(strings.moreFeedbackExplanation),
      trailing: const Icon(Icons.mail_outline),
      onTap: () => context.read<AccountBloc>().add(
        const AccountEvent.feedbackRequested(),
      ),
    );
  }
}

/// The account screen, on the feature's own route (ADR 0016), in the error
/// color: what it leads to cannot be undone.
class const _AccountRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      key: MoreView.accountKey,
      title: Text(strings.moreDeleteAccountRow, style: TextStyle(color: error)),
      subtitle: Text(strings.moreDeleteAccountExplanation),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => const AccountRoute().go(context),
    );
  }
}

/// A heading and the rows under it, set off from the section above by
/// [MoreView.sectionGap].
class const _Section({
  required final String title,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, MoreView.sectionGap, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
