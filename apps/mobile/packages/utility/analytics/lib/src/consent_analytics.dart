import 'package:analytics/src/post_hog_gate.dart';

/// Consent analytics, content-free by construction like the rest (ADR 0005).
///
/// What leaves the device is that a decision was made and which wording it
/// answered — never a word of what the user wrote, and never anything about
/// the user beyond the id PostHog already has. The version is what makes
/// these events worth having: it says how many people were asked again after
/// a wording change, and how many said no.
///
/// The methods take no arguments at all, so there is nothing a caller could
/// pass that should not go out; the version is fixed at construction.
class const ConsentAnalytics({
  required final PostHogGate gate,

  /// The wording the app currently asks consent for (its dated version), so
  /// the events say which text was answered. The app owns that constant;
  /// this package only reports it.
  required final String version,
}) {
  /// The user gave explicit consent, and the server recorded it.
  Future<void> consentGranted() => gate.capture(
    eventName: 'consent_granted',
    properties: {'version': version},
  );

  /// The user withdrew their consent (Art. 7 (3)).
  Future<void> consentWithdrawn() => gate.capture(
    eventName: 'consent_withdrawn',
    properties: {'version': version},
  );

  /// The user was asked and said no. Nothing was written to the server, but
  /// how often this happens is the one number that says whether the wording
  /// is frightening people off.
  Future<void> consentDeclined() => gate.capture(
    eventName: 'consent_declined',
    properties: {'version': version},
  );
}
