import 'package:feature_account/src/l10n/account_localizations.dart';
import 'package:profile_repository/profile_repository.dart';

/// How the screens say who is signed in and how; one place, so the Profile
/// screen and the More tab's card never disagree. The words are messages in
/// `l10n/account_*.arb`, looked up in the language the screen is shown in.
extension SignInIdentityCopy on SignInIdentity {
  /// The address as the user may see it: never Apple's made-up one.
  String? shownEmail(AccountLocalizations strings) =>
      hiddenByApple ? strings.signInHiddenByApple : email;

  /// The line under the address: how the account signs in, and what the
  /// address is for. A provider this app does not offer (only an account
  /// set up by hand) says only the second half.
  String methodLine(AccountLocalizations strings) => switch (method) {
    _ when hiddenByApple => strings.signInViaAppleRelay,
    SignInVia.email => strings.signInViaEmail,
    SignInVia.google => strings.signInViaGoogle,
    SignInVia.apple => strings.signInViaApple,
    null => strings.signInViaUnknown,
  };
}
