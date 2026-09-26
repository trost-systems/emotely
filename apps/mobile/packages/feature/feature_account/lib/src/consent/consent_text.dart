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
library;

/// Which wording the user agreed to, as stored in
/// `public.consent_events.version`.
///
/// Dated, so the text as it stood can be found in the repository at that
/// date; the server refuses a version dated after today. **Changing the
/// wording below means changing this**: a user whose latest event names an
/// older version is asked again before their next session, which is the
/// whole point of storing it.
///
/// This is not left to discipline. [consentWording] is hashed in a test
/// against a checked-in value, so editing any of the strings below without
/// bumping this date fails CI — otherwise two different texts could ship
/// under one version and nobody would ever be re-asked.
///
/// The tripwire cuts both ways, and it is the expensive direction that
/// matters: bumping this re-gates **every existing user** on their next
/// session. That is correct when the wording materially changes, and
/// needless churn when it does not — so a typo fix is worth a moment's
/// thought about whether the meaning moved (see ADR 0014).
const consentVersion = '2026-09-26';

/// The heading of the consent screen. Names the moment rather than asking a
/// question, and stays true when the screen is shown again after a wording
/// change or after a withdrawal — neither of which is a "first" session.
const consentTitle = 'Before emotely sends your writing';

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
const consentPoints = <ConsentPoint>[
  (
    lead: 'Your answers are sent to an AI model.',
    body:
        'Each answer goes to our server and on to a language model provider '
        'through the Vercel AI Gateway, together with the name you chose, or '
        'the nickname emotely picked for you, so emotely can ask the next '
        'question, address you by name and write your entry. The provider '
        'may be outside the EU; where it is, the transfer rests on the EU’s '
        'standard contractual clauses.',
  ),
  (
    lead: 'Never used for training, never kept.',
    body:
        'Every request routes only to providers contractually barred from '
        'training on what you write and from keeping it after they answer. '
        'Your entries themselves are stored in Frankfurt and nowhere else.',
  ),
  (
    lead: 'Sensitive, and yours to take back.',
    body:
        'A journal can say how you feel, how you sleep or how your health '
        'is, so we ask first. You can withdraw on the More tab at any time; '
        'what a provider has already answered cannot be recalled.',
  ),
];

/// The label on the checkbox: the affirmative act itself. Unticked, always.
const consentCheckboxLabel =
    'I consent to my journal entries being sent to a model provider as '
    'described above.';

/// The button that records it; enabled only once the box is ticked.
const consentAgreeLabel = 'Start journaling';

/// Declining. Named plainly rather than as a soft "not now", because the
/// choice has to be real.
const consentDeclineLabel = 'Not now';

/// Read out instead of a silently dimmed button. Not part of
/// [consentWording]: it is an instruction for operating the screen, not a
/// term being agreed to, so improving it does not re-gate anyone.
const consentAgreeBlockedHint = 'Tick the box above to continue';

/// What declining means. There is no session without the model, so this says
/// so rather than pretending otherwise — and everything else stays usable.
const consentDeclinedMessage =
    'No problem. Nothing has been sent. You can still read the entries you '
    'already have, and you can start a session whenever you decide to.';

/// The link to the whole notice, from the consent screen.
const consentReadNoticeLabel = 'Read the full privacy notice';

/// Shown when the consent could not be recorded. The session does not start
/// on a consent that was never written down, so this says what happened
/// rather than quietly continuing.
const consentFailureMessage =
    'Could not record your consent. Check your connection and try again.';

/// Shown when withdrawing could not be recorded, for the same reason.
const withdrawFailureMessage =
    'Could not withdraw your consent. Check your connection and try again.';

/// Shown when the app could not find out whether consent already stands.
/// Not the same as "you have not consented": asking the question again here
/// would re-prompt someone who already answered it.
const consentUnknownMessage =
    'Could not check whether you have already agreed to this. Nothing has '
    'been sent. Check your connection and try again.';

/// Every string the user reads before deciding, in the order the screen
/// shows them. This is what [consentVersion] names, and what the version
/// test hashes: if any of it changes, the version must change too, because
/// a record naming `2026-09-26` has to mean one particular text and not
/// whatever the file happens to say today.
///
/// Deliberately only the *decision* strings — the title, the three points,
/// the checkbox and the two buttons. Failure messages and link labels are
/// not part of what was agreed to, so editing them does not re-gate the
/// user base.
final consentWording = [
  consentTitle,
  for (final point in consentPoints) ...[point.lead, point.body],
  consentCheckboxLabel,
  consentAgreeLabel,
  consentDeclineLabel,
];
