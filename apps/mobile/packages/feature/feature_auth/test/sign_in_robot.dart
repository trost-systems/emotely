import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/src/view/provider_buttons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:testing/testing.dart';

/// Drives sign-in on the feature's own screen, composed the way the app
/// composes it, against a scripted Supabase. The root mirrors the app's:
/// the sign-in screen while nobody is signed in, a stand-in for the
/// journal once someone is.
class SignInRobot(
  final WidgetTester tester, {
  required final SupabaseStub supabase,
  required final AgentStub agent,
  final Set<String> passwordAccounts = const {},
}) {
  final analytics = AnalyticsSpy();

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

  String get errorText => tester.widget<Text>(error).data!;

  bool get canTapGoogle =>
      tester.widget<GoogleSignInButton>(googleButton).onPressed != null;
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
    );
    registerAuth(
      GetIt.I,
      google: googleClients,
      passwordAccounts: passwordAccounts,
    );
    return pageUnderTest(
      BlocProvider(
        create: (_) => GetIt.I<AuthBloc>(),
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => state is AuthSignedIn
              ? const Scaffold(
                  body: Center(child: Text('home', key: homeKey)),
                )
              : const SignInPage(),
        ),
      ),
    );
  }

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
