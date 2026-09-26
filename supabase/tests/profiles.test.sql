-- The profile: what the user asked to be called, and whether that name is
-- one they chose or the placeholder the app gave them on "Skip" (#204).
-- Driven as the app drives it: the owner creates their row once the account
-- exists, renames themselves, and can never see or touch anyone else's. The
-- name reaches the model in every session, so what the table accepts is the
-- product rule, not a suggestion: 1 to 40 characters, trimmed, any script.
begin;
select plan(42);

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

select has_table('public', 'profiles', 'profiles table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'row-level security is on for profiles'
);
-- One row per user, keyed by the user: there is no second profile to pick.
select col_is_pk('public', 'profiles', 'user_id', 'the user is the key');

-- The owner creates and reads their profile -----------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000a');

select lives_ok(
  $$insert into public.profiles (display_name) values ('Alice')$$,
  'a user creates their profile; user_id defaults to the caller'
);
select results_eq(
  'select user_id, display_name, name_is_placeholder from public.profiles',
  $$values ('00000000-0000-0000-0000-00000000000a'::uuid, 'Alice'::text, false)$$,
  'the profile belongs to the caller and a name is chosen unless said otherwise'
);
select throws_ok(
  $$insert into public.profiles (display_name) values ('Alice again')$$,
  '23505',
  null,
  'a user has at most one profile'
);

-- Renaming, the Profile screen's one write ------------------------------------

select lives_ok(
  $$update public.profiles set display_name = 'Pebble', name_is_placeholder = true$$,
  'a user renames themselves, placeholder or not'
);
select results_eq(
  'select display_name, name_is_placeholder from public.profiles',
  $$values ('Pebble'::text, true)$$,
  'the rename is stored'
);
-- `now()` is transaction time, so the rename cannot be told apart from the
-- insert by the clock inside this one transaction; a planted stale value
-- being replaced is what shows the trigger ran.
select pg_temp.logout();
update public.profiles set updated_at = '2020-01-01'
  where user_id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
update public.profiles set display_name = 'Alice';
select results_eq(
  $$select updated_at = now() from public.profiles$$,
  $$values (true)$$,
  'renaming maintains updated_at'
);

-- The timestamps are the server's: the app has no reason to write them, so
-- the privilege to is simply not there.
select throws_ok(
  $$update public.profiles set created_at = '2020-01-01'$$,
  '42501',
  null,
  'a user cannot rewrite when their profile was created'
);
select throws_ok(
  $$update public.profiles set updated_at = '2020-01-01'$$,
  '42501',
  null,
  'a user cannot set updated_at by hand'
);
-- No delete: the profile goes with the account (below), never on its own,
-- so there is no state where a signed-in user's name was half removed.
select throws_ok(
  $$delete from public.profiles$$,
  '42501',
  null,
  'a user cannot delete their profile on its own'
);
select throws_ok(
  $$insert into public.profiles (user_id, display_name)
    values ('00000000-0000-0000-0000-00000000000b', 'Forged')$$,
  '42501',
  null,
  'a user cannot create a profile for someone else'
);
select throws_ok(
  $$update public.profiles set user_id = '00000000-0000-0000-0000-00000000000b'$$,
  '42501',
  null,
  'a user cannot hand their profile to someone else'
);

-- What a name may be ------------------------------------------------------------

-- Every one of these runs as the owner against their own row, so a refusal
-- here is the constraint speaking, not RLS.
select lives_ok(
  $$update public.profiles set display_name = 'A'$$,
  'one character is a name'
);
select throws_ok(
  $$update public.profiles set display_name = ''$$,
  '23514',
  null,
  'an empty name is refused'
);
select throws_ok(
  $$update public.profiles set display_name = '   '$$,
  '23514',
  null,
  'a name of only spaces is refused'
);
select throws_ok(
  $$update public.profiles set display_name = ' Alice'$$,
  '23514',
  null,
  'a leading space is refused; the app trims before it writes'
);
select throws_ok(
  $$update public.profiles set display_name = 'Alice '$$,
  '23514',
  null,
  'a trailing space is refused'
);
-- The app trims with Dart's String.trim, which removes every Unicode
-- White_Space character and the byte order mark, not only ASCII space. The
-- table refuses the same set at either end, so a name the app considers
-- trimmed is one the table considers trimmed, and nothing else is.
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'Alice '),
  '23514',
  null,
  'a trailing no-break space is refused'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'　Alice'),
  '23514',
  null,
  'a leading ideographic space is refused'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'﻿Alice'),
  '23514',
  null,
  'a leading byte order mark is refused'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'Alice\n'),
  '23514',
  null,
  'a trailing newline is refused'
);
-- Inside a name, a space is part of it.
select lives_ok(
  $$update public.profiles set display_name = 'Mary Ann'$$,
  'a space inside a name is kept'
);
-- The name is spliced into a greeting and into the companion's prompt, so a
-- control character anywhere in it — a line break, a tab, an escape — is
-- refused rather than carried into either.
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'Mary\nAnn'),
  '23514',
  null,
  'a line break inside a name is refused'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, E'Mary\tAnn'),
  '23514',
  null,
  'a tab inside a name is refused'
);

-- Length is counted in characters (Unicode code points), never bytes, so
-- every script gets the same 40.
select lives_ok(
  format($$update public.profiles set display_name = %L$$, repeat('a', 40)),
  'forty characters is a name'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, repeat('a', 41)),
  '23514',
  null,
  'forty-one characters is refused'
);
-- 40 CJK characters are 120 bytes in UTF-8; a byte limit would refuse this.
select lives_ok(
  format($$update public.profiles set display_name = %L$$, repeat('名', 40)),
  'forty characters of a multi-byte script is a name'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, repeat('名', 41)),
  '23514',
  null,
  'and forty-one of them is refused'
);
-- An emoji outside the Basic Multilingual Plane is one code point (two
-- UTF-16 units, four bytes): the count is the same one Dart's `runes` gives.
select lives_ok(
  format($$update public.profiles set display_name = %L$$, repeat('🦊', 40)),
  'forty astral-plane characters is a name'
);
select throws_ok(
  format($$update public.profiles set display_name = %L$$, repeat('🦊', 41)),
  '23514',
  null,
  'and forty-one of them is refused'
);
select throws_ok(
  $$update public.profiles set display_name = null$$,
  '23502',
  null,
  'a profile always has a name'
);

-- Another user sees and touches nothing ---------------------------------------

select pg_temp.login('00000000-0000-0000-0000-00000000000b');

select is_empty('select * from public.profiles', 'another user sees no profile');
select results_eq(
  $$with touched as (
      update public.profiles set display_name = 'Tampered' returning 1
    ) select count(*) from touched$$,
  $$values (0::bigint)$$,
  'another user cannot rename someone else'
);
select lives_ok(
  $$insert into public.profiles (display_name, name_is_placeholder)
    values ('Maple', true)$$,
  'another user creates their own profile'
);
select results_eq(
  'select count(*)::int from public.profiles',
  $$values (1)$$,
  'each user sees only their own profile'
);

-- Anonymous callers are locked out entirely -----------------------------------

select pg_temp.anon();

select throws_ok(
  'select * from public.profiles',
  '42501',
  null,
  'anon cannot read profiles'
);
select throws_ok(
  $$insert into public.profiles (user_id, display_name)
    values ('00000000-0000-0000-0000-00000000000a', 'Anon')$$,
  '42501',
  null,
  'anon cannot write a profile'
);

-- Deleting the account takes the profile with it -------------------------------

-- Through the same call the app and the web deletion page make, not a
-- direct delete: this is the path that has to take the name along.
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select results_eq(
  'select public.delete_account()',
  $$values (true)$$,
  'the owner deletes their account'
);
select pg_temp.logout();
select is_empty(
  $$select * from public.profiles
    where user_id = '00000000-0000-0000-0000-00000000000a'$$,
  'the profile cascades away with the account'
);
select isnt_empty(
  $$select 1 from public.profiles
    where user_id = '00000000-0000-0000-0000-00000000000b'$$,
  'and takes nobody else''s with it'
);

select * from finish();
rollback;
