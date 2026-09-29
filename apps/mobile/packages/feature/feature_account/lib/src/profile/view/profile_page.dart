import 'package:feature_account/src/l10n/l10n.dart';
import 'package:feature_account/src/navigator.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:feature_account/src/profile/sign_in_copy.dart';
import 'package:feature_account/src/profile/view/name_field.dart';
import 'package:feature_account/src/profile/view/profile_avatar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile_repository/profile_repository.dart';

/// The Profile screen, with a [ProfileBloc] of its own that reads the
/// profile as it opens.
class const ProfilePage({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GetIt.I<ProfileBloc>()..add(const ProfileEvent.loaded()),
    child: const ProfileView(),
  );
}

/// Who the user is to emotely: the name it greets them by, editable in
/// place, and the account they signed in with, read-only, with signing out
/// at the foot. Deleting the account is not here: it lives under More on
/// its own, away from the everyday.
class const ProfileView({super.key}) extends StatelessWidget {
  static const avatarKey = Key('profile_view.avatar');
  static const nameKey = Key('profile_view.name');
  static const placeholderKey = Key('profile_view.placeholder');
  static const retryKey = Key('profile_view.retry');
  static const emailKey = Key('profile_view.email');
  static const methodKey = Key('profile_view.method');
  static const signOutKey = Key('profile_view.sign_out');

  @override
  Widget build(BuildContext context) => BlocListener<ProfileBloc, ProfileState>(
    listenWhen: (previous, next) => previous.noticeCount != next.noticeCount,
    listener: (context, state) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_message(state.notice, context.l10n))),
      ),
    child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.profileTitle)),
      body: const SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 28,
                  children: [_Avatar(), _Name(), _SignedInAs()],
                ),
              ),
            ),
            Divider(height: 1),
            _SignOut(),
          ],
        ),
      ),
    ),
  );

  static String _message(ProfileNotice? notice, AccountLocalizations strings) =>
      switch (notice) {
        ProfileNotice.saved || null => strings.profileSavedMessage,
        ProfileNotice.nameEmpty => strings.profileNameEmptyMessage,
        ProfileNotice.nameRefused => strings.profileNameRefusedMessage,
        ProfileNotice.saveFailed => strings.profileSaveFailedMessage,
      };
}

/// The initial of the name as saved, not as typed: it changes once the
/// name does.
class const _Avatar() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: ProfileAvatar(
      key: ProfileView.avatarKey,
      name: context.select<ProfileBloc, String?>(
        (bloc) => bloc.state.profile?.displayName,
      ),
      radius: 48,
    ),
  );
}

/// The name field once the profile is read, progress until then, and a
/// way to read it again if that failed.
class const _Name() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocBuilder<ProfileBloc, ProfileState>(
    buildWhen: (previous, next) => previous.status != next.status,
    builder: (context, state) => switch (state.status) {
      ProfileStatus.loading => const Center(child: CircularProgressIndicator()),
      ProfileStatus.loadFailed => const _LoadFailed(),
      ProfileStatus.ready => NameField(
        fieldKey: ProfileView.nameKey,
        saved: state.profile?.displayName,
        hint: context.l10n.profileNameHint,
        helper: const _Helper(),
      ),
    },
  );
}

/// What the name is for, or, while it is a placeholder, an invitation to
/// replace it.
class const _Helper() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => switch (context
      .select<ProfileBloc, Profile?>((bloc) => bloc.state.profile)) {
    Profile(nameIsPlaceholder: true, :final displayName) => Text(
      context.l10n.profilePlaceholderLine(displayName),
      key: ProfileView.placeholderKey,
    ),
    _ => Text(context.l10n.profileNameHelper),
  };
}

class const _LoadFailed() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      Text(
        context.l10n.profileLoadFailedMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      TextButton(
        key: ProfileView.retryKey,
        onPressed: () =>
            context.read<ProfileBloc>().add(const ProfileEvent.loaded()),
        child: Text(context.l10n.profileRetryButton),
      ),
    ],
  );
}

/// The sign-in address, read-only, and how the account signs in. An
/// account without an address (none this app creates) shows neither.
class const _SignedInAs() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final identity = context.select<ProfileBloc, SignInIdentity?>(
      (bloc) => bloc.state.identity,
    );
    final strings = context.l10n;
    final email = identity?.shownEmail(strings);
    if (identity == null || email == null) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(strings.profileSignedInAsLabel, style: text.labelLarge),
        Card.filled(
          key: ProfileView.emailKey,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(email),
          ),
        ),
        Text(
          identity.methodLine(strings),
          key: ProfileView.methodKey,
          style: text.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

/// Signing out, in plain text: an everyday act, not a destructive one.
class const _SignOut() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListTile(
    key: ProfileView.signOutKey,
    leading: const Icon(Icons.logout),
    title: Text(context.l10n.profileSignOutButton),
    onTap: () => GetIt.I<AccountNavigator>().signOut(context),
  );
}
