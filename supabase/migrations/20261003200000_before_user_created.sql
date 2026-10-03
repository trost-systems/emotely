-- No accounts for Google service accounts (#304).
--
-- Auth's ID-token grant (`/token?grant_type=id_token`, provider google) is
-- exempt from the captcha (#94), and it accepts any token Google signed
-- whose audience is one of our Google client ids. A service account's token
-- is one: anyone can create a service account in their own Google Cloud
-- project for free and mint it an ID token for any audience, with no nonce,
-- and Auth then creates an account from its `email` claim. Tested on the
-- hosted project on 2026-10-03: the grant answered 200 and created a user.
-- Unchecked, a script creates accounts without limit, without a captcha, and
-- each can start model sessions that cost money.
--
-- So Auth's before-user-created hook refuses every address on Google's
-- service-account domains (`*.gserviceaccount.com`). People never sign in
-- with one. The single exception is the probes' identity: the live smoke
-- and the latency probe sign in as `signin-probe` in the `emotely-ci`
-- project, keyless from GitHub Actions, and only through Google sign-in.
--
-- Only new accounts pass through here; an existing account is untouched.
create function public.before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  email text := lower(event -> 'user' ->> 'email');
  provider text := event -> 'user' -> 'app_metadata' ->> 'provider';
begin
  if email is null or email !~ '@([a-z0-9-]+\.)*gserviceaccount\.com$' then
    return '{}'::jsonb;
  end if;
  if email = 'signin-probe@emotely-ci.iam.gserviceaccount.com' and provider = 'google' then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object(
    'error', jsonb_build_object(
      'http_code', 403,
      'message', 'Service accounts cannot create an account.'
    )
  );
end $$;

comment on function public.before_user_created(jsonb) is
  'Auth hook: refuses Google service accounts as new users, except the probes'' signin-probe (#304).';

-- Auth alone calls it (supabase_auth_admin); nobody reaches it through the API.
revoke execute on function public.before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.before_user_created(jsonb) to supabase_auth_admin;
