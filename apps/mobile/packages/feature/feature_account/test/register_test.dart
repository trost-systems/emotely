import 'package:feature_account/feature_account.dart';
import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

import 'fake_account_device_data.dart';
import 'fake_sign_in_grants.dart';

void main() {
  group('registerAccount', () {
    test('registers its blocs as factories over the utilities', () async {
      final getIt = GetIt.asNewInstance();
      registerUtilitiesUnderTest(
        getIt,
        agent: AgentStub(),
        supabase: SupabaseStub(),
        analytics: AnalyticsSpy(),
      );

      registerAccount(getIt);
      getIt
        ..registerSingleton<AccountDeviceData>(FakeAccountDeviceData())
        ..registerSingleton<SignInGrants>(FakeSignInGrants());

      final account = getIt<AccountBloc>();
      final consent = getIt<ConsentBloc>();
      final usage = getIt<UsageAnalyticsBloc>();
      final profile = getIt<ProfileBloc>();
      expect(account, isNot(same(getIt<AccountBloc>())));
      expect(consent, isNot(same(getIt<ConsentBloc>())));
      expect(usage, isNot(same(getIt<UsageAnalyticsBloc>())));
      expect(profile, isNot(same(getIt<ProfileBloc>())));
      await account.close();
      await consent.close();
      await usage.close();
      await profile.close();
    });
  });
}
