import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:testing/testing.dart';

void main() {
  group('registerProfileRepository', () {
    test('registers one repository over the client it is given', () {
      final getIt = GetIt.asNewInstance();
      final supabase = SupabaseStub();

      registerProfileRepository(getIt, supabase: supabase.supabase);

      expect(getIt<ProfileRepository>(), same(getIt<ProfileRepository>()));
      expect(getIt<ProfileRepository>().supabase, same(supabase.supabase));
    });
  });
}
