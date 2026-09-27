import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_onboarding/src/bloc/onboarding_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

void main() {
  group('registerOnboarding', () {
    test(
      'registers one store for the device and the bloc as a factory',
      () async {
        final getIt = GetIt.asNewInstance();
        registerUtilitiesUnderTest(
          getIt,
          agent: AgentStub(),
          supabase: SupabaseStub(),
          analytics: AnalyticsSpy(),
        );
        registerOnboarding(getIt);

        expect(getIt<OnboardingStore>(), same(getIt<OnboardingStore>()));
        final bloc = getIt<OnboardingBloc>();
        expect(bloc, isNot(same(getIt<OnboardingBloc>())));
        await bloc.close();
      },
    );
  });
}
