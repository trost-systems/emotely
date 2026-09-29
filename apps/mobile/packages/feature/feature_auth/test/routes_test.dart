import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

import 'sign_in_robot.dart';

void main() {
  group(SignInRoute, () {
    testWidgets('shows the sign-in screen at its location', (tester) async {
      registerUtilitiesUnderTest(
        GetIt.I,
        agent: AgentStub(),
        supabase: SupabaseStub(),
        analytics: AnalyticsSpy(),
      );
      registerAuth(GetIt.I, google: SignInRobot.googleClients);
      GetIt.I.registerSingleton<SignInNavigator>(FakeSignInNavigator());

      await tester.pumpWidget(
        featureUnderTest(
          routes: [$signInRoute],
          initialLocation: const SignInRoute(mode: SignInMode.signUp).location,
          // The auth bloc sits above every screen in the app.
          above: (_, child) =>
              BlocProvider(create: (_) => GetIt.I<AuthBloc>(), child: child),
          localizations: SignInRobot.localizations,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<SignInPage>(find.byType(SignInPage)).mode,
        SignInMode.signUp,
      );
    });

    test('opens as a sign-in unless it says otherwise', () {
      expect(const SignInRoute().location, '/sign-in');
      expect(
        const SignInRoute(mode: SignInMode.signUp, from: '/x').location,
        '/sign-in?mode=sign-up&from=%2Fx',
      );
    });
  });
}
