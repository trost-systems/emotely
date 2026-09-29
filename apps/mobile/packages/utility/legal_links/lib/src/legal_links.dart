import 'package:url_launcher/url_launcher.dart';

/// Where the app's privacy notice lives. Apple guideline 5.1.1 (i) and
/// Google Play's User Data policy both require it to be reachable from
/// inside the app, not only from the store listing.
const privacyNoticeUrl = 'https://getemotely.com/app-privacy';

/// The imprint § 5 DDG asks of a German provider; linked next to the notice.
const imprintUrl = 'https://getemotely.com/imprint';

/// Opens the full notice in the browser. Fire-and-forget: if no browser can
/// be opened there is nothing a screen can do, and what the screen says
/// already covers the essentials.
Future<void> openPrivacyNotice() => launchUrl(
  Uri.parse(privacyNoticeUrl),
  mode: LaunchMode.externalApplication,
);

/// Opens the imprint (§ 5 DDG).
Future<void> openImprint() =>
    launchUrl(Uri.parse(imprintUrl), mode: LaunchMode.externalApplication);
