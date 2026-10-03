-- The journal day (#158): the day an entry is about. It is the local date
-- at which its session started, and a session started before 04:00 belongs
-- to the day before. The app computes it on the device when a session
-- starts and stores it on the session row; the entry takes it from there
-- when it is filed. A row written without one (an app build from before
-- #158, or a row from before this migration) gets it from its own
-- created_at in Europe/Berlin, where every user was when it shipped.
begin;
select plan(25);

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
end $$;
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

insert into auth.users (id, email)
values ('00000000-0000-0000-0000-00000000000a', 'alice@example.com');

-- Structure -----------------------------------------------------------------

select col_type_is('public', 'sessions', 'journal_day', 'date',
  'a session carries its journal day as a plain date');
select col_not_null('public', 'sessions', 'journal_day',
  'every session has a journal day');
select col_type_is('public', 'entries', 'journal_day', 'date',
  'an entry carries its journal day as a plain date');
select col_not_null('public', 'entries', 'journal_day',
  'every entry has a journal day');
select has_index('public', 'entries', 'entries_user_journal_day_idx',
  array['user_id', 'journal_day', 'created_at'],
  'the journal reads entries by journal day, then by when they were filed');

-- The 04:00 cutoff ------------------------------------------------------------

select is(public.journal_day('2026-10-03 03:59 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-02'::date, 'a session started at 03:59 belongs to the day before');
select is(public.journal_day('2026-10-03 04:00 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-03'::date, 'a session started at 04:00 belongs to that day');
select is(public.journal_day('2026-10-03 00:10 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-02'::date, 'a session started just after midnight belongs to the day before');
select is(public.journal_day('2026-10-03 23:59 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-03'::date, 'a session started late in the evening belongs to that day');
-- Clocks go forward at 02:00 on 2026-03-29: 04:00 is only three hours after
-- midnight that day, and still the cutoff.
select is(public.journal_day('2026-03-29 03:59 Europe/Berlin', 'Europe/Berlin'),
  '2026-03-28'::date, 'on the day clocks go forward, 03:59 belongs to the day before');
select is(public.journal_day('2026-03-29 04:00 Europe/Berlin', 'Europe/Berlin'),
  '2026-03-29'::date, 'on the day clocks go forward, 04:00 belongs to that day');
-- Clocks go back at 03:00 on 2026-10-25: 04:00 is five hours after midnight.
select is(public.journal_day('2026-10-25 03:59 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-24'::date, 'on the day clocks go back, 03:59 belongs to the day before');
select is(public.journal_day('2026-10-25 04:00 Europe/Berlin', 'Europe/Berlin'),
  '2026-10-25'::date, 'on the day clocks go back, 04:00 belongs to that day');
select is(public.journal_day('2026-10-03 04:30 Europe/Berlin', 'America/New_York'),
  '2026-10-02'::date, 'the day is read on the clock of the time zone it is asked for');

-- Sessions as the app writes them ---------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');

select lives_ok(
  $$insert into public.sessions (id, question_set_id, transcript, signature, journal_day)
    values ('10000000-0000-0000-0000-000000000001', 'default', '[]', 'sig', '2026-09-30')$$,
  'an app build that knows the journal day starts a session with it'
);
select is(
  (select journal_day from public.sessions where id = '10000000-0000-0000-0000-000000000001'),
  '2026-09-30'::date,
  'the session keeps the day the device computed'
);
select lives_ok(
  $$update public.sessions set transcript = '[{"role":"user"}]', signature = 'sig-2'
    where id = '10000000-0000-0000-0000-000000000001'$$,
  'a later round updates the session'
);
select is(
  (select journal_day from public.sessions where id = '10000000-0000-0000-0000-000000000001'),
  '2026-09-30'::date,
  'a later round, on any day or device, leaves the journal day alone'
);
select lives_ok(
  $$select public.complete_session(
      '10000000-0000-0000-0000-000000000001', 'Resumed.', '{}', '[]')$$,
  'the session is filed on a later day'
);
select is(
  (select journal_day from public.entries
    where session_id = '10000000-0000-0000-0000-000000000001'),
  '2026-09-30'::date,
  'the entry takes the journal day of its session, not the day it was filed'
);

-- An app build from before #158 sends no journal day.
select lives_ok(
  $$insert into public.sessions (id, question_set_id, transcript, signature, created_at)
    values ('10000000-0000-0000-0000-000000000002', 'default', '[]', 'sig',
            '2026-09-20 01:30 Europe/Berlin')$$,
  'an older app build starts a session without a journal day'
);
select is(
  (select journal_day from public.sessions where id = '10000000-0000-0000-0000-000000000002'),
  '2026-09-19'::date,
  'a session without a journal day gets one from when it started, in Europe/Berlin'
);

-- Rows from before the migration ------------------------------------------------

-- The migration backfills by clearing the day, which derives it again the
-- way an insert without one does. Only the owner of the tables can; the app
-- has no update on entries.
select pg_temp.logout();
-- Started late on 29 September, filed the next morning.
insert into public.sessions (id, user_id, question_set_id, transcript, signature,
                             status, created_at)
values ('10000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-00000000000a', 'default', '[]', 'sig',
        'completed', '2026-09-29 23:50 Europe/Berlin');
insert into public.entries (id, user_id, session_id, summary, answers, questions,
                            created_at)
values ('20000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-00000000000a',
        '10000000-0000-0000-0000-000000000003', 'Its session is left.', '{}', '[]',
        '2026-09-30 09:00 Europe/Berlin');
-- Filed at 03:00, its session deleted since.
insert into public.entries (id, user_id, summary, answers, questions, created_at)
values ('20000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-00000000000a', 'Its session is gone.', '{}', '[]',
        '2026-09-21 03:00 Europe/Berlin');
update public.sessions set journal_day = null;
update public.entries set journal_day = null;

select is(
  (select journal_day from public.sessions where id = '10000000-0000-0000-0000-000000000003'),
  '2026-09-29'::date,
  'a backfilled session takes the day it started, in Europe/Berlin'
);
select is(
  (select journal_day from public.entries where id = '20000000-0000-0000-0000-000000000003'),
  '2026-09-29'::date,
  'a backfilled entry whose session is left takes the day that session started'
);
select is(
  (select journal_day from public.entries where id = '20000000-0000-0000-0000-000000000001'),
  '2026-09-20'::date,
  'a backfilled entry whose session is gone takes the day it was filed, in Europe/Berlin'
);

select * from finish();
rollback;
