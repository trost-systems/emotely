import 'package:get_it/get_it.dart';
import 'package:profile_repository/src/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the repository as a singleton over [supabase], the real SDK
/// client — which is what a test scripts at the http seam.
void registerProfileRepository(
  GetIt getIt, {
  required SupabaseClient supabase,
}) => getIt.registerSingleton<ProfileRepository>(
  ProfileRepository(supabase: supabase),
);
