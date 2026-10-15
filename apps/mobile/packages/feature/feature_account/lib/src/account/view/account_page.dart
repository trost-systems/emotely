import 'dart:async';

import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/account/sign_in_grants.dart';
import 'package:feature_account/src/l10n/l10n.dart';
import 'package:feature_account/src/navigator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

/// Wires an [AccountBloc] to the Supabase client in scope.
class const AccountPage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<AccountBloc>(),
    child: const AccountView(),
  );
}

/// The account screen: what deleting the account means, and the button that
/// does it after a confirmation. Leaves on its own once the account is gone;
/// the router has already landed on sign-in underneath.
class const AccountView({super.key}) extends StatelessWidget {
  static const deleteKey = Key('account_view.delete');
  static const confirmKey = Key('account_view.confirm');
  static const cancelKey = Key('account_view.cancel');
  static const retryKey = Key('account_view.retry');
  static const signOutKey = Key('account_view.sign_out');

  @override
  Widget build(BuildContext context) => BlocConsumer<AccountBloc, AccountState>(
    listenWhen: (_, state) =>
        state is AccountDeleted ||
        state is AccountSigningOut && state.stillLinked.isNotEmpty,
    listener: (context, state) => switch (state) {
      AccountSigningOut(:final stillLinked) => _sayStillLinked(
        context,
        stillLinked,
      ),
      _ => _leave(context),
    },
    // The server deletes the account whether or not this screen stays; the
    // bloc lives with the route, so leaving mid-flight would drop the local
    // sign-out and keep a session for a user who no longer exists. Every
    // way out (back arrow, system back, swipe) asks the route first.
    builder: (context, state) => PopScope(
      canPop: state is! AccountDeleting && state is! AccountSigningOut,
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.accountTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: switch (state) {
              AccountIdle(:final asksApple) => _DeleteAccount(
                asksApple: asksApple,
              ),
              // Deleted has no screen of its own: the listener above pops
              // this route the moment it arrives.
              AccountDeleting() ||
              AccountSigningOut() ||
              AccountDeleted() => const _Busy(),
              AccountFailure() => const _Failure(),
            },
          ),
        ),
      ),
    ),
  );
}

/// Only this route pops itself; never whatever else may be on top, and
/// never the root under it.
void _leave(BuildContext context) {
  if (ModalRoute.of(context)?.isCurrent ?? false) {
    Navigator.of(context).pop();
  }
}

/// The account is deleted, but Apple or Google may still list emotely
/// (#193): says so, and where to remove it. On the app's own messenger, so
/// the message stays on the welcome screen the sign-out lands on, and long
/// enough to read the path it names.
void _sayStillLinked(BuildContext context, Set<SignInGrant> stillLinked) {
  final provider = stillLinked.length == 1 ? stillLinked.single.name : 'other';
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(context.l10n.accountDeletedStillLinked(provider)),
      duration: const Duration(seconds: 12),
      showCloseIcon: true,
    ),
  );
}

/// What deleting means, said once here; the dialog only asks.
class const _DeleteAccount({required final bool asksApple})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        context.l10n.accountConsequenceMessage,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      OutlinedButton(
        key: AccountView.deleteKey,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => unawaited(_confirm(context, asksApple: asksApple)),
        child: Text(context.l10n.accountDeleteButton),
      ),
    ],
  );

  /// The dialog sits above this screen on the navigator, outside the
  /// bloc's scope, so the bloc is captured before it opens.
  static Future<void> _confirm(
    BuildContext context, {
    required bool asksApple,
  }) {
    final account = context.read<AccountBloc>();
    return showDialog<void>(
      context: context,
      builder: (_) => _Confirmation(
        asksApple: asksApple,
        onConfirm: () => account.add(const AccountEvent.deletionRequested()),
      ),
    );
  }
}

/// Asks once more, naming the loss in the question; the only way to delete.
/// When [asksApple], it also says Apple's sheet comes next (#193).
class const _Confirmation({
  required final bool asksApple,
  required final VoidCallback onConfirm,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.accountConfirmationMessage),
    content: asksApple ? Text(context.l10n.accountConfirmationAppleNote) : null,
    actions: [
      TextButton(
        key: AccountView.cancelKey,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.accountCancelButton),
      ),
      FilledButton(
        key: AccountView.confirmKey,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm();
        },
        child: Text(context.l10n.accountConfirmDeleteButton),
      ),
    ],
  );
}

/// Retry, or sign out: the server may have deleted the account even though
/// the answer never arrived, and this device should not keep a session it
/// may no longer be entitled to. (`delete_account` is idempotent, so the
/// retry is safe either way.)
class const _Failure() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Text(
        context.l10n.accountFailureMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      FilledButton(
        key: AccountView.retryKey,
        onPressed: () => context.read<AccountBloc>().add(
          const AccountEvent.deletionRequested(),
        ),
        child: Text(context.l10n.accountRetryButton),
      ),
      TextButton(
        key: AccountView.signOutKey,
        onPressed: () {
          // The app signs out (the router lands on sign-in underneath);
          // this route leaves too. Resolving the navigator is one of the
          // two container calls a widget may make (ADR 0015).
          GetIt.I<AccountNavigator>().signOut(context);
          Navigator.of(context).pop();
        },
        child: Text(context.l10n.accountSignOutButton),
      ),
    ],
  );
}

class const _Busy() extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
