import 'dart:async';

import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/consent/consent_outcome.dart';
import 'package:feature_account/src/consent/consent_text.dart';
import 'package:feature_account/src/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:legal_links/legal_links.dart';
import 'package:material_ui/material_ui.dart';

/// Asks for the explicit consent (Art. 9 (2) (a) GDPR) a session needs, on
/// its own route, before the first session and never again once it stands.
///
/// It reads the [ConsentBloc] in scope rather than making one: the route
/// that shows it owns the bloc, so the answer it records is the answer the
/// route pops with.
///
/// Pops with a [ConsentOutcome] — recorded, declined, or not recordable —
/// so the caller starts a session on exactly one of those and can say why
/// it did not on the others. Left by the back arrow, it pops with nothing.
class const ConsentPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const ConsentView();
}

/// The consent screen itself: what is sent where, the unticked box, and the
/// two ways out.
class const ConsentView({super.key}) extends StatelessWidget {
  static const checkboxKey = Key('consent_view.checkbox');
  static const agreeKey = Key('consent_view.agree');
  static const declineKey = Key('consent_view.decline');
  static const noticeKey = Key('consent_view.notice');
  static const retryKey = Key('consent_view.retry');

  @override
  Widget build(BuildContext context) => BlocConsumer<ConsentBloc, ConsentState>(
    listenWhen: (previous, state) => state.allowsSession,
    // Recorded: this route is done, and the caller starts the session.
    listener: (context, _) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        Navigator.of(context).pop(ConsentOutcome.granted);
      }
    },
    builder: (context, state) => PopScope(
      // The write is in flight; leaving now would strand it and could
      // start a session on a consent that had not landed.
      canPop: state is! ConsentBusy,
      child: Scaffold(
        // No title here: the app bar holds one short line, and the title
        // is part of the wording agreed to. _Ask shows it as its heading.
        appBar: AppBar(),
        body: SafeArea(
          child: switch (state) {
            // Still reading. Showing the question here would flash it for
            // a moment and then answer it, which is not how a decision
            // this size should arrive.
            ConsentUnknown() ||
            ConsentBusy() => const Center(child: CircularProgressIndicator()),
            ConsentWriteFailure() => const _Margin(child: _WriteFailed()),
            // The read failed: the app does not know whether consent
            // already stands, and asking again would re-prompt someone
            // who has consented — consent fatigue, on a flaky network.
            // Say what happened and offer to look again.
            ConsentFailure() => const _Margin(child: _ReadFailed()),
            // `known(granted: true)` is handled by the listener above;
            // a known `false` asks the question. A failed *withdrawal*
            // can only be reached from the account screen, which owns
            // that act, so it asks here too rather than being a state of
            // its own.
            ConsentKnown() || ConsentWithdrawFailure() => const _Ask(),
          },
        ),
      ),
    ),
  );
}

/// The question, the box, and the two answers. Stateful for one reason: the
/// tick is a local intention until the button is pressed, and nothing
/// outside this screen has any business knowing about a half-made decision.
class const _Ask() extends StatefulWidget {
  @override
  State<_Ask> createState() => _AskState();
}

class _AskState() extends State<_Ask> {
  /// Unticked, always, on every build of this screen. No pre-ticked box and
  /// no remembered tick: the act has to be made here, now.
  var _ticked = false;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        const _Margin(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [_Title(), _Points()],
          ),
        ),
        TextButton(
          key: ConsentView.noticeKey,
          onPressed: () => unawaited(openPrivacyNotice()),
          child: Text(context.l10n.consentReadNoticeLink),
        ),
        // Full-bleed, like every list row: the whole width is the tap
        // target, so its highlight runs edge to edge and the box and label
        // sit at the row's own inset.
        CheckboxListTile(
          key: ConsentView.checkboxKey,
          value: _ticked,
          // The label is the checkbox's own semantics, so a screen reader
          // reads the thing being agreed to, not "checkbox, unchecked".
          title: Text(context.l10n.consentCheckboxLabel),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (ticked) => setState(() => _ticked = ticked ?? false),
        ),
        _Margin(child: _Answers(ticked: _ticked)),
      ],
    ),
  );
}

/// The screen's title, as the heading of what is agreed to. It wraps: in
/// German it runs past what an app bar shows.
class const _Title() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      context.l10n.consentTitle,
      style: Theme.of(context).textTheme.headlineSmall,
    ),
  );
}

/// What is sent where: every point of [consentPoints], one under the other.
class const _Points() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      for (final point in consentPoints(context.l10n)) _Point(point: point),
    ],
  );
}

/// Agree, enabled only once [ticked], and decline.
class const _Answers({required final bool ticked}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      // A disabled button reads as just "dimmed" to a screen reader, which
      // leaves someone who cannot see the checkbox with no way to know why
      // the button does nothing. The hint says what to do.
      Semantics(
        enabled: ticked,
        hint: ticked ? null : context.l10n.consentAgreeBlockedHint,
        child: FilledButton(
          key: ConsentView.agreeKey,
          // Disabled until the box is ticked: the button alone is not the
          // affirmative act, the pair is.
          onPressed: ticked
              ? () => context.read<ConsentBloc>().add(
                  const ConsentEvent.granted(),
                )
              : null,
          child: Text(context.l10n.consentAgreeButton),
        ),
      ),
      TextButton(
        key: ConsentView.declineKey,
        onPressed: () {
          context.read<ConsentBloc>().add(const ConsentEvent.declined());
          // Declining is an answer, not a dead end: back to the journal,
          // which stays entirely usable.
          Navigator.of(context).pop(ConsentOutcome.declined);
        },
        child: Text(context.l10n.consentDeclineButton),
      ),
    ],
  );
}

/// One of the three points: a bold lead, then its body, in one text so a
/// screen reader hears one sentence and not a heading followed by a
/// paragraph.
class const _Point({required final ConsentPoint point})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: point.lead,
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: ' ${point.body}'),
        ],
      ),
    );
  }
}

/// The page margin, applied to the text and the buttons but not to the
/// checkbox row, which claims the full width.
class const _Margin({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: child);
}

/// Whether consent already stands could not be read. Distinct from the
/// question itself: re-asking someone who has already consented, every time
/// the network hiccups, trains them to tick the box without reading it —
/// and a consent given that way is not much of a consent.
class const _ReadFailed() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        context.l10n.consentUnknownMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
      FilledButton(
        key: ConsentView.retryKey,
        onPressed: () =>
            context.read<ConsentBloc>().add(const ConsentEvent.loaded()),
        child: Text(context.l10n.consentRetryButton),
      ),
      // Nothing was asked, so there is no answer to give.
      TextButton(
        key: ConsentView.declineKey,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.consentBackButton),
      ),
    ],
  );
}

/// The consent could not be written down. The session does not start on
/// this: an unrecorded consent is one nobody can demonstrate later.
class const _WriteFailed() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        context.l10n.consentFailureMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
      FilledButton(
        key: ConsentView.retryKey,
        onPressed: () =>
            context.read<ConsentBloc>().add(const ConsentEvent.granted()),
        child: Text(context.l10n.consentRetryButton),
      ),
      // Leaving here is not a refusal: the box was ticked and the record
      // did not land, and what the caller says about it must say so.
      TextButton(
        key: ConsentView.declineKey,
        onPressed: () => Navigator.of(context).pop(ConsentOutcome.writeFailed),
        child: Text(context.l10n.consentDeclineButton),
      ),
    ],
  );
}
