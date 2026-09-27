-- The consent record holds more than one decision (#204). Besides explicit
-- consent to send journal content to a model provider (Art. 9 (2) (a) GDPR),
-- the app now records the usage-analytics choice once the account exists
-- (§ 25 TDDDG, Art. 6 (1) (a) GDPR). Each is its own purpose with its own
-- versions and its own history, in the same append-only table.
--
-- Two things matter most here. A decision about one purpose must never
-- answer the other: an analytics "Allow" making journal consent stand would
-- send special-category data to a model provider on the strength of a tap
-- about counting screens. And the app already in testers' hands calls these
-- functions without a purpose, so that call must keep working and keep
-- meaning the journal.
begin;
select plan(40);

create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
end $$;
create function pg_temp.anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '', true);
end $$;
create function pg_temp.logout() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

insert into auth.users (id, email)
values
  ('00000000-0000-0000-0000-00000000000a', 'alice@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'bob@example.com');

-- Structure -----------------------------------------------------------------

select has_column(
  'public', 'consent_events', 'purpose',
  'every event names what it is consent to'
);
select col_not_null(
  'public', 'consent_events', 'purpose',
  'an event without a purpose cannot exist'
);
-- The functions default to the journal for the deployed app's sake; the
-- table does not, so a future write path has to say what it records.
select col_hasnt_default(
  'public', 'consent_events', 'purpose',
  'the table never assumes a purpose'
);

-- PostgREST picks a function by name and argument names. A second overload
-- of the same name would make the deployed app's purpose-less call
-- ambiguous (PGRST203) and break its consent gate outright, so the purpose
-- is a defaulted parameter of the one function, never a sibling.
select results_eq(
  $$select proname::text collate "default", count(*)::int
      from pg_proc
     where pronamespace = 'public'::regnamespace
       and proname in ('record_consent', 'withdraw_consent', 'consent_stands')
     group by 1
     order by 1$$,
  $$values ('consent_stands', 1), ('record_consent', 1), ('withdraw_consent', 1)$$,
  'each consent function exists exactly once'
);

-- The deployed app's call still means the journal -----------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');

-- Exactly the shape PostgREST sends for `rpc('record_consent', params:
-- {'version': ...})`: named arguments, no purpose.
select lives_ok(
  $$select public.record_consent(version => '2026-09-15')$$,
  'a consent recorded without a purpose is accepted'
);
select results_eq(
  'select purpose::text, action from public.consent_events',
  $$values ('journal'::text, 'granted'::text)$$,
  'and is recorded as consent to the journal'
);
select results_eq(
  $$select public.consent_stands(version => '2026-09-15')$$,
  $$values (true)$$,
  'asking without a purpose asks about the journal'
);
select results_eq(
  $$select public.consent_stands('2026-09-15', 'journal')$$,
  $$values (true)$$,
  'which is the same answer as naming it'
);

-- One purpose never answers the other ------------------------------------------

-- Same version string on purpose: the versions are dates, so two wordings
-- published on the same day share one, and only the purpose tells them apart.
select results_eq(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  $$values (false)$$,
  'journal consent does not make usage analytics stand'
);
select lives_ok(
  $$select public.record_consent(version => '2026-09-15', purpose => 'usage_analytics')$$,
  'a user allows usage analytics'
);
select results_eq(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  $$values (true)$$,
  'usage analytics stands once allowed'
);
select results_eq(
  $$select purpose::text from public.consent_events order by seq$$,
  $$values ('journal'::text), ('usage_analytics'::text)$$,
  'the choice is its own event in the same record'
);

-- Withdrawing one leaves the other exactly as it was.
select lives_ok(
  $$select public.withdraw_consent(version => '2026-09-15')$$,
  'a user withdraws journal consent the way the deployed app does'
);
select results_eq(
  $$select public.consent_stands('2026-09-15')$$,
  $$values (false)$$,
  'journal consent no longer stands'
);
select results_eq(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  $$values (true)$$,
  'and usage analytics is untouched by it'
);
select lives_ok(
  $$select public.withdraw_consent('2026-09-15', 'usage_analytics')$$,
  'a user turns usage analytics off'
);
select results_eq(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  $$values (false)$$,
  'usage analytics no longer stands'
);
-- The decisive direction: an analytics "Allow" must never be what lets a
-- session send journal content to a model provider.
select lives_ok(
  $$select public.record_consent('2026-09-15', 'usage_analytics')$$,
  'a user allows usage analytics again'
);
select results_eq(
  $$select public.consent_stands('2026-09-15')$$,
  $$values (false)$$,
  'an analytics grant does not bring journal consent back'
);
select results_eq(
  $$select purpose::text, action from public.consent_events order by seq$$,
  $$values ('journal'::text, 'granted'::text),
           ('usage_analytics'::text, 'granted'::text),
           ('journal'::text, 'withdrawn'::text),
           ('usage_analytics'::text, 'withdrawn'::text),
           ('usage_analytics'::text, 'granted'::text)$$,
  'the record reads every decision about both purposes in order'
);

-- Idempotence holds per purpose ------------------------------------------------

select lives_ok(
  $$select public.record_consent('2026-09-15', 'usage_analytics')$$,
  'allowing usage analytics that already stands is accepted'
);
select lives_ok(
  $$select public.withdraw_consent('2026-09-15')$$,
  'withdrawing journal consent that no longer stands is accepted'
);
select results_eq(
  'select count(*)::int from public.consent_events',
  $$values (5)$$,
  'neither appends anything'
);

-- The version rules hold for every purpose -------------------------------------

select throws_ok(
  format(
    $$select public.record_consent(%L, 'usage_analytics')$$,
    to_char(now() + interval '1 year', 'YYYY-MM-DD')
  ),
  '23514',
  null,
  'a usage-analytics version dated after today is refused'
);
select throws_ok(
  $$select public.record_consent('not-a-date', 'usage_analytics')$$,
  '23514',
  null,
  'a junk usage-analytics version is refused'
);
select results_eq(
  $$select public.consent_stands('2026-08-01', 'usage_analytics')$$,
  $$values (false)$$,
  'an allow for one wording says nothing about another'
);

-- Only the purposes the product has ---------------------------------------------

-- An unknown purpose is refused rather than recorded or quietly answered
-- "no": a typo in the app would otherwise read as a user who never decided,
-- and ask them again forever without anyone noticing why.
select throws_ok(
  $$select public.record_consent('2026-09-15', 'marketing')$$,
  '23514',
  null,
  'consent to an unknown purpose is refused'
);
select throws_ok(
  $$select public.consent_stands('2026-09-15', 'analytics')$$,
  '23514',
  null,
  'asking about an unknown purpose is refused'
);
select throws_ok(
  $$select public.withdraw_consent('2026-09-15', 'marketing')$$,
  '23514',
  null,
  'withdrawing an unknown purpose is refused'
);
select throws_ok(
  $$select public.record_consent('2026-09-15', null)$$,
  '23502',
  null,
  'a consent with no purpose at all is refused'
);

-- Still the controller's evidence, not the user's to author --------------------

select throws_ok(
  $$insert into public.consent_events (version, action, purpose)
    values ('2026-09-15', 'granted', 'usage_analytics')$$,
  '42501',
  null,
  'a user cannot write a usage-analytics event directly'
);
select throws_ok(
  $$update public.consent_events set purpose = 'journal'$$,
  '42501',
  null,
  'a user cannot move an event to another purpose'
);

-- Another user inherits nothing ------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000b');

select results_eq(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  $$values (false)$$,
  'another user does not inherit a usage-analytics allow'
);
select lives_ok(
  $$select public.record_consent('2026-09-15', 'usage_analytics')$$,
  'another user allows usage analytics for themselves'
);
select results_eq(
  'select count(*)::int from public.consent_events',
  $$values (1)$$,
  'and sees only their own event'
);

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select results_eq(
  $$select count(*)::int from public.consent_events
     where purpose = 'usage_analytics'$$,
  $$values (3)$$,
  'the other user''s allow did not reach this one''s history'
);

-- Anonymous callers are locked out of the new shape too -------------------------

select pg_temp.anon();

select throws_ok(
  $$select public.record_consent('2026-09-15', 'usage_analytics')$$,
  '42501',
  null,
  'anon cannot record a usage-analytics choice'
);
select throws_ok(
  $$select public.consent_stands('2026-09-15', 'usage_analytics')$$,
  '42501',
  null,
  'anon cannot ask whether usage analytics stands'
);
select throws_ok(
  $$select public.withdraw_consent('2026-09-15', 'usage_analytics')$$,
  '42501',
  null,
  'anon cannot withdraw a usage-analytics choice'
);

-- Deleting the account takes both histories with it -----------------------------

select pg_temp.logout();
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select is_empty(
  $$select * from public.consent_events
    where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  'both purposes cascade away with the account'
);

select * from finish();
rollback;
