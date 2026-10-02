/// The integration tests' own `--dart-define`s: what they need beyond the
/// app's (`package:emotely/app/environment.dart`), read only here and never
/// from `lib/`, so no build of the app can carry them.
library;

/// The smoke account's password (`--dart-define=SMOKE_PASSWORD=…`). The
/// live session signs in with it before the app starts; its email is the
/// app's own `smokeEmail`.
const smokePassword = String.fromEnvironment('SMOKE_PASSWORD');
