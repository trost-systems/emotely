import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every frame the engine draws while [action] runs, as the engine timed
/// it: each frame's build (UI thread) and raster time and the start of its
/// vsync, in microseconds, in the order drawn.
///
/// The survey measures on the phone itself, where nothing on a host can
/// read a timeline: Test Lab runs the test with no driver attached. So
/// this reads the engine's [FrameTiming]s, the numbers a user's frames
/// really took, which `watchPerformance` also reads but without its
/// timeline of garbage collections, which needs the VM service.
Future<Map<String, Object?>> watchFrames(Future<void> Function() action) async {
  final timings = <FrameTiming>[];
  // The engine hands timings over in batches (at most a second apart in a
  // profile build): the previous screen's last frames go by first.
  await Future<void>.delayed(const Duration(seconds: 2));
  void collect(List<FrameTiming> batch) => timings.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  try {
    await action();
    await Future<void>.delayed(const Duration(seconds: 2));
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
  if (timings.isEmpty) {
    return const {
      'frame_count': 0,
      'frame_build_times': <int>[],
      'frame_rasterizer_times': <int>[],
      'frame_vsync_starts': <int>[],
    };
  }
  final summary = FrameTimingSummarizer(timings).summary;
  return {
    for (final key in const [
      'frame_count',
      'frame_build_times',
      'frame_rasterizer_times',
    ])
      key: summary[key],
    // When each frame's vsync arrived: the rate the display really ran at,
    // which an adaptive display does not report up front.
    'frame_vsync_starts': [
      for (final timing in timings)
        timing.timestampInMicroseconds(FramePhase.vsyncStart),
    ],
  };
}
