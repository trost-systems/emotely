# Explicit consent is an append-only record, and the wording is versioned

A journal entry can say how someone sleeps, what a diagnosis is doing to them,
or how things stand with a parent. That makes entries capable of carrying
health and other special-category data under Art. 9 GDPR, and the session
sends the transcript to a model provider through the Vercel AI Gateway
(ADR 0003). Art. 9 has no contract exception — EDPB Guidelines 05/2020 para 99
— so **explicit consent under Art. 9 (2) (a) is the only available basis**, and
it has to be asked for, recorded, and revocable. Art. 7 (4) does not bite here:
the processing is what the user asked the product to do, not a condition bolted
onto it (same guidelines, para 100).

Before #97 the app asked for nothing and the notice claimed consent was given
"by writing an entry". Inferred conduct is not an affirmative act, so the claim
was false and the basis was missing.

## Decisions

1. **The record lives on the server, not the device.** Art. 7 (1) requires the
   controller to be able to *demonstrate* consent. A local flag proves nothing
   and does not survive a reinstall. `public.consent_events` holds it, next to
   the data it is about, under the same RLS model as everything else
   (ADR 0010).

2. **The record is append-only.** Every grant and every withdrawal is its own
   immutable row; "consent stands" is derived from the latest event for that
   user and version.

   The cheaper design — one row per user per version, with withdrawal clearing
   a column — was implemented first and is wrong. Consenting again after a
   withdrawal cleared the withdrawal, leaving a row that claimed unbroken
   consent since the original date. That row would then vouch for whatever had
   been written during the window when consent did not stand, which is the
   opposite of evidence. The account screen's "Consent again" button reached
   that path in one tap, so it was the normal journey, not a corner.

   What the controller must be able to show is what was true *when*. So
   nothing is ever updated or deleted: no `UPDATE` privilege and no `DELETE`
   privilege is granted on the table to anyone. The history goes only when the
   account does, by cascade.

3. **The user has no write privilege at all; three functions are the only way
   in.** `record_consent`, `withdraw_consent` and `consent_stands` are the
   entire interface. The first two are `security definer` — unlike the
   journal's functions, which run as the caller precisely so RLS can decide
   which row they touch. Here the point is the reverse: the caller may touch
   *none* of the rows directly, because a user who can insert can forge. A
   direct insert grant, even column-scoped, let a user backdate `granted_at`,
   choose the primary key, or plant an event for a wording nobody had
   published yet — which would silently satisfy the next re-consent. The
   function bodies read `auth.uid()` themselves and refuse a caller without a
   JWT.

4. **Ordering is a sequence, not a timestamp.** `now()` is transaction time,
   so a grant and a withdrawal in one transaction share it and "the latest
   event" would be decided by a random uuid. `seq bigint generated always as
   identity` is the key and the order.

5. **The wording is versioned, and the version is enforced by a tripwire.**
   `version` is the date the wording was published (`YYYY-MM-DD`, never in the
   future). The text itself is never stored per user: it lives on the site and
   in this repository's history, and the version names it.

   A version only means something if it names exactly one text, which nothing
   in the language guarantees. `consentWording` in `apps/app` collects every
   string the user reads before deciding, and a test hashes it against a
   checked-in digest. Editing a paragraph without bumping `consentVersion`
   fails CI.

   **The tripwire has an expensive direction, and that is deliberate: bumping
   the version re-gates the entire existing user base on their next session.**
   That is correct when the meaning moved and needless churn when it did not,
   so the test's failure message spells out both paths — bump both for a
   material change, update the digest alone for a typo that changes nothing
   about what is being agreed to.

## What this does not cover

**The gate is in the app; the agent does not check consent.** The agent
verifies the JWT and holds no database connection — ADR 0010 decision 2, which
is why no service-role key exists in this repository or in Vercel. A consent
lookup there would need either that key or the user's token forwarded to
PostgREST on every round, and that ADR rejected both.

So the true claim is narrow: **this app does not start a session without a
recorded consent.** A bearer token driven straight at `/api/advance-session`
is not stopped by anything on the consent path. For Apple 5.1.2 (i) and Play's
User Data policy that is sufficient — the in-app gate is what reviewers test.
For the Art. 9 claim it is weaker than a server-side check would be, and it is
recorded here as an open trade rather than described as something it is not. If
it is closed later, the natural place is `verifyCaller` in
`apps/agent/src/http-advance-session.ts`, where `userId` is already threaded
through, and the cost is a database dependency the agent does not currently
have.

## Consequences

- Withdrawal is one tap on the account screen and never requires deleting the
  account (Art. 7 (3)). Giving consent again goes back through the same
  screen, the same three points and the same unticked box — withdrawal must
  be as easy as giving, which does not license making *giving* easier the
  second time.
- The gate re-reads from the server before every session, not once at launch,
  so a withdrawal made on another device stops this one.
- Declining records nothing. A refusal is the absence of a consent, not a
  decision to store.
- Analytics stay content-free (ADR 0005): `consent_granted`,
  `consent_withdrawn` and `consent_declined` carry a version and nothing else.
- Store reviewers meet the gate like any user. `reviewer-accounts.sh`
  recreating an account deletes its consent history with it, so the gate
  reappears on the next run — expected, not a regression.

## Amendment 2026-09-26: a second kind, and a new journal wording

**Usage analytics is a second kind of consent in the same record.** The app
now asks before it sets PostHog up (ADR 0004 amendment 2026-09-26), and
that consent has to be demonstrable too (Art. 7 (1)). It is a different
purpose asked at a different moment — the first launch, not the first
session — so it is its own kind, never folded into journal consent, and it
has its own version: a new analytics wording does not re-gate sessions, and
a new journal wording does not re-ask the analytics choice. Its wording is
versioned and pinned by a digest exactly as decision 5 describes.
Everything else above holds for both kinds: append-only, no write privilege,
the functions as the only way in, the sequence as the order. Existing rows
are journal consent.

**It is given before an account exists.** The choice is made on the device,
before sign-up (ADR 0019), and appended to the record once the user signs
in. The row's time is when the server recorded it, not when the phone says
it was given: a client-supplied time is the backdating hole decision 3
closed. Declining records nothing, as for journal consent; switching it off
later in Privacy settings appends a withdrawal.

**The journal wording changes, and its version is bumped.** Sessions now
send the user's display name to the model provider (`userContext`,
ADR 0019), so what the user agrees to has changed in meaning, not only in
words — the expensive direction of decision 5, taken on purpose. There are
no testers yet, so in practice nobody is re-gated.
