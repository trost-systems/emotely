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

  static const title = 'Profile';

  /// Under the field, while the name is one the user gave.
  static const nameHelper = 'How emotely greets you.';

  /// In the empty field, while there is no name yet.
  static const nameHint = 'What should I call you?';

  static const savedMessage = 'Saved';
  static const emptyMessage = 'A name needs at least one character.';
  static const refusedMessage = 'That name has a character I can’t use.';
  static const saveFailedMessage =
      'I couldn’t save that name. Try again in a moment.';
  static const loadFailedMessage = 'I couldn’t load your name.';
  static const signedInAsLabel = 'Signed in as';
  static const signOutLabel = 'Sign out';

  static const hiddenByApple = hiddenByAppleLabel;
  static const viaEmailCode = viaEmailCodeLine;
  static const viaGoogle = viaGoogleLine;
  static const viaApple = viaAppleLine;
  static const viaAppleRelay = viaAppleRelayLine;
  static const viaUnknown = viaUnknownLine;

  /// Under the field while the name is one emotely picked on Skip: an
  /// invitation, in the companion's voice, never a demand.
  static String placeholderLine(String name) =>
      '$name · a nickname I picked – tell me yours';

  @override
  Widget build(BuildContext context) => BlocListener<ProfileBloc, ProfileState>(
    listenWhen: (previous, next) => previous.noticeCount != next.noticeCount,
    listener: (context, state) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_message(state.notice)))),
    child: Scaffold(
      appBar: AppBar(title: const Text(title)),
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

  static String _message(ProfileNotice? notice) => switch (notice) {
    ProfileNotice.saved || null => savedMessage,
    ProfileNotice.nameEmpty => emptyMessage,
    ProfileNotice.nameRefused => refusedMessage,
    ProfileNotice.saveFailed => saveFailedMessage,
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
        hint: ProfileView.nameHint,
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
      ProfileView.placeholderLine(displayName),
      key: ProfileView.placeholderKey,
    ),
    _ => const Text(ProfileView.nameHelper),
  };
}

class const _LoadFailed() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      Text(
        ProfileView.loadFailedMessage,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      TextButton(
        key: ProfileView.retryKey,
        onPressed: () =>
            context.read<ProfileBloc>().add(const ProfileEvent.loaded()),
        child: const Text('Try again'),
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
    final email = identity?.shownEmail;
    if (identity == null || email == null) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(ProfileView.signedInAsLabel, style: text.labelLarge),
        Card.filled(
          key: ProfileView.emailKey,
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(email),
          ),
        ),
        Text(
          identity.methodLine,
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
    title: const Text(ProfileView.signOutLabel),
    onTap: () => GetIt.I<AccountNavigator>().signOut(context),
  );
}
