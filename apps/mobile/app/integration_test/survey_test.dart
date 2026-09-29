// The performance survey (#242): every screen of the feature map, walked in
// profile mode on a real phone, with each screen's frames as the engine
// timed them and the requests it made. Run through the survey script,
// never `flutter test`:
//
//   .claude/skills/run-app/scripts/survey.sh ftl --device SC-51E:36
//   .claude/skills/run-app/scripts/survey.sh local --device <id>
//
// On Firebase Test Lab no host drives the test, so it writes what it
// measured to the device (`survey.json`, below), where Test Lab pulls it
// from. Locally, the driver (test_driver/survey_driver.dart) receives the
// same document.
//
// The backend is the performance budget's in-process fake (perf/): the
// frames measure the app, not a connection, the request counts are exact
// and everything on screen is made up (ADR 0005).
//
// Two --dart-defines, both set by survey.sh:
// - SURVEY_SCREENS limits the walk to the screens it names, comma-separated;
//   an ad-hoc run chasing one screen takes a minute, not five.
// - SURVEY_ON_DEVICE=true writes survey.json to the device, for a Test Lab
//   build, where no driver receives it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf/compose.dart';
import 'perf/fake_backend.dart';
import 'survey/device_directory.dart';
import 'survey/survey_walk.dart';

const _screens = String.fromEnvironment('SURVEY_SCREENS');
const _onDevice = bool.fromEnvironment('SURVEY_ON_DEVICE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Frames come from the engine as on a phone, never from the test's own
    // pumps, which would add frames no user sees.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('the survey walks every screen of the feature map', (
    tester,
  ) async {
    final backend = FakeBackend.seeded();
    final app = await composeApp(backend);
    final survey = await SurveyWalk(tester, backend, app).run({
      for (final name in _screens.split(','))
        if (name.trim().isNotEmpty) name.trim(),
    });
    binding.reportData = {'survey': survey};
    if (_onDevice) {
      await _writeOnDevice(survey);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _writeOnDevice(Map<String, Object?> survey) async {
  final directory = await Directory(surveyDirectory()).create(recursive: true);
  final file = File('${directory.path}/survey.json');
  await file.writeAsString(jsonEncode(survey));
  // In the device's log, which Test Lab keeps: where to look when the pull
  // comes back empty.
  debugPrint('survey: wrote ${file.path}');
}
