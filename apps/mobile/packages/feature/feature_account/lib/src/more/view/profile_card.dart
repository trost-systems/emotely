import 'dart:async';

import 'package:feature_account/src/l10n/account_localizations.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:feature_account/src/profile/sign_in_copy.dart';
import 'package:feature_account/src/profile/view/profile_avatar.dart';
import 'package:feature_account/src/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// The top of the More tab: who the user is to emotely — their initial,
/// their name (or an invitation to give one) and the address they sign in
/// with — opening the Profile screen, where both live.
///
/// Reads the [ProfileBloc] the More tab provides, and reads it again once
/// the Profile screen closes, since a new name was saved there.
class const ProfileCard({super.key}) extends StatelessWidget {
  static const tileKey = Key('more_view.profile');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileBloc>().state;
    final name = state.profile?.displayName;
    final strings = AccountLocalizations.of(context);
    final email = state.identity?.shownEmail(strings);
    final text = Theme.of(context).textTheme;
    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: tileKey,
        contentPadding: const EdgeInsets.all(16),
        leading: ProfileAvatar(name: name, radius: 26),
        title: Text(switch (state.status) {
          ProfileStatus.ready => name ?? strings.profileCardAddName,
          ProfileStatus.loading ||
          ProfileStatus.loadFailed => strings.profileCardTitle,
        }, style: text.titleLarge),
        subtitle: email == null ? null : Text(email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(_open(context)),
      ),
    );
  }

  static Future<void> _open(BuildContext context) async {
    final profile = context.read<ProfileBloc>();
    await const ProfileRoute().push<void>(context);
    profile.add(const ProfileEvent.loaded());
  }
}
