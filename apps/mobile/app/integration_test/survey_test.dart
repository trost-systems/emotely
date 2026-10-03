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
// Two --dart-defines, both set by survey.sh and read in environment.dart:
// SURVEY_SCREENS limits the walk to the screens it names (an ad-hoc run
// chasing one screen takes a minute, not five), and SURVEY_ON_DEVICE=true
// writes survey.json to the device, for a Test Lab build.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'environment.dart';
import 'perf/fake_backend.dart';
import 'perf/perf_paths.dart';
import 'survey/device_directory.dart';
import 'survey/survey_walk.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Frames come from the engine as on a phone, never from the test's own
    // pumps, which would add frames no user sees.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  testWidgets('the survey walks every screen of the feature map', (
    tester,
  ) async {
    // The budget's composition and paths (perf/perf_paths.dart), over its
    // fake backend.
    final paths = PerfPaths(tester, FakeBackend.seeded());
    await paths.compose();
    final survey = await SurveyWalk(tester, paths).run({
      for (final name in surveyOnly.split(','))
        if (name.trim().isNotEmpty) name.trim(),
    });
    binding.reportData = {'survey': survey};
    if (surveyOnDevice) {
      await _writeOnDevice(survey);
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

Future<void> _writeOnDevice(Map<String, Object?> survey) async {
  final json = jsonEncode(survey);
  final directory = await Directory(surveyDirectory()).create(recursive: true);
  final file = File('${directory.path}/survey.json');
  await file.writeAsString(json);
  debugPrintSynchronously('survey: wrote ${file.path}');
  await _logInChunks(json);
}

/// The characters of survey.json per log line: under the 1024 bytes an
/// iPhone's log keeps of a message.
const _chunk = 800;

/// survey.json in the device's log too, which Test Lab always keeps (an
/// iPhone's syslog, an Android phone's logcat): on an iPhone it has not
/// yet pulled the file back (`survey.sh from-log` puts it together).
/// Numbered, and between bars so that a space at a chunk's end survives.
/// Paced: logcat dropped a third of the lines written all at once.
Future<void> _logInChunks(String json) async {
  final count = (json.length / _chunk).ceil();
  for (var index = 0; index < count; index++) {
    final end = (index + 1) * _chunk;
    final chunk = json.substring(
      index * _chunk,
      end < json.length ? end : json.length,
    );
    debugPrintSynchronously('survey.json ${index + 1}/$count |$chunk|');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
