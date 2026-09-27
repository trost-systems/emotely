# PostHog for the full observability stack; no Sentry

We adopt PostHog from day one as the single observability and experimentation
platform, and deliberately do **not** add Sentry.

Adopted day one (all within PostHog's free tier at our scale):

- **Product analytics** — `posthog_flutter` (app) + `posthog-node` (agent).
- **AI Observability** — `@posthog/ai` on the AI SDK calls → `$ai_generation`
  events (tokens, cost, latency, traces per model). This is the cost/quality
  benchmark surface.
- **Feature flags + experiments** — a flag payload `{model, prompt}` drives
  server-side model selection with no deploy; PostHog LLM prompt experiments
  auto-attribute cost + quality per variant.
- **Error tracking** — native PostHog exception tracking. This is why we skip
  Sentry: one fewer vendor and SDK for a solo build; add Sentry later only if we
  outgrow PostHog's error tracking (unlikely soon).
- **Max AI + anomaly alerts** — the "self-driving" watchdog: watches AI-cost-per-
  user and session-completion and pings on drift instead of us dashboard-staring.

Deferred: session replay (only with mask-all-text, given sensitive journal
content). Surveys were deferred too until **2026-09-18, when they were adopted
for the beta — see below**. Skipped for now: the
data warehouse (Supabase is our source of truth; revisit only to join Stripe
subscription data).

Set billing limits / spike protection per product on day one so an agent retry
storm cannot surprise-bill.

## The self-driving loop

PostHog flag hands the agent `{model, prompt}` → `@posthog/ai` emits cost/latency
per variant → LLM prompt experiment attributes cost + quality per variant → Max AI
/ anomaly alerts flag drift. The product tunes its own model choice.

## Surveys, for the beta (added 2026-09-18)

Surveys are on for the beta's structured questions, **event-triggered and
popover-presentation only**. Two channels, deliberately split: the mailto
"Send feedback" row is the *human* channel — open-ended, unprompted, and it
reaches a person — while a survey is the *structured, timed* one. A survey
asks one question at the moment it is about, and the answer lands as an
event next to that person's funnel, so "who bounced after two entries" and
"what they said about it" are the same query rather than an inbox to
correlate by hand. Neither replaces the other; the mailto exit stays.

Two surveys exist as drafts, each with its trigger:

- **"Would you miss emotely?"** — triggered by `third_entry_written`, shown
  once. The habit question, asked when there is just enough habit to have an
  opinion about.
- **"How was that entry?"** — triggered by `session_completed`, repeated, at
  most every 7 days.

`third_entry_written` exists because PostHog's survey targeting does not
accept a behavioural cohort as a trigger: the milestone has to *be* an
event. The app captures it exactly once, when the count of filed entries
reaches three, read after the entry is persisted and after
`session_completed` — so a survey popping on either trigger can never
interrupt a save.

Mechanically, the Flutter SDK has no "show survey now" API: popover surveys
render on their own for users who fired the trigger and match the targeting,
but only if the app mounts `PostHogWidget` and `PosthogObserver` (the
observer is what the SDK reads a `BuildContext` from; without it it logs that
it cannot show the survey). `config.surveys` already defaults to true in the
pinned 5.39.0, so the app shell is the whole change. **Session replay stays
deferred** — enabling surveys does not enable it.

ADR 0005 is untouched: a survey carries only what the user types into it,
and no journal text passes through the survey path. The privacy notice says
so plainly — the app occasionally asks for feedback, and an answer, if one
is given, goes to PostHog.

## The web site (added 2026-09-12)

getemotely.com reports to the **same production project** — PostHog's own
recommendation is one project for app and marketing site so a journey can be
followed end to end — but in **cookieless mode** (`cookieless_mode: "always"`,
`person_profiles: "never"`, autocapture off): nothing is stored in the
visitor's browser, uniques come from PostHog's daily-rotating server-side
hash, and the IP is dropped before enrichment. That is why the site carries no
cookie banner, and it costs exactly the things a landing page does not need
yet: returning-visitor attribution, `identify()`, replay, surveys, flag
caching, GeoIP. The site sends `$pageview`, `waitlist_joined {source}` and
`waitlist_refused {source, reason}`; the address itself never leaves the form
except to Postgres.

Attribution survives cookieless because the waitlist row stores the visit's
`utm_source/utm_medium/utm_campaign` as `source` (see the `campaign-links`
skill); "campaign → waitlist → app account" is then a join on the email in
Postgres, no cookie involved. The day paid campaigns or on-page experiments
start, the site switches to `cookieless_mode: "on_reject"` plus a consent
banner; that switch is tracked as an issue, not decided here.

## Amendment 2026-09-26: usage analytics only after consent

Until now the app called `Posthog().setup()` on every launch, before it had
asked anything. Setup generates an id, stores it on the phone and sends it
with every event. **Usage analytics in the app — events, crash reports and
surveys, everything the SDK does — now needs the user's consent, and the SDK
is not set up at all until the user allows it.** Found while planning
onboarding (#204, ADR 0019).

**Why consent.** § 25 (1) TDDDG permits storing information on a user's
device, or reading it back, only with consent; the exception in § 25 (2)
Nr. 2 covers only what is strictly necessary for a service the user
expressly asked for
([§ 25 TDDDG](https://www.gesetze-im-internet.de/ttdsg/__25.html)). The
German supervisory authorities read that exception technically, not
commercially (DSK, Orientierungshilfe Digitale Dienste v1.2, 20 Nov 2024,
Rn. 78). Measurement and A/B tests are not per se part of the service
(Rn. 77), and they decline to call audience measurement consent-free in
general (Rn. 87–90). Personal data is not a precondition (section III.1.d),
so calling the data anonymous does not help. The EDPB counts an SDK that
makes the device send an identifier as gaining access to the device
(Guidelines 2/2023 on Art. 5 (3) ePrivacy, v2.0, paras 34 and 63). The
processing that follows needs its own basis, and a missing § 25 consent
carries over to it (DSK Rn. 97–98); Art. 6 (1) (f) holds for tracking "only
in few constellations" (Rn. 109). So the basis is **consent under
§ 25 (1) TDDDG together with Art. 6 (1) (a) GDPR**, asked once for both, as
the DSK allows (section III.1.e). Apple asks the same of every app: usage
data needs consent "even if such data is considered to be anonymous", and
withdrawing it must be easy (App Review Guideline 5.1.1 (ii)).

**Why not set up and opt out.** `PostHogConfig.optOut` exists, but on iOS
setup still loads remote config and preloads feature flags with a generated,
persisted anonymous id; that path has no opt-out check
(`PostHogRemoteConfig.swift`, read 2026-09-26). The mobile SDKs have no
cookieless mode either: `cookieless_mode`, which lets the web site run
without a banner, exists only in posthog-js. The one configuration that
provably stores and sends nothing is not calling `setup()`, so no device id
exists before Allow. Auto-init is already off in `Info.plist` and
`AndroidManifest.xml`.

**How it is asked.**

- On first launch, as a sheet over Welcome: "May I count how you use the
  app?". It comes before anything else because tracking would otherwise
  start on Welcome.
- **Don't allow** and **Allow** have equal weight: same size, colour and
  type (DSK Rn. 134–137). Nothing is preselected, and carrying on without
  answering is not consent (Rn. 45; CJEU C-673/17 *Planet49*).
- It can be withdrawn at any time with a switch in Privacy settings, which
  turns both ways. Withdrawing stops the SDK and resets its id.
- **Signing out resets it**, and the sheet asks again. The choice belongs to
  a person, not to the phone. The device keeps whose it is with it (#216):
  an account id, or none for an answer given before sign-up, which the
  first account to sign in adopts. On launch and on every change of
  session, a choice that belongs to anyone other than the account now
  signed in is forgotten before PostHog is set up or anything is sent, so
  a session that ends while the app is closed cannot pass one person's
  answer to the next. A choice stored without an owner, by the builds
  before that, is asked again: nothing can tell whose it was.
- Before an account exists the choice is kept on the device. After sign-in
  it is appended to the consent record as its own kind (ADR 0014 amendment),
  and `identify()` with the user's id links the events sent since Allow to
  that person.

**Rejected.** Legitimate interest with an opt-out, which is what comparable
wellbeing apps claim: the DSK reading above leaves it no room for a German
provider, and Apple's 5.1.1 (ii) asks for consent either way. The EU Digital
Omnibus would allow consent-free, aggregated first-party measurement
(proposed Art. 88a GDPR), but it is a proposal, not law, and a per-user
funnel is not aggregated.

**What it costs.**

- **Crash reports now come only from people who allowed analytics.** Error
  tracking was one reason for skipping Sentry; that holds, but a crash on a
  phone that declined is never seen.
- **Every metric is among those who allowed.** The onboarding funnel, the
  surveys and the beta dashboard all lose the people who declined, and the
  decline rate itself cannot be measured.
- **The web site is unchanged.** It already runs cookieless and stores
  nothing on the visitor's device.
- **The agent's server-side events are unchanged.** `@posthog/ai` runs in
  the agent and touches no device, so § 25 does not reach it; it stays
  content-free under ADR 0005.
