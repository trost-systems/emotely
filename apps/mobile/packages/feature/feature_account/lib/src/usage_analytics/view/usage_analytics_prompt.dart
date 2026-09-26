import 'dart:async';

import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:feature_account/src/usage_analytics/usage_analytics_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// Asks "May I count how you use the app?" over [child] whenever nobody on
/// this device has answered (#204): on first launch, and again after a
/// sign-out, since the answer belongs to a person, not the phone.
///
/// Mounted by the app above its navigator, under the startup gate, so the
/// question comes before anything else the user sees and whatever screen is
/// underneath waits for the answer. Nothing is set up for PostHog until the
/// answer is "Allow"; the sheet cannot be dismissed without one, because
/// not answering must not be read as either.
class const UsageAnalyticsPrompt({required final Widget child, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        GetIt.I<UsageAnalyticsBloc>()..add(const UsageAnalyticsEvent.started()),
    child: BlocBuilder<UsageAnalyticsBloc, UsageAnalyticsState>(
      builder: (context, state) => Stack(
        children: [
          child,
          if (state == UsageAnalyticsState.undecided) ...[
            ModalBarrier(
              dismissible: false,
              color: Theme.of(context).colorScheme.scrim
                  .withValues(alpha: 0.32),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              // Only the sheet is read out while it is up: the screen under
              // the scrim cannot be reached until it is answered.
              child: BlockSemantics(child: UsageAnalyticsSheet()),
            ),
          ],
        ],
      ),
    ),
  );
}

/// The sheet itself: the question, what is counted and what never is, two
/// answers of equal weight, and where to change it later.
class const UsageAnalyticsSheet({super.key}) extends StatelessWidget {
  static const sheetKey = Key('usage_analytics_sheet');
  static const denyKey = Key('usage_analytics_sheet.deny');
  static const allowKey = Key('usage_analytics_sheet.allow');
  static const noticeKey = Key('usage_analytics_sheet.notice');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: sheetKey,
      color: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: usageAnalyticsTitle,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 18,
              children: [_Question(), _Points(), _Answers(), _ChangeLater()],
            ),
          ),
        ),
      ),
    );
  }
}

class const _Question() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            usageAnalyticsTitle,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        Text(
          usageAnalyticsBody,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// What is counted, and what never is, each with its mark.
class const _Points() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      _Point(icon: Icons.check, text: usageAnalyticsCounted),
      _Point(icon: Icons.close, text: usageAnalyticsNever),
    ],
  );
}

class const _Point({required final IconData icon, required final String text})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Don't allow" and "Allow", the same button twice: neither nudges.
class const _Answers() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UsageAnalyticsBloc>();
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: OutlinedButton(
            key: UsageAnalyticsSheet.denyKey,
            onPressed: () => bloc.add(const UsageAnalyticsEvent.denied()),
            child: const Text(usageAnalyticsDenyLabel),
          ),
        ),
        Expanded(
          child: OutlinedButton(
            key: UsageAnalyticsSheet.allowKey,
            onPressed: () => bloc.add(const UsageAnalyticsEvent.allowed()),
            child: const Text(usageAnalyticsAllowLabel),
          ),
        ),
      ],
    );
  }
}

/// Where to change it later, and the whole notice.
class const _ChangeLater() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          usageAnalyticsChangeHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          key: UsageAnalyticsSheet.noticeKey,
          onPressed: () => unawaited(openPrivacyNotice()),
          child: const Text(privacyNoticeLabel),
        ),
      ],
    );
  }
}
