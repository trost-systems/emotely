import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Where Test Lab pulls the survey from: a directory the app may write
/// without asking for a permission.
///
/// - Android: its own external files directory, which Test Lab may pull
///   (`--directories-to-pull` allows /sdcard) and which the instrumentation
///   test creates (android/app/src/androidTest).
/// - iOS: its Documents, which Test Lab pulls as
///   `<bundle id>:/Documents/survey`. Under Test Lab's XCTest runner the app
///   has no HOME (a first run failed on `null/Documents`), so the container
///   comes from the one place that always knows it: the per-app temporary
///   directory Darwin keeps in it (`confstr(_CS_DARWIN_USER_TEMP_DIR)`,
///   what `NSTemporaryDirectory()` returns), whose parent is the container.
String surveyDirectory() => Platform.isIOS
    ? '${File(_darwinTemporaryDirectory()).parent.path}/Documents/survey'
    : '/sdcard/Android/data/de.emotely.emotely/files/survey';

/// `_CS_DARWIN_USER_TEMP_DIR` in Darwin's `unistd.h`.
const _darwinUserTempDir = 65537;

String _darwinTemporaryDirectory() {
  final confstr = DynamicLibrary.process()
      .lookupFunction<
        Size Function(Int, Pointer<Utf8>, Size),
        int Function(int, Pointer<Utf8>, int)
      >('confstr');
  const capacity = 1024;
  final buffer = calloc<Uint8>(capacity).cast<Utf8>();
  try {
    final length = confstr(_darwinUserTempDir, buffer, capacity);
    if (length == 0 || length > capacity) {
      throw StateError('confstr found no temporary directory for the app');
    }
    // A trailing slash would make `parent` the directory itself.
    return buffer.toDartString().replaceFirst(RegExp(r'/+$'), '');
  } finally {
    calloc.free(buffer);
  }
}
