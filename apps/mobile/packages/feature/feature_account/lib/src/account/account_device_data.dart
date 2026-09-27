/// What this device keeps about the account outside its session, forgotten
/// once the account is deleted (#204): today the way in the sign-in screen
/// tags "Last used", which is kept over sign-out but must not outlive the
/// account.
///
/// That data belongs to other features, and a feature never knows another
/// feature (ADR 0015). So, like a navigator, this feature says when and the
/// app says what: it implements this in its composition root and registers
/// it as a singleton; a test fakes it.
abstract class AccountDeviceData() {
  /// Forgets everything this device kept about the deleted account.
  Future<void> forget();
}
