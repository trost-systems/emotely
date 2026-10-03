/// The integration tests' own `--dart-define`s: what they need beyond the
/// app's (`package:emotely/app/environment.dart`), read only here and never
/// from `lib/`, so no build of the app can carry them.
library;

/// The smoke account's password (`--dart-define=SMOKE_PASSWORD=…`). The
/// live session signs in with it before the app starts; its email is the
/// app's own `smokeEmail`.
const smokePassword = String.fromEnvironment('SMOKE_PASSWORD');

/// The screens the performance survey walks (`--dart-define=
/// SURVEY_SCREENS=journal,entry`), comma-separated; empty, all of them
/// (`survey_test.dart`).
const surveyOnly = String.fromEnvironment('SURVEY_SCREENS');

/// Whether the survey writes survey.json to the device
/// (`--dart-define=SURVEY_ON_DEVICE=true`): a Test Lab build, where no
/// driver receives it.
const surveyOnDevice = bool.fromEnvironment('SURVEY_ON_DEVICE');
