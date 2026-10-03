import 'package:agent_client/agent_client.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart'
    show AppleIDAuthorizationScopes, AuthorizationErrorCode;
import 'package:testing/testing.dart';

import '../sign_in_robot.dart';

/// Apple's native sheet exists on iOS alone.
final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
final android = TargetPlatformVariant.only(TargetPlatform.android);

/// What revoking the account's grants talks to, composed the way the app
/// composes it: the utilities over a scripted Supabase and agent, the
/// provider sheets faked at their platform channels.
class _Grants({required final List<String> providers}) {
  final supabase = SupabaseStub();
  final agent = AgentStub();
  final analytics = AnalyticsSpy();
  final google = GoogleSignInFake.setup();
  final apple = AppleSignInFake.setup();

  /// Signed in to an account with [providers] linked, revokes its grants
  /// and lets the reports it queued reach the spy.
  Future<Set<IdentityProvider>> revoke(WidgetTester tester) async {
    final left = await (await compose()).revoke();
    await tester.pumpAndSettle();
    return left;
  }

  /// The grants of an account with [providers] linked, signed in.
  Future<ProviderGrants> compose() async {
    await supabase.signedIn(provider: providers.first, providers: providers);
    registerUtilitiesUnderTest(
      GetIt.I,
      agent: agent,
      supabase: supabase,
      analytics: analytics,
    );
    registerAuth(GetIt.I, google: SignInRobot.googleClients);
    return GetIt.I<ProviderGrants>();
  }

  /// How often the agent was asked to revoke an Apple grant: the only
  /// request it gets here.
  int get appleRevocations => agent.requests.length;

  List<Map<String, Object>> get reported => [
    for (final exception in analytics.exceptions) exception.properties,
  ];
}

void main() {
  group(ProviderGrants, () {
    testWidgets('warns of Apple’s sheet only where it will appear', (
      tester,
    ) async {
      final apple = await _Grants(providers: ['email', 'apple']).compose();
      expect(apple.asksApple, isTrue);
    }, variant: iOS);

    testWidgets('never warns of Apple’s sheet on Android', (tester) async {
      final apple = await _Grants(providers: ['apple']).compose();
      expect(apple.asksApple, isFalse);
    }, variant: android);

    testWidgets('never warns of Apple’s sheet to a Google account', (
      tester,
    ) async {
      final google = await _Grants(providers: ['google']).compose();
      expect(google.asksApple, isFalse);
    }, variant: iOS);

    testWidgets('revokes an Apple grant with a fresh code from the sheet', (
      tester,
    ) async {
      final grants = _Grants(providers: ['apple']);
      grants.apple.script([appleToken('apple-id-token')]);
      grants.agent.script([revoked()]);

      final left = await grants.revoke(tester);

      expect(left, isEmpty);
      // A fresh credential asks for nothing: no name, no address.
      expect(
        grants.apple.requests.single.scopes,
        <AppleIDAuthorizationScopes>[],
      );
      expect(grants.agent.lastRequest, {'authorization_code': 'apple-code'});
      expect(
        grants.agent.lastHeaders['authorization'],
        'Bearer ${SupabaseStub.jwt(sub: SupabaseStub.userId)}',
      );
      expect(grants.reported, isEmpty);
    }, variant: iOS);

    testWidgets('leaves the Apple grant when the user dismisses the sheet', (
      tester,
    ) async {
      final grants = _Grants(providers: ['apple']);
      grants.apple.script([appleFailed(AuthorizationErrorCode.canceled)]);

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.apple});
      expect(grants.appleRevocations, 0);
      // Dismissing is the user's choice, not a failure to report.
      expect(grants.reported, isEmpty);
    }, variant: iOS);

    testWidgets('reports and leaves the Apple grant when the agent refuses', (
      tester,
    ) async {
      final grants = _Grants(providers: ['apple']);
      grants.apple.script([appleToken('apple-id-token')]);
      grants.agent.script([
        refused(502, AgentErrorCode.appleRevocationUnavailable),
      ]);

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.apple});
      expect(grants.reported, [
        {'step': 'sign_in_revocation', 'provider': 'apple'},
      ]);
    }, variant: iOS);

    testWidgets('reports and leaves the Apple grant when the sheet fails', (
      tester,
    ) async {
      final grants = _Grants(providers: ['apple']);
      grants.apple.script([appleFailed(AuthorizationErrorCode.failed)]);

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.apple});
      expect(grants.appleRevocations, 0);
      expect(grants.reported, [
        {'step': 'sign_in_revocation', 'provider': 'apple'},
      ]);
    }, variant: iOS);

    testWidgets('cannot reach an Apple grant where Apple has no sheet', (
      tester,
    ) async {
      final grants = _Grants(providers: ['email', 'apple']);

      final left = await grants.revoke(tester);

      // Android has no native Apple sheet, so nothing is asked of anyone.
      expect(left, {IdentityProvider.apple});
      expect(grants.apple.requests, isEmpty);
      expect(grants.reported, isEmpty);
    }, variant: android);

    testWidgets('disconnects the Google account the device remembers', (
      tester,
    ) async {
      final grants = _Grants(providers: ['google']);
      grants.google.remembered = googleRemembered;

      final left = await grants.revoke(tester);

      expect(left, isEmpty);
      expect(grants.google.disconnects, 1);
      // Set up with the app's clients, as for a sign-in.
      expect(
        grants.google.inits.single.clientId,
        SignInRobot.googleClients.ios,
      );
    });

    testWidgets('leaves the Google grant when no account comes back', (
      tester,
    ) async {
      final grants = _Grants(providers: ['google']);

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.google});
      expect(grants.google.disconnects, 0);
      expect(grants.reported, isEmpty);
    });

    testWidgets('reports and leaves the Google grant when Google refuses', (
      tester,
    ) async {
      final grants = _Grants(providers: ['google']);
      grants.google
        ..remembered = googleRemembered
        ..disconnectFails = true;

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.google});
      expect(grants.reported, [
        {'step': 'sign_in_revocation', 'provider': 'google'},
      ]);
    });

    testWidgets('revokes every grant the account holds, and only those', (
      tester,
    ) async {
      final grants = _Grants(providers: ['email', 'google', 'apple']);
      grants.google.remembered = googleRemembered;
      grants.apple.script([appleFailed(AuthorizationErrorCode.canceled)]);

      final left = await grants.revoke(tester);

      expect(left, {IdentityProvider.apple});
      expect(grants.google.disconnects, 1);
      expect(grants.apple.requests, hasLength(1));
    }, variant: iOS);

    testWidgets('asks no provider anything for an email-code account', (
      tester,
    ) async {
      final grants = _Grants(providers: ['email']);

      final left = await grants.revoke(tester);

      expect(left, isEmpty);
      expect(grants.google.inits, isEmpty);
      expect(grants.apple.requests, isEmpty);
    }, variant: iOS);
  });
}
