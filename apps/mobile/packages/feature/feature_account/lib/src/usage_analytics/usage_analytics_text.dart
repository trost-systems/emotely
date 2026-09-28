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
/// The strings are messages in `l10n/account_*.arb`, one text per language
/// the app ships (ADR 0020).
library;

import 'package:feature_account/src/l10n/account_localizations.dart';

/// Which wording the user answered, as the consent record stores it once
/// they sign in (purpose `usage_analytics`).
///
/// Dated like the journal consent's version, and held to the same tripwire:
/// [usageAnalyticsWording], in every locale the app ships, is hashed in a
/// test, so editing one of its strings in any language without bumping this
/// date fails CI. A bump means every device's answer is recorded again
/// against the new wording on the next sign-in; it does not ask anyone
/// again, because the choice on the device still stands.
const usageAnalyticsVersion = '2026-09-26';

/// Every string the user reads before deciding, in the order the sheet
/// shows them, in the language of [strings]: what [usageAnalyticsVersion]
/// names and the test hashes. The question, why, what is counted and what
/// never is, the two answers — refusing exactly as prominent as allowing
/// (DSK OH Digitale Dienste Rn. 134 ff.) — and where to change it later,
/// since withdrawal must be as easy as giving and the user has to know where
/// before they give it. The notice link's label is not part of what is
/// agreed to.
List<String> usageAnalyticsWording(AccountLocalizations strings) => [
  strings.usageAnalyticsTitle,
  strings.usageAnalyticsBody,
  strings.usageAnalyticsCounted,
  strings.usageAnalyticsNever,
  strings.usageAnalyticsDenyButton,
  strings.usageAnalyticsAllowButton,
  strings.usageAnalyticsChangeHint,
];
