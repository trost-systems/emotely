import 'package:flutter/widgets.dart';

/// Which door the sign-in screen is (#204, ADR 0019).
enum SignInMode() {
  /// The last step of onboarding: "Almost there, {name}". An email code
  /// from here creates the account when there is none.
  signUp,

  /// "I have an account": "Welcome back". An email code from here never
  /// creates an account.
  signIn,
}

/// What the sign-in screen asks of the app and cannot know itself, because
/// a feature never knows another feature (ADR 0015): onboarding is
/// another feature's, and so is the name it asked for. The app implements
/// this with onboarding's store and routes; a test fakes it.
abstract class SignInNavigator() {
  /// The name sign-up greets the user by: the one onboarding asked for,
  /// typed or placeholder, if there is one.
  String? signUpName();

  /// Back out of the screen opened as [mode]: from sign-up to the greeting
  /// before it, from sign-in to Welcome.
  void leave(BuildContext context, SignInMode mode);
}
