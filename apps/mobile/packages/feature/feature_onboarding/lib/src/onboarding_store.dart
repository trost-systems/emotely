import 'dart:async';
import 'dart:convert';

import 'package:analytics/analytics.dart';
import 'package:feature_onboarding/src/flow.dart';
import 'package:feature_onboarding/src/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding progress as this device keeps it, before any account exists
/// (#204, ADR 0019): read once at launch, then held in memory so the
/// router can ask it synchronously where a signed-out user belongs, and
/// written through on every change so a restart resumes at the step
/// reached.
///
/// One per process, like the preferences underneath: it holds the device's
/// progress, not a user's, and is cleared once the account exists and on
/// every sign-out.
class OnboardingStore({
  required final SharedPreferencesAsync _preferences,
  final OnboardingFlow _flow = onboardingFlow,
}) {
  /// The one key this store owns.
  static const key = 'onboarding_progress';

  var _progress = const OnboardingProgress();

  final _changes = StreamController<OnboardingProgress>.broadcast();

  /// The progress as it stands.
  OnboardingProgress get progress => _progress;

  /// Every change of [progress] from here on.
  Stream<OnboardingProgress> get changes => _changes.stream;

  /// Whether every step before sign-up is done, so a signed-out user
  /// belongs on sign-up rather than in onboarding.
  bool get readyForAccount => _flow.readyForAccount(_progress);

  /// Reads the progress this device kept. `main` awaits it before the
  /// first frame, so the router's first question already has its answer.
  /// Progress kept under another flow version, or in a shape this build
  /// cannot read, starts the flow over: resuming at a step that no longer
  /// means the same would be worse than asking again.
  Future<void> restore() async {
    _set(_decode(await _preferences.getString(key)));
  }

  /// Keeps [progress], in memory at once and on the device.
  Future<void> save(OnboardingProgress progress) async {
    _set(progress);
    await _preferences.setString(key, _encode(progress));
  }

  /// Back from sign-up to the last step before it.
  Future<void> reopen() => switch (_flow.of(OnboardingPhase.beforeSignUp)) {
    [..., final last] => save(
      _progress.copyWith(completed: {..._progress.completed}..remove(last.id)),
    ),
    [] => Future.value(),
  };

  /// Forgets the progress: the account now holds what it was for, or
  /// someone signed out and the next person starts at Welcome.
  Future<void> clear() async {
    _set(const OnboardingProgress());
    await _preferences.remove(key);
  }

  void _set(OnboardingProgress progress) {
    _progress = progress;
    _changes.add(progress);
  }

  String _encode(OnboardingProgress progress) => jsonEncode({
    'flow_version': _flow.version,
    'completed': [for (final id in progress.completed) id.wire],
    'draft': progress.draft,
    'placeholder': progress.placeholder,
    'started': progress.started,
  });

  OnboardingProgress _decode(String? stored) {
    final Object? json;
    try {
      json = stored == null ? null : jsonDecode(stored);
    } on FormatException {
      return const OnboardingProgress();
    }
    return switch (json) {
      {
        'flow_version': final int version,
        'completed': final List<Object?> completed,
        'draft': final String draft,
        'placeholder': final String? placeholder,
        'started': final bool started,
      }
          when version == _flow.version =>
        OnboardingProgress(
          completed: {
            for (final id in OnboardingStepId.values)
              if (completed.contains(id.wire)) id,
          },
          draft: draft,
          placeholder: placeholder,
          started: started,
        ),
      _ => const OnboardingProgress(),
    };
  }
}
