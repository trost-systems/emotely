---
name: change-notice
description: How to tell account holders and the waitlist about a material change to a privacy notice before it takes effect — whether a change is material, how far ahead, writing the mail, the dry run, Peter's send, and the record of who was told. Use whenever a privacy notice, a purpose of processing, a recipient or a transfer changes, or someone asks whether or when people were told about a change.
---

# Telling people about a material change

Both privacy notices promise it: the site notice tells the waitlist "by email
before it takes effect", the app notice tells account holders the same about
their journal. The mail is the change notice, and it is the only thing that
keeps those promises. It lives in the `change_notice` schema
(`supabase/migrations/20261003120000_change_notice.sql`), which only postgres
reaches, and `scripts/change-notice.sh` is the one way to drive it.

A change notice is not re-consent. A change to what users agree to also needs
`consentVersion` bumped (ADR 0014); a change to the notice's words alone needs
neither that nor this.

## 1. Is it material?

Per WP260 rev.01 paras 29–31 (the EDPB's transparency guidelines):

- **Material:** a new or changed purpose, a new controller, a change in how
  rights are exercised. A new purpose must be notified before that
  processing starts (Art. 13 (3) GDPR): #295's reading of entries over time
  is the example in view.
- **Fundamental**, a subset: new categories of recipient, a new transfer
  outside the EU, a new purpose. These go out *well in advance*, so a reader
  can object, withdraw or leave first. The law names no number of days; our
  default is 30 days for fundamental and 14 for other material changes, and
  the dry run prints the lead time so it is a decision, not an accident.
- **Not material:** spelling, styling, a clearer sentence about the same
  processing. Those ship with the notice's new date and nothing else.

## 2. Who

- `accounts` — the change touches the app or the journal (the app notice).
- `waitlist` — the change touches what happens to a waitlist address (the
  site notice).
- `both` — the change touches both: a new controller, a new contact, how
  rights are exercised.

Account holders are those who completed sign-in; waitlist addresses are those
confirmed. An address in both gets one mail, as the account holder. Each
reader gets German when the app kept `de` (or, failing that, the waitlist row
says `de`) and a German text exists; English otherwise.

## 3. Write the mail

One plain-text file per language: the subject on line 1, a blank line, then
the body. English is required, German expected (`CONTEXT.md` terms, "du").
The body is devoted to this change and nothing else — no news, no
invitation, no marketing — and explains the impact, not merely that
something changed:

1. what changes, in a sentence;
2. what it means for the reader's data, concretely;
3. what they can do: object (reply), withdraw consent, delete the account
   (More), or leave the waitlist;
4. a greeting and "Peter" as signature.

The schema appends a footer in the reader's language with the date the
change takes effect, why they get the mail, the link to their notice and
"reply to this mail", so the body need not repeat those. Write the notice
change itself in the same pull request or before; the mail stands on its
own, so a reader needs no diff.

## 4. Dry run (agent)

```bash
S=.claude/skills/change-notice/scripts/change-notice.sh
$S preview --audience accounts --effective 2026-12-01 --en en.txt --de de.txt            # local stack
$S preview --audience accounts --effective 2026-12-01 --en en.txt --de de.txt --linked   # production, read-only
```

It prints the readers by kind and language, how many are not yet told, the
lead time, and every mail exactly as it will go out. It writes nothing. Keep
the message files out of the repository (the scratchpad), and paste the
preview into the conversation for Peter.

## 5. Send (Peter only)

A send mails real people, so it is Peter's, at his own terminal:

```bash
$S send --audience accounts --effective 2026-12-01 --en en.txt --de de.txt --linked
```

It shows the preview, then asks for the number of readers not yet told to be
typed at the terminal. A shell without a terminal — every agent's — stops
there with nothing sent. That gate is the approval: an agent hands Peter the
command (or starts it in his terminal panel, where he types the number) and
never reaches `change_notice.send` any other way, `supabase db query`
included.

Resend's free tier (100 a day, 3,000 a month) is shared with sign-in codes
and waitlist confirmations, so one run sends at most 50 and the schema
refuses past 50 a day or 1,500 in 30 days. A larger audience goes out over
several days: run the same `send` with the same files again; it continues the
same notice and never mails anyone twice. A paid plan raises the two
constants in `change_notice.send`, in a migration.

Before the first send to accounts: Apple's Hide My Email relay delivers only
mail from sources registered under Sign in with Apple → Email Sources in the
Apple developer account. Check that `hello@getemotely.com` (or
`getemotely.com`) is listed there.

## 6. Check and the record

`send` waits for Resend's answers and prints accepted and failed counts. pg_net
keeps the answers for six hours; until then

```bash
$S check --notice <id> --linked
```

reads them into the record. A failed batch (Resend refused it) is queued
again by the next `send`.

The record is `change_notice.notices` (audience, effective date, the exact
mails) and `change_notice.deliveries` (one row per reader: user or waitlist
id, language, when queued, Resend's status and id). No address is stored;
Resend's log, searched by the delivery's `resend_id`, has the address for as
long as Resend keeps it. "We told N people on this date":

```bash
supabase db query --linked "select n.created_at::date, n.effective_on, n.audience, count(*) filter (where d.status_code between 200 and 299) as accepted, count(*) as queued from change_notice.notices n join change_notice.deliveries d on d.notice_id = n.id group by n.id order by n.created_at"
```
