import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Where feedback from inside the app goes. The same address the site and
/// the notices name, so a reply comes from somewhere the user recognises.
const feedbackAddress = 'hello@getemotely.com';

/// What the app knows about itself, for the footer of a feedback mail:
/// enough to tell one build and one device class from another, and nothing
/// that identifies the person writing.
///
/// The version and the build number are the app's to supply (it is the only
/// layer that reads `package_info_plus`, ADR 0015); the platform and its
/// version this package can read for itself, which is what `ofPlatform`
/// does.
class const BuildInfo({
  /// The app's marketing version, pubspec's `version` without the build.
  required final String version,

  /// The build number after the `+` — what tells two TestFlight builds of
  /// the same version apart, and the first thing a bug report needs.
  required final String buildNumber,

  /// `iOS` or `Android`, as the user would name it.
  required final String platform,

  /// Whatever the OS calls its own version.
  required final String operatingSystemVersion,

  /// The device model, if it is known for free. Nothing reads it today;
  /// naming a model would cost a plugin, and a feedback mail is not worth
  /// one, so this stays a parameter a later build can fill.
  final String? deviceModel,
}) {
  /// The build facts the running platform already knows, with the version
  /// and build number the app hands in.
  factory ofPlatform({required String version, required String buildNumber}) =>
      BuildInfo(
        version: version,
        buildNumber: buildNumber,
        platform: _platformName,
        operatingSystemVersion: Platform.operatingSystemVersion,
      );

  /// What the user would call the platform, rather than the token
  /// `Platform.operatingSystem` returns (`ios`, `android`).
  static String get _platformName => switch (Platform.operatingSystem) {
    'ios' => 'iOS',
    'android' => 'Android',
    final other => other,
  };

  /// `1.2.3+42` — one string, because a build is only ever read as a pair.
  String get versionAndBuild => '$version+$buildNumber';
}

/// The prefilled mail: who it goes to, what it is about, and a footer of
/// the facts that make a report usable.
///
/// Built through [Uri] rather than a hand-written string so the spaces in
/// the subject and the newlines in the body are percent-encoded the way
/// every mail app expects to read them back.
///
/// Deliberately carries no user id, no email address and nothing from the
/// journal: the mail itself already says who sent it, and everything else
/// is the user's to write.
Uri feedbackMailUri(BuildInfo build) => Uri(
  scheme: 'mailto',
  path: feedbackAddress,
  query: _encodeQueryParameters({
    'subject':
        'emotely feedback (${build.versionAndBuild}, '
        '${build.platform} ${build.operatingSystemVersion})',
    'body': _body(build),
  }),
);

/// A blank line for the user to write in, then the footer. The user's
/// cursor lands at the top; the footer is below, where it can be left alone
/// or deleted.
String _body(BuildInfo build) => [
  '\n',
  '---',
  'App version: ${build.versionAndBuild}',
  'Platform: ${build.platform}',
  'OS version: ${build.operatingSystemVersion}',
  if (build.deviceModel case final model?) 'Device: $model',
].join('\n');

/// `Uri`'s own query encoding treats a query as a map it may reorder and
/// re-escape per RFC 3986, which leaves `+` in a body meaning a space to
/// the mail app. Encoding each pair with [Uri.encodeComponent] and joining
/// them is what the url_launcher documentation prescribes for `mailto:`.
String _encodeQueryParameters(Map<String, String> parameters) => parameters
    .entries
    .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');

/// Opens the platform's mail app on a new message to [feedbackAddress].
/// Fire-and-forget like the other links here: if no mail app is set up
/// there is nothing this screen can do about it.
Future<void> openFeedbackMail(BuildInfo build) =>
    launchUrl(feedbackMailUri(build));
