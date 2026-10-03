part of 'account_bloc.dart';

/// Where the deletion stands; the screen renders exactly one step per state.
@freezed
sealed class AccountState with _$AccountState {
  /// Nothing asked yet: the screen offers to delete the account.
  const factory idle() = AccountIdle;

  /// The account is being deleted.
  const factory deleting() = AccountDeleting;

  /// The account is gone on the server; this device is forgetting it and
  /// ending its session. [stillLinked] are the sign-in grants that could
  /// not be revoked (#193), which the screen tells the user how to remove
  /// themselves — now, while it is still there to say so.
  const factory signingOut({required Set<SignInGrant> stillLinked}) =
      AccountSigningOut;

  /// The account is gone and this device signed out; the screen leaves.
  const factory deleted() = AccountDeleted;

  /// The server refused or could not be reached; the screen offers a retry.
  const factory failure() = AccountFailure;
}
