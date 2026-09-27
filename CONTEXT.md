# Context

The language of this project. Glossary only — decisions live in
[`docs/adr/`](docs/adr/), architecture in [`README.md`](README.md).

## Companion

The persona the user talks to: the voice that asks the questions in a
session and speaks to the user as "I" in onboarding. A character, not a
service — the software behind it is **the agent**. It has no name of its own
yet. Avoid "Journaling Assistant", "the assistant" and "the bot".

## Session

One complete journaling conversation: the **companion** walks the user through
the **questions** of a chosen **question set** and ends by producing a
**journal entry**. A session is the unit the cost ceiling is measured against
(~30 sessions/month for a daily poweruser).

## Question

One thing the companion asks about within a session — a concrete question text
(e.g. "What are you grateful for today?"), not an abstract theme. Asked via
`ask_question`, answered via `record_answer` — the pair is what makes a question
distinct from a free-form chat turn. One `record_answer` per question carries
the complete answer; a repeated call for the same question overwrites.
("Topic" is not a term in this project; the legacy app used it only in prompts.)

## Question set

An ordered list of questions the user picks before a session starts; the session
walks exactly that set. Sets are predefined for now; user-created sets are an
intended future capability (the legacy app built the storage for this but never
shipped the UI).

## Answer type

How a question is answered, and therefore which native widget the client renders
and what shape the answer value has: `text_list` (several short texts),
`longtext` (one text), `rating` (one integer, 1–10), `emoji` (several emojis),
`color` (several hex colors). This is the surface of the generative UI — the
answer type comes from the question, the client renders the matching widget.
For list-shaped types, multiplicity lives inside the value, never in repeated
calls; `minAnswers` on a question is the only cardinality constraint.

## Journal entry

The durable artifact a session produces: the summary passed to
`complete_session`, persisted for the user. Distinct from the session itself,
which is the conversation that produced it.

## Onboarding

The steps a new user walks on the device before they have an account, from
the usage-analytics choice to sign-up. It ends when the account exists.
Distinct from sign-in, which is only its last step, and from **journal
consent**, which is asked later, before the first session.

## Onboarding step

One screen of onboarding, named by a stable step id and placed by its
position in the flow. A step is *completed* when the user leaves it forward,
by continuing or by skipping. The ordered list of steps carries a **flow
version**, which names one particular sequence.

## Display name

What the user asked to be called: the name the app greets them by and the
companion addresses them with. Chosen in the app, never taken from Apple or
Google, and not the account's email or legal name. Either typed by the user
or a **placeholder name**. Avoid "username", "first name" and "nickname".

## Placeholder name

A display name the user did not choose: the playful stand-in (Pebble, Maple,
Wren, …) given when they skip the name step. It stays a placeholder until the
user types a name of their own.

## User context

What the companion is told about the user for a session, as one object beside
the transcript: now the display name and whether it is a placeholder, later
such facts as the local date, time zone and locale. Facts about the person,
never journal content.

## Consent

Two kinds, never used interchangeably:

- **Journal consent** — explicit consent under Art. 9 GDPR to send what the
  user says in a session to the model provider. Asked before the first
  session.
- **Usage-analytics consent** — consent to PostHog counting how the app is
  used: events, crash reports, surveys. Asked on first launch, before any
  account exists.

Each has its own wording and its own **consent version**. "Consent" alone is
ambiguous; qualify it.

## Contract

The tool-call schema in `packages/contract` — the single source of truth shared
by the agent (producer) and the app (consumer). "Contract drift" means the two
sides disagreeing about it, which the monorepo exists to prevent.

## Agent

Ambiguous by default; always qualify:

- **the agent** (`apps/agent`) — the deployed TypeScript service running the
  tool-calling loop. The **companion** is the persona the user meets
  through it, not the service.
- **an autonomous agent** — an AI coding agent that writes to this repository.
  These are the actors [ADR 0007](docs/adr/0007-protected-main-for-autonomous-agents.md)
  protects `main` against.

## Gate

A check that must pass *before* a change lands. Distinct from a **rollback**,
which is a correction *after*. The CI gate is a precondition; rollback is the
second line of defence. See [ADR 0007](docs/adr/0007-protected-main-for-autonomous-agents.md).

## Evals

Two distinct layers, never used interchangeably:

- **Offline evals** (`apps/agent/evals/`) — deterministic fixtures replayed
  against candidate models. A CI gate. Proves *correct and cheap in the lab*.
- **Online experiment** (PostHog) — real sessions, live variant comparison.
  Proves *cheap and retained in the wild*.
