import 'package:shared_preferences/shared_preferences.dart';

/// A way in the sign-in screen offers, as the "Last used" tag names it
/// (#204): a button, not a protocol. A review account's password starts
/// at the email field too, so it counts as [emailCode].
enum SignInOption(final String wire) {
  apple('apple'),
  google('google'),
  emailCode('email_code'),
}

/// The way in last used on this phone, for the sign-in screen to tag
/// (#204, ADR 0019 decision 7).
///
/// On the device only: it goes to neither PostHog nor Supabase. Kept over
/// sign-out, since the next sign-in is when it helps; forgotten when the
/// account is deleted, since there is no account left to come back to.
class const LastSignInStore({
  required final SharedPreferencesAsync preferences,
}) {
  /// The one key this store owns.
  static const key = 'last_sign_in';

  /// The way in last used, or `null` when none is kept. A value this build
  /// does not recognize counts as none: no tag beats a tag on the wrong
  /// button.
  Future<SignInOption?> read() async {
    final stored = await preferences.getString(key);
    for (final option in SignInOption.values) {
      if (option.wire == stored) {
        return option;
      }
    }
    return null;
  }

  /// Keeps [option] as the way in last used.
  Future<void> remember(SignInOption option) =>
      preferences.setString(key, option.wire);

  /// Forgets the way in last used.
  Future<void> clear() => preferences.remove(key);
}
