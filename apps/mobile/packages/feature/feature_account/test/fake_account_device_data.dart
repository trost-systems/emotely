import 'package:feature_account/feature_account.dart';

/// Records what the account feature asked the app to forget on this device,
/// and [fails] when told to, as a preferences store that cannot write would.
class FakeAccountDeviceData({final bool fails = false})
    extends AccountDeviceData {
  /// How often the feature asked for the device's data to be forgotten.
  var forgotten = 0;

  @override
  Future<void> forget() {
    forgotten++;
    return fails
        ? Future.error(Exception('preferences unavailable'))
        : Future.value();
  }
}
