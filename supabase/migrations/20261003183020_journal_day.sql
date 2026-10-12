-- The journal day (#158): the day an entry is about, which is the local date
-- at which its session started, with a 04:00 cutoff, so a session started
-- before 04:00 belongs to the day before. It is a plain date, fixed once: a
-- user who travels later, or resumes on another day or device, keeps it.
--
-- The app computes it on the device when a session starts (the device's
-- time zone at that moment) and writes it on the session row; filing the
-- entry copies it from there. created_at stays, and orders entries within a
-- day.
--
-- A row written without one gets it from its own created_at, read in
-- Europe/Berlin: an app build from before #158 still starts sessions
-- without it, and every user at the time is an internal tester in Germany.
-- The same rule backfills the rows that exist today.

-- The journal day of a moment, on the clock of time_zone. Wall-clock
-- arithmetic on purpose: on the days clocks change, 04:00 is still 04:00,
-- not four hours after midnight.
create function public.journal_day(at timestamptz, time_zone text)
returns date
language sql
immutable
set search_path = ''
as $$
  select ((journal_day.at at time zone journal_day.time_zone)
          - interval '4 hours')::date;
$$;
comment on function public.journal_day(timestamptz, text) is
  'The day a session started at `at` belongs to: the local date, with a 04:00 cutoff.';

-- Callers are the triggers below, which run as the user who writes the row.
revoke execute on function public.journal_day(timestamptz, text) from public, anon;
grant execute on function public.journal_day(timestamptz, text) to authenticated;

-- Sessions ----------------------------------------------------------------------

alter table public.sessions add column journal_day date;
comment on column public.sessions.journal_day is
  'The day the session belongs to, computed on the device when it started (#158).';

-- A session written without a journal day gets one from when it started.
-- On update too, so clearing it derives it again: that is how the rows
-- below are backfilled, by the same rule an insert follows.
create function public.sessions_set_journal_day()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.journal_day is null then
    new.journal_day := public.journal_day(new.created_at, 'Europe/Berlin');
  end if;
  return new;
end;
$$;
revoke execute on function public.sessions_set_journal_day()
  from public, anon, authenticated;

create trigger sessions_set_journal_day
  before insert or update on public.sessions
  for each row execute function public.sessions_set_journal_day();

-- A backfill is not a round: it must not move updated_at.
alter table public.sessions disable trigger sessions_set_updated_at;
update public.sessions set journal_day = null;
alter table public.sessions enable trigger sessions_set_updated_at;

alter table public.sessions alter column journal_day set not null;

-- Entries -----------------------------------------------------------------------

alter table public.entries add column journal_day date;
comment on column public.entries.journal_day is
  'The day the entry is about: its session''s journal day (#158).';

-- An entry takes the journal day of its session, so complete_session needs
-- no change and an app build from before #158 files entries correctly. An
-- entry without a session left (deleted since, which sets session_id to
-- null) falls back to when it was filed.
create function public.entries_set_journal_day()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.journal_day is null then
    new.journal_day := coalesce(
      (select session.journal_day from public.sessions as session
        where session.id = new.session_id),
      public.journal_day(new.created_at, 'Europe/Berlin')
    );
  end if;
  return new;
end;
$$;
revoke execute on function public.entries_set_journal_day()
  from public, anon, authenticated;

create trigger entries_set_journal_day
  before insert or update on public.entries
  for each row execute function public.entries_set_journal_day();

update public.entries set journal_day = null;

alter table public.entries alter column journal_day set not null;

-- The journal lists entries by journal day, newest first, then by when they
-- were filed.
drop index public.entries_user_created_idx;
create index entries_user_journal_day_idx
  on public.entries (user_id, journal_day desc, created_at desc);
