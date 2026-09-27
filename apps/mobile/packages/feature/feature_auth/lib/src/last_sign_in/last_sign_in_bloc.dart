import 'package:feature_auth/src/last_sign_in/last_sign_in_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the sign-in screen asks of [LastSignInBloc].
sealed class const LastSignInEvent();

/// Read the way in this device kept; the bloc asks on its own when made.
final class const LastSignInRequested() extends LastSignInEvent;

/// The way in last used on this phone, for the sign-in screen to tag, or
/// null for none (#204). Owned by the sign-in screen: the value changes
/// only when someone signs in, and then the screen is gone. The auth bloc
/// writes it and the account's deletion clears it; this only reads.
class LastSignInBloc({required final LastSignInStore _store})
    extends Bloc<LastSignInEvent, SignInOption?> {
  this : super(null) {
    on<LastSignInRequested>((_, emit) async => emit(await _store.read()));
    add(const LastSignInRequested());
  }
}
