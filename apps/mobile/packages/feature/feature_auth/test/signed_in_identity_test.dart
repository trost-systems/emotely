import 'package:feature_auth/feature_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;
import 'package:testing/testing.dart';

import 'sign_in_robot.dart';

void main() {
  group(AuthSignedIn, () {
    testWidgets('carries the address and the method of a password sign-in', (
      tester,
    ) async {
      final supabase = SupabaseStub()
        ..script(password: [sessionGranted(provider: 'email')]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.submitCredentials();

      expect(
        robot.state,
        const AuthState.signedIn(
          userId: SupabaseStub.userId,
          identity: SignInIdentity(
            email: SupabaseStub.email,
            method: SignInVia.email,
          ),
        ),
      );
    });

    testWidgets('carries the method of a provider sign-in', (tester) async {
      GoogleSignInFake.setup().script([googleToken('google-id-token')]);
      final supabase = SupabaseStub()
        ..script(idToken: [sessionGranted(provider: 'google')]);
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      await robot.tapGoogle();
      await robot.settle();

      expect((robot.state as AuthSignedIn).identity.method, SignInVia.google);
    });

    testWidgets('carries a restored session, and flags Apple’s relay', (
      tester,
    ) async {
      const relay = 'x7k2@privaterelay.appleid.com';
      final supabase = SupabaseStub();
      await supabase.signedIn(email: relay, provider: 'apple');
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      final identity = (robot.state as AuthSignedIn).identity;
      expect(identity.email, relay);
      expect(identity.method, SignInVia.apple);
      expect(identity.hiddenByApple, isTrue);
    });

    testWidgets('follows the same user to a new address', (tester) async {
      const changed = 'new@example.com';
      final supabase = SupabaseStub();
      await supabase.signedIn(provider: 'email');
      final robot = SignInRobot(tester, supabase: supabase, agent: AgentStub());
      await robot.launch();

      supabase.rest('PUT /auth/v1/user', [userUpdated(email: changed)]);
      await supabase.supabase.auth.updateUser(UserAttributes(email: changed));
      await robot.settle();

      expect((robot.state as AuthSignedIn).identity.email, changed);
      // Still the one sign-in: an address is not a new user.
      expect(robot.analytics.events, isEmpty);
    });
  });
}
