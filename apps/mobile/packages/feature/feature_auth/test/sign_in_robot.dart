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

/// Drives sign-in on the feature's own screen, composed the way the app
/// composes it, against a scripted Supabase. The root mirrors the app's:
/// the sign-in screen while nobody is signed in, a stand-in for the
/// journal once someone is.
class SignInRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
  final Set<String> passwordAccounts = const {},
  final HumanCheckStub? humanCheck,
  final SignInMode mode = SignInMode.signIn,
  final String? name,
  final Locale locale = const Locale('de'),
  final ThemeMode themeMode = ThemeMode.light,
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
  Finder get sendCode => find.byKey(SignInPage.sendCodeKey);
  Finder get codeField => find.byKey(SignInPage.codeKey);
  Finder get submitCode => find.byKey(SignInPage.signInKey);
  Finder get passwordField => find.byKey(SignInPage.passwordKey);
  Finder get submitPassword => find.byKey(SignInPage.passwordSignInKey);
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
    AuthPasswordRequired(:final problem) => problem,
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
  bool get canSendCode =>
      tester.widget<FilledButton>(sendCode).onPressed != null;
  bool get canSubmitCode =>
      tester.widget<FilledButton>(submitCode).onPressed != null;
  bool get canSubmitPassword =>
      tester.widget<FilledButton>(submitPassword).onPressed != null;
  bool get passwordObscured =>
      tester.widget<TextField>(passwordField).obscureText;

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
    registerAuth(
      GetIt.I,
      google: googleClients,
      passwordAccounts: passwordAccounts,
    );
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

  Future<void> enterEmail(String email) async {
    await tester.enterText(emailField, email);
    await tester.pump();
  }

  Future<void> tapSendCode() async {
    await tester.tap(sendCode);
    await tester.pump();
  }

  Future<void> enterCode(String code) async {
    await tester.enterText(codeField, code);
    await tester.pump();
  }

  Future<void> tapSignIn() async {
    await tester.tap(submitCode);
    await tester.pump();
  }

  Future<void> tapGoogle() async {
    await tester.tap(googleButton);
    await tester.pump();
  }

  Future<void> tapApple() async {
    await tester.tap(appleButton);
    await tester.pump();
  }

  Future<void> tapChangeEmail() async {
    await tester.tap(changeEmail);
    await tester.pump();
  }

  Future<void> enterPassword(String password) async {
    await tester.enterText(passwordField, password);
    await tester.pump();
  }

  Future<void> tapPasswordSignIn() async {
    await tester.tap(submitPassword);
    await tester.pump();
  }

  /// The keyboard's "done" action on the password field.
  Future<void> submitPasswordFromKeyboard() async {
    await tester.showKeyboard(passwordField);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  /// Signs out from wherever a signed-in user is, as the Profile screen
  /// asks the app to; the Supabase stub needs a `logout:` round.
  Future<void> signOut() async {
    tester
        .element(find.byType(BlocBuilder<AuthBloc, AuthState>))
        .read<AuthBloc>()
        .add(const AuthEvent.signOutRequested());
    await settle();
  }

  /// Enters [email] and goes on to whichever step follows it.
  Future<void> submitEmail(String email) async {
    await enterEmail(email);
    await tapSendCode();
    await settle();
  }

  /// The happy path up to the code step.
  Future<void> requestCode([String email = SupabaseStub.email]) =>
      submitEmail(email);
}
