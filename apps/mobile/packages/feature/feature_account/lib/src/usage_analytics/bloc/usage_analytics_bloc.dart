import 'package:analytics/analytics.dart';
import 'package:consent_repository/consent_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage_analytics_bloc.freezed.dart';
part 'usage_analytics_event.dart';

/// Where the usage-analytics choice stands, as a screen shows it.
enum UsageAnalyticsState() {
  /// Not read yet: nothing is shown, so the sheet never flashes up at
  /// someone who already answered.
  unknown,

  /// Nobody on this device has answered: the first-launch sheet asks.
  undecided,

  /// PostHog runs.
  allowed,

  /// PostHog stays off.
  denied,
}

/// The usage-analytics choice for the screens that show or change it — the
/// first-launch sheet and Privacy settings — over the one
/// [UsageAnalyticsConsent] they share, so a change made on one is what the
/// other shows.
class UsageAnalyticsBloc({required final UsageAnalyticsConsent _consent})
    extends Bloc<UsageAnalyticsEvent, UsageAnalyticsState> {
  this : super(UsageAnalyticsState.unknown) {
    on<UsageAnalyticsStarted>(_onStarted);
    on<UsageAnalyticsAllowed>((_, _) => _consent.allow());
    on<UsageAnalyticsDenied>((_, _) => _consent.deny());
  }

  /// Waits for the stored answer, then follows every change of it, from
  /// here or from anywhere else — a sign-out forgets it, for one.
  Future<void> _onStarted(
    UsageAnalyticsStarted event,
    Emitter<UsageAnalyticsState> emit,
  ) async {
    await _consent.settled;
    emit(_of(_consent.choice));
    await emit.forEach(_consent.changes, onData: _of);
  }

  static UsageAnalyticsState _of(AnalyticsChoice? choice) => switch (choice) {
    null => UsageAnalyticsState.undecided,
    AnalyticsChoice.allowed => UsageAnalyticsState.allowed,
    AnalyticsChoice.denied => UsageAnalyticsState.denied,
  };
}
