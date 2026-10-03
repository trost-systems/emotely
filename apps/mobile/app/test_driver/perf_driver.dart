// The host side of integration_test/perf_test.dart: receives each path's
// timeline and requests from the device and writes them where the budget
// gate reads them (`perf.sh gate`):
//
//   <out>/<path>.timeline.json          the whole trace, for a profiler
//   <out>/<path>.timeline_summary.json  frame build and raster times
//   <out>/requests.json                 each path's requests, in order
//
// <out> is PERF_OUT, else Flutter's test outputs directory (`build`).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final out = Platform.environment['PERF_OUT'] ?? testOutputsDirectory;
    await Directory(out).create(recursive: true);
    for (final MapEntry(:key, :value) in (data ?? const {}).entries) {
      if (key == 'requests') {
        await File('$out/requests.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(value));
      } else {
        final timeline = Timeline.fromJson(value as Map<String, dynamic>);
        await TimelineSummary.summarize(timeline)
            .writeTimelineToFile(key, destinationDirectory: out);
      }
    }
  },
);
