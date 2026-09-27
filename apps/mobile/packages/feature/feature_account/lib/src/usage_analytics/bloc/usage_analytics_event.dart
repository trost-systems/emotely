part of 'usage_analytics_bloc.dart';

/// What the screens can tell [UsageAnalyticsBloc].
@freezed
sealed class UsageAnalyticsEvent with _$UsageAnalyticsEvent {
  /// Read the stored choice and follow it from then on.
  const factory started() = UsageAnalyticsStarted;

  /// The user allowed usage analytics.
  const factory allowed() = UsageAnalyticsAllowed;

  /// The user said no, or switched it off.
  const factory denied() = UsageAnalyticsDenied;
}
