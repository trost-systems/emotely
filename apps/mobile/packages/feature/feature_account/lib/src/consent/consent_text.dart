/// The wording of the explicit consent the app asks for before the first
/// session, and the identifier that names it.
///
/// The app asks for consent under Art. 9 (2) (a) GDPR because a journal entry
/// can carry health and other special-category data, and the transcript
/// leaves the device for a model provider. What this text says about where
/// the transcript goes has to agree with the notice at
/// `getemotely.com/app-privacy` (apps/web `lib/pages/app_privacy.dart`): the
/// same recipients, in the same order, named the same way. If one changes,
/// both change, and [consentVersion] changes with them.
///
/// The strings themselves are messages in `l10n/account_*.arb`, one text
/// per language the app ships (ADR 0020); each one's description there says
/// what it does on the screen and that it is part of this wording.
library;

import 'package:feature_account/src/l10n/account_localizations.dart';

/// Which wording the user agreed to, as stored in
/// `public.consent_events.version`.
///
/// Dated, so the text as it stood can be found in the repository at that
/// date; the server refuses a version dated after today. **Changing the
/// wording means changing this**: a user whose latest event names an
/// older version is asked again before their next session, which is the
/// whole point of storing it.
///
/// This is not left to discipline. [consentWording], in every locale the
/// app ships, is hashed in a test against a checked-in value, so editing any
/// of its strings in any language without bumping this date fails CI —
/// otherwise two different texts could ship under one version and nobody
/// would ever be re-asked.
///
/// The tripwire cuts both ways, and it is the expensive direction that
/// matters: bumping this re-gates **every existing user** on their next
/// session. That is correct when the wording materially changes, and
/// needless churn when it does not — so a typo fix, or a faithful new
/// translation, is worth a moment's thought about whether the meaning moved
/// (see ADR 0014).
const consentVersion = '2026-10-02';

/// One point of the consent: a lead the eye can catch, then the sentence or
/// two behind it.
typedef ConsentPoint = ({String lead, String body});

/// What the user agrees to, in three points that fit one screen. Everything
/// an explicit consent under Art. 9 (2) (a) GDPR has to be informed about —
/// what is sent and to whom, the third country and its safeguard (EDPB
/// 05/2020 para 64 (vi)), what may not be done with it, why it is sensitive,
/// and that it can be taken back — is here; the full notice, one tap below,
/// carries the rest.
///
/// What this says about where the transcript goes has to agree with the
/// notice at `getemotely.com/app-privacy`: the same recipients, in the same
/// order, named the same way. If one changes, both change.
List<ConsentPoint> consentPoints(AccountLocalizations strings) => [
  (lead: strings.consentSendingLead, body: strings.consentSendingBody),
  (lead: strings.consentRetentionLead, body: strings.consentRetentionBody),
  (lead: strings.consentWithdrawalLead, body: strings.consentWithdrawalBody),
];

/// Every string the user reads before deciding, in the order the screen
/// shows them, in the language of [strings]. This is what [consentVersion]
/// names, and what the version test hashes across every locale: if any of
/// it changes, the version must change too, because a record naming
/// `2026-10-02` has to mean one particular text per language and not
/// whatever the ARB files happen to say today.
///
/// Deliberately only the *decision* strings — the title, the three points,
/// the checkbox and the two buttons. Failure messages, the hint on the
/// disabled button and link labels are not part of what was agreed to, so
/// editing them does not re-gate the user base.
List<String> consentWording(AccountLocalizations strings) => [
  strings.consentTitle,
  for (final point in consentPoints(strings)) ...[point.lead, point.body],
  strings.consentCheckboxLabel,
  strings.consentAgreeButton,
  strings.consentDeclineButton,
];
