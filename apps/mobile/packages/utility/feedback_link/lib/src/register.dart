import 'package:feedback_link/src/feedback_link.dart';
import 'package:get_it/get_it.dart';

/// Registers what the app knows about its own build, so a feature can put
/// it in a feedback mail without reading `package_info_plus` itself — the
/// app is the only layer that reads build-time values (ADR 0015).
///
/// The address and the label need no registration: they are constants.
void registerFeedbackLink(GetIt getIt, {required BuildInfo build}) =>
    getIt.registerSingleton<BuildInfo>(build);
