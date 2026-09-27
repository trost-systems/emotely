import 'package:feature_session/feature_session.dart';
import 'package:feature_session/src/bloc/session_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:testing/testing.dart';

import 'fake_user_context_source.dart';

void main() {
  group('registerSession', () {
    test('registers the bloc as a factory over the utilities', () async {
      final getIt = GetIt.asNewInstance();
      registerUtilitiesUnderTest(
        getIt,
        agent: AgentStub(),
        supabase: SupabaseStub(),
        analytics: AnalyticsSpy(),
      );

      registerSession(getIt);
      getIt.registerSingleton<UserContextSource>(FakeUserContextSource());

      final first = getIt<SessionBloc>();
      final second = getIt<SessionBloc>();
      expect(first, isNot(same(second)));
      await first.close();
      await second.close();
    });
  });
}
