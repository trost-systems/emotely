/// The app's side of the consent record (ADR 0014): read from the server,
/// never from the device, because a local flag would not survive a reinstall
/// and would not be the proof Art. 7 (1) asks the controller for.
library;

export 'src/consent_repository.dart';
export 'src/register.dart';
export 'src/usage_analytics_consent.dart';
