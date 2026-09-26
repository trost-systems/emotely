/// The wording of the usage-analytics question (#204), and the identifier
/// that names it in the consent record.
///
/// This consent is not the journal's: it covers PostHog — which screens
/// are used, taps, crash reports — under § 25 TDDDG and Art. 6 (1) (a)
/// GDPR, and it is asked before anything else, on the device, because
/// there is no account yet. The companion speaks as "I" here: it is the one
/// asking.
///
/// What this says about PostHog has to agree with the notice at
/// `getemotely.com/app-privacy` (apps/web `lib/pages/app_privacy.dart`).
library;

/// Which wording the user answered, as the consent record stores it once
/// they sign in (purpose `usage_analytics`).
///
/// Dated like the journal consent's version, and held to the same tripwire:
/// [usageAnalyticsWording] is hashed in a test, so editing a string below
/// without bumping this date fails CI. A bump means every device's answer is
/// recorded again against the new wording on the next sign-in; it does not
/// ask anyone again, because the choice on the device still stands.
const usageAnalyticsVersion = '2026-09-26';

/// The question itself, the heading of the first-launch sheet.
const usageAnalyticsTitle = 'May I count how you use the app?';

/// Why, in one breath.
const usageAnalyticsBody =
    'It shows which screens help and where people get stuck, so I can get '
    'better. What you write never goes into it.';

/// What is counted, and where it is kept.
const usageAnalyticsCounted =
    'Taps, screens and crash reports, stored with PostHog in the EU';

/// What never is.
const usageAnalyticsNever = 'Never your answers, entries or name';

/// Refusing. Exactly as prominent as [usageAnalyticsAllowLabel]: a refusal
/// has to be as easy as the yes (DSK OH Digitale Dienste Rn. 134 ff.).
const usageAnalyticsDenyLabel = 'Don’t allow';

/// Allowing.
const usageAnalyticsAllowLabel = 'Allow';

/// Where the choice can be changed later: withdrawal must be as easy as
/// giving, and the user has to know where before they give it.
const usageAnalyticsChangeHint =
    'Change it any time under More › Privacy settings.';

/// Every string the user reads before deciding, in the order the sheet
/// shows them: what [usageAnalyticsVersion] names and the test hashes. The
/// notice link's label is not part of what is agreed to.
const usageAnalyticsWording = [
  usageAnalyticsTitle,
  usageAnalyticsBody,
  usageAnalyticsCounted,
  usageAnalyticsNever,
  usageAnalyticsDenyLabel,
  usageAnalyticsAllowLabel,
  usageAnalyticsChangeHint,
];
