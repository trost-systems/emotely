import 'package:emotely/config/bloc/config_bloc.dart';
import 'package:emotely/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The startup gate: nothing below it is built until the server has said this
/// build may run (#49).
///
/// It wraps the whole app rather than the session, so a build the server no
/// longer serves never reaches sign-in — the screens underneath may depend on
/// wire shapes that are gone, and asking someone to sign in only to block
/// them afterwards is worse than blocking them first.
class const ConfigGate({required final Widget child, super.key})
    extends StatelessWidget {
  static const checkingKey = Key('config_gate.checking');
  static const updateRequiredKey = Key('config_gate.update_required');
  static const updateKey = Key('config_gate.update');
  static const failureKey = Key('config_gate.failure');
  static const retryKey = Key('config_gate.retry');

  @override
  Widget build(BuildContext context) => BlocBuilder<ConfigBloc, ConfigState>(
    builder: (context, state) => switch (state) {
      ConfigReady() => child,
      ConfigUnknown() => const _Checking(),
      ConfigUpdateRequired(:final minAppVersion) => _UpdateRequired(
        minAppVersion: minAppVersion,
      ),
      ConfigFailure(:final problem) => _Failure(problem: problem),
    },
  );
}

/// Everything the gate shows sits on its own scaffold: it renders before the
/// app's own chrome exists, so it cannot borrow one.
class const _GateScaffold({
  required final Key contentKey,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          key: contentKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class const _Checking() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const _GateScaffold(
    contentKey: ConfigGate.checkingKey,
    children: [CircularProgressIndicator()],
  );
}

/// The force-update screen: no retry, no way around it. This is what lets the
/// server delete deprecated wire shapes instead of keeping them (#37).
class const _UpdateRequired({required final String minAppVersion})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _GateScaffold(
    contentKey: ConfigGate.updateRequiredKey,
    children: [
      Text(
        context.l10n.updateRequiredMessage(minAppVersion),
        textAlign: TextAlign.center,
      ),
      FilledButton(
        key: ConfigGate.updateKey,
        onPressed: () =>
            context.read<ConfigBloc>().add(const ConfigEvent.updateRequested()),
        child: Text(context.l10n.updateButton),
      ),
    ],
  );
}

/// The config could not be read, so the app does not know whether it may run
/// and blocks with a retry. Not "allowed by default": the version gate is the
/// one thing that must fail shut, or a build the server has stopped serving
/// walks straight past it whenever the network is down.
class const _Failure({required final ConfigProblem problem})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _GateScaffold(
    contentKey: ConfigGate.failureKey,
    children: [
      Text(
        _messageFor(context.l10n),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
      FilledButton(
        key: ConfigGate.retryKey,
        onPressed: () =>
            context.read<ConfigBloc>().add(const ConfigEvent.loaded()),
        child: Text(context.l10n.tryAgainButton),
      ),
    ],
  );

  String _messageFor(AppLocalizations strings) => switch (problem) {
    ConfigProblem.unreachable => strings.configUnreachableMessage,
    ConfigProblem.unreadable => strings.configUnreadableMessage,
  };
}
