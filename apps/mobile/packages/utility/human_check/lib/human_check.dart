/// The human check in front of every Supabase Auth call a script could
/// abuse (#94): `HumanCheck.guard` runs the call with a fresh Cloudflare
/// Turnstile token, which GoTrue verifies with Cloudflare before it sends
/// a mail or checks a password.
///
/// It has its own package because more than one feature makes such calls
/// (signing in, signing up, recovering a password), and the token source
/// is a leaf the app wires and every test scripts.
library;

export 'src/human_check.dart';
export 'src/register.dart';
export 'src/turnstile.dart';
