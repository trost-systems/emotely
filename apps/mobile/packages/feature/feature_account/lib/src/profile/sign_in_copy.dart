import 'package:profile_repository/profile_repository.dart';

// How the screens say who is signed in and how; one place, so the Profile
// screen and the More tab's card never disagree.

/// Instead of an address Apple made up for this app.
const hiddenByAppleLabel = 'Hidden by Apple';

const viaEmailCodeLine =
    'Via email code. This is where sign-in codes and account mail go.';
const viaGoogleLine = 'Via Google. This is where account mail goes.';
const viaAppleLine = 'Via Apple. This is where account mail goes.';
const viaAppleRelayLine =
    'Hidden by Apple (private relay). Apple forwards account mail to you.';

/// A provider this app does not offer; only an account set up by hand.
const viaUnknownLine = 'This is where account mail goes.';

/// The copy for one identity.
extension SignInIdentityCopy on SignInIdentity {
  /// The address as the user may see it: never Apple's made-up one.
  String? get shownEmail => hiddenByApple ? hiddenByAppleLabel : email;

  /// The line under the address: how the account signs in, and what the
  /// address is for.
  String get methodLine => switch (method) {
    _ when hiddenByApple => viaAppleRelayLine,
    SignInVia.emailCode => viaEmailCodeLine,
    SignInVia.google => viaGoogleLine,
    SignInVia.apple => viaAppleLine,
    null => viaUnknownLine,
  };
}
