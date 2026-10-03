import 'package:get_it/get_it.dart';
import 'package:human_check/src/human_check.dart';

/// The one [HumanCheck], over the [token] source the app wires to
/// Cloudflare Turnstile.
void registerHumanCheck(GetIt getIt, {required HumanCheckToken token}) =>
    getIt.registerSingleton<HumanCheck>(HumanCheck(token));
