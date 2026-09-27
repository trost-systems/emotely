import 'package:feature_auth/src/bloc/auth_bloc.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_bloc.dart';
import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:feature_auth/src/providers/provider_sign_in.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The auth feature's registrations: the provider sheets, one per process
/// (google_sign_in takes a single `initialize`), set up with the app's
/// [google] clients; the way in last used, kept on the device like the
/// preferences underneath; and its blocs, factories like every bloc, of
/// which the app creates the one auth bloc it holds above every screen.
///
/// [passwordAccounts] are addresses that sign in with a password as the
/// review accounts do, on top of them; the app decides which (none in a
/// release build).
void registerAuth(
  GetIt getIt, {
  required GoogleClientIds google,
  Set<String> passwordAccounts = const {},
}) => getIt
  ..registerSingleton(ProviderSignIn(google: google))
  ..registerSingleton(LastSignInStore(preferences: SharedPreferencesAsync()))
  ..registerFactory(
    () => AuthBloc(
      supabase: getIt(),
      analytics: getIt(),
      errors: getIt(),
      providers: getIt(),
      lastSignIn: getIt(),
      passwordAccounts: passwordAccounts,
    ),
  )
  ..registerFactory(() => LastSignInBloc(store: getIt()));
