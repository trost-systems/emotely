import 'package:feature_session/src/bloc/session_bloc.dart';
import 'package:get_it/get_it.dart';

/// The session feature's registrations: its bloc, a fresh one per screen,
/// reading when a session starts from [now] (the clock; a test pins it).
/// The bloc also needs a `UserContextSource`, which is the app's to
/// register, like a navigator: resolved when a bloc is made, not here, and
/// closed with the bloc.
void registerSession(GetIt getIt, {DateTime Function() now = DateTime.now}) =>
    getIt.registerFactory(
      () => SessionBloc(
        agentClient: getIt(),
        analytics: getIt(),
        errors: getIt(),
        repository: getIt(),
        userContext: getIt(),
        now: now,
      ),
    );
