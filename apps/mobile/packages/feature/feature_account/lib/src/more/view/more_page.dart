import 'dart:async';

import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/navigator.dart';
import 'package:feature_account/src/routes.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:feedback_link/feedback_link.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// The More tab: everything that is not the journal, as sections of rows
/// with a heading each — privacy, about, and the account at the very
/// bottom, where deleting it sits alone (#204).
///
/// Reads the [ConsentBloc] the route provides, and brings two blocs of its
/// own: an [AccountBloc] for the feedback mail, which carries the build the
/// app runs and so goes through a bloc rather than being launched from
/// here (ADR 0015), and a [UsageAnalyticsBloc] for the status line under
/// Privacy settings.
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
  static const signOutKey = Key('more_view.sign_out');
  static const accountKey = Key('more_view.account');

  static const privacySection = 'Privacy';
  static const aboutSection = 'About';
  static const accountSection = 'Account';

  static const privacySettingsLabel = 'Privacy settings';

  static const accountLabel = 'Delete account';
  static const accountExplanation = 'Removes your account and every entry.';

  /// Under the feedback row: says what the mail already contains, so
  /// nobody has to wonder whether tapping it sends anything they wrote.
  static const feedbackExplanation =
      'Opens your mail app. Carries your app version and device, '
      'nothing from your journal.';

  static const signOutLabel = 'Sign out';

  /// The gap above every section heading, and above the sign-out row: what
  /// tells one section from the next at a glance.
  static const sectionGap = 24.0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('More')),
    body: const SafeArea(
      // A handful of rows, all built at once rather than as they scroll
      // into view: a screen reader, and a test, can reach every row
      // without scrolling first.
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: sectionGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The privacy notice and the imprint are required to be
            // reachable from inside the app — Apple guideline 5.1.1 (i) and
            // Google Play's User Data policy for the notice, § 5 DDG for the
            // imprint of a German provider.
            _Section(
              title: privacySection,
              children: [_PrivacySettingsRow(), _PrivacyNoticeRow()],
            ),
            // Kept off the Account section, with About between the two, so
            // a tap meant for signing out never lands on deletion.
            _SignOutRow(),
            _Section(
              title: aboutSection,
              children: [_FeedbackRow(), _ImprintRow()],
            ),
            // Last, alone, below everything the user might want first.
            _Section(title: accountSection, children: [_AccountRow()]),
          ],
        ),
      ),
    ),
  );
}

/// Privacy settings, with where both consents stand in one line.
class const _PrivacySettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final journal = context.select<ConsentBloc, String?>(
      (bloc) => _journalStatus(bloc.state),
    );
    final usage = context.select<UsageAnalyticsBloc, String?>(
      (bloc) => _usageAnalyticsStatus(bloc.state),
    );
    return ListTile(
      key: MoreView.privacySettingsKey,
      title: const Text(MoreView.privacySettingsLabel),
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
String? _journalStatus(ConsentState state) => switch (state) {
  ConsentKnown(:final granted) => granted ? 'Journal: allowed' : 'Journal: off',
  ConsentWithdrawFailure() => 'Journal: allowed',
  ConsentWriteFailure() => 'Journal: off',
  ConsentUnknown() || ConsentBusy() || ConsentFailure() => null,
};

/// Usage analytics in a word, or nothing while the choice is not read.
String? _usageAnalyticsStatus(UsageAnalyticsState state) => switch (state) {
  UsageAnalyticsState.allowed => 'Usage analytics: on',
  UsageAnalyticsState.denied ||
  UsageAnalyticsState.undecided => 'Usage analytics: off',
  UsageAnalyticsState.unknown => null,
};

/// The privacy notice, opened in the browser.
class const _PrivacyNoticeRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: MoreView.privacyNoticeKey,
    title: const Text(privacyNoticeLabel),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => unawaited(openPrivacyNotice()),
  );
}

/// The imprint, opened in the browser.
class const _ImprintRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: MoreView.imprintKey,
    title: const Text(imprintLabel),
    trailing: const Icon(Icons.open_in_new),
    onTap: () => unawaited(openImprint()),
  );
}

/// The feedback mail, which the [AccountBloc] composes because it carries
/// the build the app runs.
class const _FeedbackRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: MoreView.feedbackKey,
    title: const Text(feedbackLabel),
    subtitle: const Text(MoreView.feedbackExplanation),
    trailing: const Icon(Icons.mail_outline),
    onTap: () =>
        context.read<AccountBloc>().add(const AccountEvent.feedbackRequested()),
  );
}

/// Signing out, in the normal text colour — it loses nothing — and set off
/// from the section above by [MoreView.sectionGap].
class const _SignOutRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MoreView.sectionGap),
    child: ListTile(
      key: MoreView.signOutKey,
      leading: const Icon(Icons.logout),
      title: const Text(MoreView.signOutLabel),
      onTap: () => GetIt.I<AccountNavigator>().signOut(context),
    ),
  );
}

/// The account screen, on the feature's own route (ADR 0016), in the error
/// colour: what it leads to cannot be undone.
class const _AccountRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      key: MoreView.accountKey,
      title: Text(MoreView.accountLabel, style: TextStyle(color: error)),
      subtitle: const Text(MoreView.accountExplanation),
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
