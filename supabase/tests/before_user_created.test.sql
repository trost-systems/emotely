-- No accounts for Google service accounts (#304). Anyone can create a
-- service account in their own Google Cloud project for free and mint it an
-- ID token for any audience, including our Google client id, and Auth's
-- ID-token grant needs no captcha. Without this hook a script creates
-- accounts without limit, each able to start model sessions that cost money.
-- The one exception is the probes' own identity, signin-probe in the
-- emotely-ci project, and only through Google sign-in.
--
-- Driven as Auth drives it: the hook is called with the user it is about to
-- create, and refuses by returning an error object.
begin;
select plan(16);

-- The event Auth sends, trimmed to what the hook reads.
create function pg_temp.event(email text, provider text) returns jsonb
language sql as $$
  select jsonb_build_object(
    'metadata', jsonb_build_object('name', 'before-user-created'),
    'user', jsonb_build_object(
      'email', email,
      'app_metadata', jsonb_build_object('provider', provider, 'providers', jsonb_build_array(provider))
    )
  )
$$;
create function pg_temp.verdict(email text, provider text) returns jsonb
language sql as $$
  select public.before_user_created(pg_temp.event(email, provider))
$$;

-- Only Auth calls it -------------------------------------------------------------

set local role anon;
select throws_ok($$select public.before_user_created('{}'::jsonb)$$, '42501',
  null, 'a visitor cannot call the hook');
reset role;
set local role authenticated;
select throws_ok($$select public.before_user_created('{}'::jsonb)$$, '42501',
  null, 'a signed-in user cannot call the hook');
reset role;
-- The test cannot become supabase_auth_admin, so it asks Postgres instead,
-- and calls the hook as the owner below.
select ok(
  has_function_privilege('supabase_auth_admin', 'public.before_user_created(jsonb)', 'execute')
    and has_schema_privilege('supabase_auth_admin', 'public', 'usage'),
  'Auth can call the hook'
);

-- People sign up as before ----------------------------------------------------

select is(pg_temp.verdict('someone@gmail.com', 'google'), '{}'::jsonb,
  'a person signing in with Google gets an account');
select is(pg_temp.verdict('someone@getemotely.com', 'email'), '{}'::jsonb,
  'a person asking for a sign-in code gets an account');
select is(pg_temp.verdict('someone@icloud.com', 'apple'), '{}'::jsonb,
  'a person signing in with Apple gets an account');
select is(pg_temp.verdict('someone@notgserviceaccount.com', 'google'), '{}'::jsonb,
  'a domain that only ends in the same letters is not a service account');
select is(pg_temp.verdict('someone@gserviceaccount.com.example.org', 'google'), '{}'::jsonb,
  'a domain that only starts like a service account is not one');
select is(pg_temp.verdict(null, 'phone'), '{}'::jsonb,
  'an account without an address is not a service account');

-- Service accounts do not -------------------------------------------------------

select is(pg_temp.verdict('bot@someones-project.iam.gserviceaccount.com', 'google')->'error'->>'http_code',
  '403', 'a service account of any project is refused');
select is(pg_temp.verdict('123456789-compute@developer.gserviceaccount.com', 'google')->'error'->>'http_code',
  '403', 'a default compute service account is refused');
select is(pg_temp.verdict('someones-project@appspot.gserviceaccount.com', 'google')->'error'->>'http_code',
  '403', 'an App Engine default service account is refused');
select is(pg_temp.verdict('Bot@Someones-Project.IAM.GServiceAccount.com', 'google')->'error'->>'http_code',
  '403', 'a service account is refused whatever the case of its address');
select is(pg_temp.verdict('ftl-runner@emotely-ci.iam.gserviceaccount.com', 'google')->'error'->>'http_code',
  '403', 'another service account of our own CI project is refused');

-- Except the probes' identity, through Google -------------------------------------

select is(pg_temp.verdict('signin-probe@emotely-ci.iam.gserviceaccount.com', 'google'), '{}'::jsonb,
  'the probes'' service account gets its account through Google sign-in');
select is(pg_temp.verdict('signin-probe@emotely-ci.iam.gserviceaccount.com', 'email')->'error'->>'http_code',
  '403', 'the probes'' address gets no account through any other sign-in');

select * from finish();
rollback;
