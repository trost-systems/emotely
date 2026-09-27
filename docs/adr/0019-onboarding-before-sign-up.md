# Onboarding runs before sign-up, on the device, and the companion learns the user's name

A new user's first screens are onboarding, not sign-in: the usage-analytics
choice, Welcome, what emotely does for them, what to call them, and a
greeting by that name. Onboarding is a versioned, ordered list of typed steps
in a new feature package, `feature_onboarding`, and it runs entirely on the
device before any account exists. Sign-up comes at the last possible moment,
right before the first session. From then on the app greets the user by name,
and the companion gets the name with every session request. Decided on #204,
2026-09-26.

## Why

The app opened on sign-in. The first thing it asked of a stranger was an
account, before it had said what it was for or who it was talking to. So
the order is turned round: show what emotely does, ask what to call the user,
and ask for the account only when the next tap is the first reflection, the
moment the account buys something.

The flow has to grow. Goal questions come next, and later the steps are
meant to be served remotely so they can be experimented on. It also has to be
measurable step by step in PostHog, which exposed a gap on the way: the app
set PostHog up on first launch without asking. That is fixed in the
[ADR 0004 amendment](0004-posthog-observability-stack.md#amendment-2026-09-26-usage-analytics-only-after-consent),
and the fix is onboarding's first step.

## Decisions

1. **Onboarding is an ordered list of typed steps with a flow version.**
   `feature_onboarding` is a feature package (ADR 0015). Each step is a type
   of its own with a stable `step_id`, and the list carries a
   `flow_version`. Order is data; a new kind of step is a new type. The first
   version:

   1. **The usage-analytics choice**, a sheet over Welcome (ADR 0004).
   2. **Welcome**: "Get started" or "I have an account".
   3. **What you get**: one screen, three promises.
   4. **Your name**: one optional field, 1–40 characters, trimmed, any
      script.
   5. **Nice to meet you, {name}**, with one button: "Start my first
      reflection".
   6. **Sign up**, headed "Almost there, {name}": Apple, Google, then email
      code.

   Journal consent is not an onboarding step. It stays just in time, before
   the first session (ADR 0014), because it is about sessions, not the
   account.

2. **Onboarding runs before sign-up, on the device.** Progress is recorded per
   step as each one completes, so closing the app resumes at the step
   reached. The typed name is kept on the phone until the account exists and
   then moves to the profile. Storing what the user typed, for a flow they
   are walking, is technically necessary storage (§ 25 (2) Nr. 2 TDDDG); it
   needs no consent.

3. **Names are asked, never taken from Apple or Google.** App Review rejected
   emotely before for asking for what Sign in with Apple already supplies.
   Asking *before* sign-in, optionally, is what guideline 5.1.1 (x) allows:
   apps "may request basic contact information … so long as the request is
   optional". The provider names would be unreliable anyway: Apple hands the
   name over only on the first authorization, and Supabase does not store
   Google's `given_name`
   ([Supabase, Sign in with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple);
   `googleUser` in `supabase/auth`). We try it as designed and change it only
   if review rejects it.

4. **Skipping the name gives a placeholder.** A random, gender-neutral name
   from a fixed list (Pebble, Pip, Maple, …), announced playfully ("Fine, stay
   mysterious. I'll call you Pebble for now…"), with a way back to the field.
   It is stored with `nameIsPlaceholder`, so the product never mistakes it
   for a name the user chose.

5. **The router redirect is the gate.** ADR 0016's `authRedirect` gains one
   input: signed out and onboarding not done leads to onboarding, at the step
   reached. It stays a pure function of its inputs, and its refresh listener
   now also fires when onboarding completes.

6. **"I have an account" skips onboarding.** It lands on the same sign-up
   screen, headed "Welcome back". An email code requested from there does not
   create an account. Apple and Google sign-in create one when none exists, so
   a new account can still arrive through that door without a name; for that
   account the name step runs once, after sign-in.

7. **Sign-up is the last step.** Apple, Google and email code are offered in
   that order. A "Last used" tag marks the method last used on this phone. It
   is kept on the device only, survives sign-out, and is cleared when the
   account is deleted.

8. **Sign-out returns to Welcome and asks the analytics choice again.** The
   choice belongs to a person, not to the phone (ADR 0004 amendment).

9. **The profile is a table.** `profiles` holds the display name and the
   placeholder flag, one row per user, readable and writable only by its
   owner under RLS, and deleted with the account by cascade (ADR 0010).

10. **The companion gets the name through `userContext`.** Each session
    request carries an optional `userContext` object, now
    `{ displayName, nameIsPlaceholder }`. `localDate`, `timeZone` and
    `locale` are meant to join it later; sending previous entries is a
    separate decision. It is additive under ADR 0009 rule 1: an app that
    sends none gets the prompt it gets today. The prompt builder takes the
    whole object, not one argument per fact, and uses a placeholder name
    playfully and sparingly. When sessions move server-side, the agent
    fills the same object from `profiles`, and the prompt builder does not
    change.

11. **Onboarding is tracked by a typed class.** `OnboardingAnalytics` mirrors
    `SessionAnalytics` (ADR 0005): `onboarding_started`,
    `onboarding_step_viewed`, `onboarding_step_completed` (with `action`:
    continue, skip or back, and `duration_ms`), `onboarding_completed` and
    `display_name_changed`. Every event carries `flow_version`,
    `variant: "control"`, `step_id` and `step_index`. **It is never handed
    the name**, so the name cannot reach an event. There is no feature flag
    yet, because there are too few users for an experiment. A PostHog funnel
    runs from the analytics choice through sign-up to `session_completed`
    (#130).

## Alternatives considered

- **Onboarding after sign-in.** Simpler: the profile would exist from the
  first step and nothing would move from the device to the server. It keeps
  sign-in as the first screen, which is the problem this solves.
- **Steps served by the server now.** That is where the flow is going, so
  experiments can change steps and copy without a release. Today there are
  too few users to run an experiment, and a remote flow needs a wire shape
  and an offline fallback. The versioned, typed list is what can move there
  later.
- **The companion runs onboarding as a conversation.** Every new install
  would spend model rounds before an account exists, and the steps would stop
  being deterministic, so they would stop being measurable step by step.
- **Anonymous accounts, with sign-up after the first session.** The first
  session is model inference. Running it for a device with no account
  reopens what ADR 0008 closes, a public LLM endpoint anyone can drive, and
  it spends against the per-session ceiling of ADR 0003 for people who may
  never sign up. ADR 0010 decision 4 already declined anonymous sign-in
  (CAPTCHA and a cleanup job). This is revisited once a first journaling
  flow exists that costs no inference.
- **The name in the auth user's `user_metadata`.** It needs no table, but
  Supabase puts `user_metadata` into every access token, and the user can
  edit it. The goal answers planned next can be data concerning health
  (Art. 9 GDPR) and must not ride in every JWT to every service. The
  profile is a table under RLS from the first field, so the goal answers
  have a place to go.

## Consequences

- **The display name now goes to the model provider.** The journal-consent
  wording says so, and its version is bumped
  ([ADR 0014 amendment](0014-explicit-consent-as-an-append-only-record.md#amendment-2026-09-26-a-second-kind-and-a-new-journal-wording)).
- **`userContext` is client-authored text in the prompt.** Until now the
  model saw client text only inside a size-capped, typed tool result
  (ADR 0008). The contract caps `displayName` at the same 40 characters as
  the field, and the prompt treats it as data, not instructions.
- **The privacy notice changes.** Analytics moves to consent (ADR 0004); the
  name is collected under Art. 6 (1) (b) and reaches the model provider; the
  sentence saying emotely never asks for a name goes. The App Store privacy
  label and Play's data safety form follow.
- **The funnel sees only people who allowed analytics.** Everyone who
  declines is invisible to it, including their drop-off. Rates read from it
  are rates among those who allowed.
- **It lands as a stack of pull requests** listed on #204, this record
  first.
