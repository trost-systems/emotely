import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing/testing.dart';

void main() {
  group(AuthAnalytics, () {
    test('names every sign-in milestone, and the user only by id', () async {
      final spy = AnalyticsSpy();
      final analytics = spy.authAnalytics;

      await analytics.signUpRequested();
      await analytics.signUpFailed();
      await analytics.confirmationCodeRejected();
      await analytics.passwordResetRequested();
      await analytics.passwordResetFailed();
      await analytics.resetCodeRejected();
      await analytics.passwordFailed();
      await analytics.identify(userId: 'user-1', internal: false);
      await analytics.providerCanceled(SignInMethod.google);
      await analytics.providerFailed(SignInMethod.apple);
      await analytics.signedIn(SignInMethod.password);
      await analytics.signedIn(SignInMethod.google);
      await analytics.signedIn(SignInMethod.apple);

      expect(spy.identified, ['user-1']);
      expect(spy.events, [
        event('sign_up_requested'),
        event('sign_up_failed'),
        event('sign_up_code_rejected'),
        event('password_reset_requested'),
        event('password_reset_failed'),
        event('password_reset_code_rejected'),
        event('sign_in_password_failed'),
        // Which way, never who: the provider's name is the one property.
        event('sign_in_provider_canceled', {'provider': 'google'}),
        event('sign_in_provider_failed', {'provider': 'apple'}),
        event('signed_in', {'method': 'password'}),
        event('signed_in', {'method': 'google'}),
        event('signed_in', {'method': 'apple'}),
      ]);
    });

    test('flags the person internal or not, never by email', () async {
      final spy = AnalyticsSpy();
      final analytics = spy.authAnalytics;

      await analytics.identify(userId: 'user-1', internal: true);
      await analytics.identify(userId: 'user-2', internal: false);

      expect(spy.identities, [
        identity('user-1', {r'$internal_or_test_user': true}),
        identity('user-2', {r'$internal_or_test_user': false}),
      ]);
    });

    test("forgets the device's user and their choice on sign-out", () async {
      final spy = AnalyticsSpy();

      await spy.authAnalytics.signedOut();

      expect(spy.events, [event('signed_out')]);
      expect(spy.lifecycle, ['setup', 'flush', 'reset', 'disable']);
      expect(spy.gate.choice, isNull);
    });

    test("forgets the device's user and their choice on deletion", () async {
      final spy = AnalyticsSpy();

      await spy.authAnalytics.accountDeleted();

      expect(spy.events, [event('account_deleted')]);
      expect(spy.lifecycle, ['setup', 'flush', 'reset', 'disable']);
      expect(spy.gate.choice, isNull);
    });
  });
}
