import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/l10n/l10n.dart';
import 'package:feature_auth/src/view/last_used_tag.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

/// What the sign-in screen asked of the app, and the name onboarding
/// would hand it.
class FakeSignInNavigator({final String? name}) extends SignInNavigator {
  final left = <SignInMode>[];

  @override
  String? signUpName() => name;

  @override
  void leave(BuildContext context, SignInMode mode) => left.add(mode);
}

/// A password long enough to choose, and one that is not.
const goodPassword = 'correct horse battery staple';
const shortPassword = 'too short';

/// The six digits a scripted mail carries.
const code = '482913';

/// Drives sign-in on the feature's own screen, composed the way the app
/// composes it, against a scripted Supabase. The root mirrors the app's:
/// the sign-in screen while nobody is signed in, a stand-in for the
/// journal once someone is.
class SignInRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
  final SignInMode mode = SignInMode.signIn,
  final String? name,
  final Locale locale = const Locale('de'),
  final ThemeMode themeMode = ThemeMode.light,
  final HumanCheckStub? humanCheck,
}) {
  final analytics = AnalyticsSpy();
  late final navigator = FakeSignInNavigator(name: name);

  static const homeKey = Key('home');

  /// Public client ids, but not the real ones: nothing here talks to Google.
  static const googleClients = GoogleClientIds(
    server: 'server.apps.googleusercontent.com',
    ios: 'ios.apps.googleusercontent.com',
  );

  Finder get signIn => find.byType(SignInPage);
  Finder get home => find.byKey(homeKey);
  Finder get emailField => find.byKey(SignInPage.emailKey);
  Finder get passwordField => find.byKey(SignInPage.passwordKey);
  Finder get submit => find.byKey(SignInPage.submitKey);
  Finder get forgotPassword => find.byKey(SignInPage.forgotPasswordKey);
  Finder get codeField => find.byKey(SignInPage.codeKey);
  Finder get confirm => find.byKey(SignInPage.confirmKey);
  Finder get newPasswordField => find.byKey(SignInPage.newPasswordKey);
  Finder get savePassword => find.byKey(SignInPage.savePasswordKey);
  Finder get resendCode => find.byKey(SignInPage.resendCodeKey);
  Finder get codeResent => find.byKey(SignInPage.codeResentKey);
  Finder get changeEmail => find.byKey(SignInPage.changeEmailKey);
  Finder get error => find.byKey(SignInPage.errorKey);
  Finder get busy => find.byType(CircularProgressIndicator);
  Finder get googleButton => find.byKey(SignInPage.googleKey);
  Finder get appleButton => find.byKey(SignInPage.appleKey);
  Finder get back => find.byKey(SignInPage.backKey);
  Finder get heading => find.byKey(SignInPage.headingKey);

  /// The "Last used" tag, over whichever button it marks.
  Finder get lastUsed => find.byType(LastUsedTag);

  /// The tag's pill itself, as a sighted user reads it.
  Finder get lastUsedPill => find.text(strings.lastUsedTag);

  /// Whether [button] is the one the "Last used" tag marks.
  bool tagged(Finder button) =>
      find.ancestor(of: button, matching: lastUsed).evaluate().isNotEmpty;

  /// The way in this device keeps from an earlier sign-in: call before
  /// [launch], as a relaunch finds it.
  Future<void> keep(SignInOption option) =>
      LastSignInStore(preferences: analytics.preferences).remember(option);

  /// The way in this device keeps now.
  Future<SignInOption?> kept() =>
      LastSignInStore(preferences: analytics.preferences).read();

  /// The screen's strings in the locale it is shown in: what every
  /// expectation about its words reads, so a test holds in any locale.
  AuthLocalizations get strings => tester.element(signIn).l10n;

  String get headingText => tester.widget<Text>(heading).data!;

  String get errorText => tester.widget<Text>(error).data!;

  /// What the auth bloc above every screen holds now: what the app's other
  /// screens are handed.
  AuthState get state => tester
      // The root's, the first: the screen's own steps build on it too.
      .element(find.byType(BlocBuilder<AuthBloc, AuthState>).first)
      .read<AuthBloc>()
      .state;

  /// Why the step on screen failed last, as the bloc words it for the
  /// screen: a reason, never text.
  SignInProblem? get problem => switch (state) {
    AuthSignedOut(:final problem) ||
    AuthCodeSent(:final problem) ||
    AuthNewPasswordRequired(:final problem) => problem,
    _ => null,
  };

  /// The step failed for [reason], and the screen says so in [words].
  void expectError(SignInProblem reason, String words) {
    expect(problem, reason);
    expect(errorText, words);
  }

  bool get canTapGoogle =>
      tester.widget<ProviderButton>(googleButton).onPressed != null;
  bool get canTapApple =>
      tester.widget<ProviderButton>(appleButton).onPressed != null;
  bool get canSubmit => tester.widget<FilledButton>(submit).onPressed != null;
  bool get canReset =>
      tester.widget<TextButton>(forgotPassword).onPressed != null;
  bool get canConfirm => tester.widget<FilledButton>(confirm).onPressed != null;
  bool get canSavePassword =>
      tester.widget<FilledButton>(savePassword).onPressed != null;
  bool obscured(Finder field) => tester.widget<TextField>(field).obscureText;

  /// The bodies the app posted to [path], in order.
  List<Map<String, dynamic>> posted(String path) =>
      supabase.bodies('/auth/v1/$path');

  /// The auth bloc above every screen and the one decision the app makes
  /// with it — signed in or not. Reading this composes the container.
  Widget get app {
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: agent,
      supabase: supabase,
      analytics: analytics,
      humanCheck: humanCheck,
    );
    registerAuth(GetIt.I, google: googleClients);
    GetIt.I.registerSingleton<SignInNavigator>(navigator);
    final root = BlocProvider(
      create: (_) => GetIt.I<AuthBloc>(),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) => state is AuthSignedIn
            ? const Scaffold(
                body: Center(child: Text('home', key: homeKey)),
              )
            : SignInPage(mode: mode),
      ),
    );
    return pageUnderTest(
      root,
      localizations: localizations,
      locale: locale,
      themeMode: themeMode,
    );
  }

  /// The feature's own strings, as the app composes them.
  static const localizations = [AuthLocalizations.delegate];

  Future<void> launch() async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.pump();
  }

  Future<void> settle() => tester.pumpAndSettle();

  Future<void> _type(Finder field, String text) async {
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> _tap(Finder button) async {
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> enterEmail(String email) => _type(emailField, email);
  Future<void> enterPassword(String password) => _type(passwordField, password);
  Future<void> enterCode(String typed) => _type(codeField, typed);
  Future<void> enterNewPassword(String password) =>
      _type(newPasswordField, password);

  Future<void> tapSubmit() => _tap(submit);
  Future<void> tapForgotPassword() => _tap(forgotPassword);
  Future<void> tapConfirm() => _tap(confirm);
  Future<void> tapSavePassword() => _tap(savePassword);
  Future<void> tapResendCode() => _tap(resendCode);
  Future<void> tapChangeEmail() => _tap(changeEmail);
  Future<void> tapGoogle() => _tap(googleButton);
  Future<void> tapApple() => _tap(appleButton);

  /// The keyboard's "done" action on [field].
  Future<void> submitFromKeyboard(Finder field) async {
    await tester.showKeyboard(field);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  /// Signs out from wherever a signed-in user is, as the Profile screen
  /// asks the app to; the Supabase stub needs a `logout:` round.
  Future<void> signOut() async {
    tester
        .element(find.byType(BlocBuilder<AuthBloc, AuthState>).first)
        .read<AuthBloc>()
        .add(const AuthEvent.signOutRequested());
    await settle();
  }

  /// Types [email] and [password] and submits them: a sign-in, or a new
  /// account in [SignInMode.signUp].
  Future<void> submitCredentials({
    String email = SupabaseStub.email,
    String password = goodPassword,
  }) async {
    await enterEmail(email);
    await enterPassword(password);
    await tapSubmit();
    await settle();
  }

  /// Types [email] and asks for a reset code.
  Future<void> requestReset([String email = SupabaseStub.email]) async {
    await enterEmail(email);
    await tapForgotPassword();
    await settle();
  }

  /// Types the confirmation [typed] code and confirms it.
  Future<void> confirmWith([String typed = code]) async {
    await enterCode(typed);
    await tapConfirm();
    await settle();
  }

  /// Types the reset [typed] code and [password] and saves them.
  Future<void> resetWith({
    String typed = code,
    String password = goodPassword,
  }) async {
    await enterCode(typed);
    await enterNewPassword(password);
    await tapSavePassword();
    await settle();
  }
}
