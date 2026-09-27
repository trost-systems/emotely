-- The consent record gains a purpose: usage analytics beside the journal
-- (#204).
--
-- The app used to start PostHog on first launch without asking, which § 25
-- TDDDG does not allow: reading a device identifier and counting how the app
-- is used is not strictly necessary for the service, so it needs consent
-- (Art. 6 (1) (a) GDPR). Before sign-up that choice can only live on the
-- device — there is no account to attach it to — but once the account exists
-- the controller has the same duty to demonstrate it as for journal consent
-- (Art. 7 (1)), so it is appended here, under the same append-only rules
-- (ADR 0014): its own events, its own versions, the latest event wins.
--
-- A purpose column on the one table rather than a second table, because
-- everything that makes the record evidence — no write privilege, the
-- definer functions, the ordering by `seq`, the version rules, the cascade —
-- is the same for every purpose, and a second copy of it would be a second
-- place for it to drift.

-- The purposes the product has. A domain rather than a check on the column,
-- so the one list types both the column and every function parameter: an
-- unknown purpose is refused (23514) wherever it is named, including by the
-- read-only `consent_stands`, where a typo would otherwise be answered "no"
-- forever and re-ask the user without anyone noticing why. `null` is left to
-- the column's `not null` (a domain's own `not null` is not enforced on
-- function arguments, so it would promise more than it holds).
create domain public.consent_purpose as text
  check (value in ('journal', 'usage_analytics'));
comment on domain public.consent_purpose is
  'What a consent event is about: journal (Art. 9 (2) (a) GDPR, content to a '
  'model provider) or usage_analytics (§ 25 TDDDG, PostHog).';

-- Every event recorded so far is journal consent, the only purpose there
-- was. The default fills them in — a constant default is a catalog change in
-- Postgres 11 and later, not a table rewrite — and is then dropped, so the
-- table never assumes a purpose for a future row: whatever writes here has to
-- say what it is recording. (The functions below do default to the journal,
-- for a different reason: the app already in testers' hands.)
alter table public.consent_events
  add column purpose public.consent_purpose not null default 'journal';
alter table public.consent_events
  alter column purpose drop default;
comment on column public.consent_events.purpose is
  'What the consent is to; each purpose has its own versions and history.';

comment on table public.consent_events is
  'Append-only history of consent per user, purpose and notice version: '
  'journal (Art. 9 (2) (a) GDPR) and usage_analytics (§ 25 TDDDG).';

-- The query every function makes is now the latest event per user, purpose
-- and version.
drop index public.consent_events_user_version_idx;
create index consent_events_user_purpose_version_idx
  on public.consent_events (user_id, purpose, version, seq desc);

-- The functions -----------------------------------------------------------------

-- Each gains `purpose public.consent_purpose default 'journal'` as a second
-- parameter. The default is wire compatibility (ADR 0009): the app in
-- testers' hands calls `rpc('record_consent', params: {'version': ...})` and
-- friends with no purpose, and that call must keep working and keep meaning
-- the journal.
--
-- Drop and recreate rather than add an overload beside the old one:
-- PostgREST resolves an RPC by name and argument names, so a
-- `record_consent(text)` next to a `record_consent(text, consent_purpose)`
-- with a default would make the deployed app's call ambiguous (PGRST203)
-- and break its consent gate outright. There is exactly one of each.
-- Dropping discards the grants, so they are restated at the end.
--
-- The bodies are the ones from 20260915083929_explicit_consent.sql with the
-- purpose threaded through; the reasoning there (definer vs invoker, the
-- caller pinned inside, idempotence that never rewrites history) is
-- unchanged.

drop function public.record_consent(text);
drop function public.withdraw_consent(text);
drop function public.consent_stands(text);

-- Whether consent to `version` for `purpose` stands for the caller right
-- now: the latest event for that pair wins, and no event means no. A
-- decision about one purpose never answers another, even for the same
-- version string (two wordings published on the same day share a date).
create function public.consent_stands(
  version text,
  purpose public.consent_purpose default 'journal'
)
returns boolean
language sql
security invoker
stable
set search_path = ''
as $$
  select coalesce(
    (select action = 'granted'
       from public.consent_events
      where user_id = (select auth.uid())
        and consent_events.purpose = consent_stands.purpose
        and consent_events.version = consent_stands.version
      order by seq desc
      limit 1),
    false
  );
$$;
comment on function public.consent_stands(text, public.consent_purpose) is
  'Whether the caller''s consent to a notice version stands for a purpose '
  '(latest event wins; purpose defaults to journal).';

create function public.record_consent(
  version text,
  purpose public.consent_purpose default 'journal'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise insufficient_privilege using message = 'no authenticated caller';
  end if;
  perform public.assert_publishable_version(record_consent.version);
  if public.consent_stands(record_consent.version, record_consent.purpose) then
    return;
  end if;
  insert into public.consent_events (user_id, purpose, version, action)
    values (caller, record_consent.purpose, record_consent.version, 'granted');
end;
$$;
comment on function public.record_consent(text, public.consent_purpose) is
  'Appends the caller''s consent to a notice version for a purpose '
  '(default journal); idempotent.';

create function public.withdraw_consent(
  version text,
  purpose public.consent_purpose default 'journal'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise insufficient_privilege using message = 'no authenticated caller';
  end if;
  if not public.consent_stands(withdraw_consent.version, withdraw_consent.purpose) then
    return;
  end if;
  insert into public.consent_events (user_id, purpose, version, action)
    values (caller, withdraw_consent.purpose, withdraw_consent.version, 'withdrawn');
end;
$$;
comment on function public.withdraw_consent(text, public.consent_purpose) is
  'Appends the caller''s withdrawal of a notice version for a purpose '
  '(default journal, Art. 7 (3)); idempotent.';

revoke execute on function public.record_consent(text, public.consent_purpose)
  from public, anon;
revoke execute on function public.withdraw_consent(text, public.consent_purpose)
  from public, anon;
revoke execute on function public.consent_stands(text, public.consent_purpose)
  from public, anon;
grant execute on function public.record_consent(text, public.consent_purpose)
  to authenticated;
grant execute on function public.withdraw_consent(text, public.consent_purpose)
  to authenticated;
grant execute on function public.consent_stands(text, public.consent_purpose)
  to authenticated;
