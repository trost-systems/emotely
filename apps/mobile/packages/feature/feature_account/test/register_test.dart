import 'package:feature_account/feature_account.dart';
import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

void main() {
  group('registerAccount', () {
    test('registers the three blocs as factories over the utilities', () async {
      final getIt = GetIt.asNewInstance();
      registerUtilitiesUnderTest(
        getIt,
        agent: AgentStub(),
        supabase: SupabaseStub(),
        analytics: AnalyticsSpy(),
      );

      registerAccount(getIt);

      final account = getIt<AccountBloc>();
      final consent = getIt<ConsentBloc>();
      final usage = getIt<UsageAnalyticsBloc>();
      expect(account, isNot(same(getIt<AccountBloc>())));
      expect(consent, isNot(same(getIt<ConsentBloc>())));
      expect(usage, isNot(same(getIt<UsageAnalyticsBloc>())));
      await account.close();
      await consent.close();
      await usage.close();
    });
  });
}
