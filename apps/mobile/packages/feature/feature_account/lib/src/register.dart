import 'package:feature_account/src/account/bloc/account_bloc.dart';
import 'package:feature_account/src/consent/bloc/consent_bloc.dart';
import 'package:feature_account/src/profile/bloc/profile_bloc.dart';
import 'package:feature_account/src/usage_analytics/bloc/usage_analytics_bloc.dart';
import 'package:get_it/get_it.dart';

/// The account feature's registrations: its four blocs, a fresh one per
/// owner. The consent bloc is owned by whichever screen gates on it — the
/// journal today, the account screen alongside — and read by the screens
/// that share that owner's route. The usage-analytics bloc is owned by the
/// first-launch sheet and by Privacy settings, each over the one consent
/// they share.
///
/// The app registers an `AccountNavigator` implementation itself; it is the
/// app's to provide, not this feature's.
void registerAccount(GetIt getIt) => getIt
  ..registerFactory(
    () => AccountBloc(
      supabase: getIt(),
      analytics: getIt(),
      errors: getIt(),
      build: getIt(),
    ),
  )
  ..registerFactory(
    () => ConsentBloc(repository: getIt(), analytics: getIt(), errors: getIt()),
  )
  ..registerFactory(
    () => UsageAnalyticsBloc(consent: getIt(), analytics: getIt()),
  )
  ..registerFactory(
    () => ProfileBloc(repository: getIt(), errors: getIt(), analytics: getIt()),
  );
