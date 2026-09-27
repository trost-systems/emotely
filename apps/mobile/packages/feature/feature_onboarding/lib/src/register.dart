import 'package:feature_onboarding/src/bloc/onboarding_bloc.dart';
import 'package:feature_onboarding/src/onboarding_store.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The onboarding feature's registrations: the device's progress, one per
/// process and user-agnostic like the preferences it lives in, which `main`
/// restores before the first frame; and the bloc, a fresh one per screen.
///
/// The app registers an `OnboardingNavigator` itself; it is the app's to
/// provide, not this feature's.
void registerOnboarding(GetIt getIt) => getIt
  ..registerSingleton(OnboardingStore(preferences: SharedPreferencesAsync()))
  ..registerFactory(
    () => OnboardingBloc(
      store: getIt(),
      profiles: getIt(),
      analytics: getIt(),
      errors: getIt(),
    ),
  );
