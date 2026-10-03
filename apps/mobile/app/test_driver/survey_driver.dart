// The host side of integration_test/survey_test.dart for a local run
// (`survey.sh local`): writes the survey the device reports to
// <PERF_OUT>/survey.json, the same document a Test Lab run pulls off the
// device. <PERF_OUT> defaults to Flutter's test outputs directory (`build`).

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final out = Platform.environment['PERF_OUT'] ?? testOutputsDirectory;
    await Directory(out).create(recursive: true);
    await File('$out/survey.json').writeAsString(jsonEncode(data?['survey']));
  },
);
