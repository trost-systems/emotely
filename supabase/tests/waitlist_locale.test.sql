-- The waitlist mail in the reader's language (#252): the site's form sends
-- the language of the page it sits on, the row keeps it, and the
-- double-opt-in mail is written in it, linking that language's confirm page.
-- English is the default, for every row the site wrote before it sent a
-- language and for any caller that sends none. Driven as PostgREST would
-- drive it, with a throwaway Resend key rolled back with the transaction.
begin;
select plan(16);

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
create function pg_temp.from_ip(ip text) returns void language plpgsql as $$
begin
  perform set_config(
    'request.headers',
    json_build_object('x-forwarded-for', ip)::text,
    true
  );
end $$;
-- The body pg_net queued for the mail to [address].
create function pg_temp.mail_to(address text) returns jsonb language sql as $$
  select convert_from(body, 'utf8')::jsonb from net.http_request_queue
    where convert_from(body, 'utf8')::jsonb -> 'to' ->> 0 = address
$$;
create function pg_temp.token_of(address text) returns text language sql as $$
  select confirm_token::text from public.waitlist where email = address
$$;

select vault.create_secret('re_test_key', 'resend_api_key', 'test only');

-- The column -------------------------------------------------------------------

select col_not_null('public', 'waitlist', 'locale', 'every row has a language');
select col_default_is(
  'public', 'waitlist', 'locale', 'en'::text,
  'English unless the site says otherwise'
);

-- A German sign-up gets the German mail ------------------------------------------

select pg_temp.anon();
select pg_temp.from_ip('203.0.113.20');
select lives_ok(
  $$insert into public.waitlist (email, source, locale)
    values ('anna@example.com', 'landing', 'de')$$,
  'the site may send the language of the page'
);
select pg_temp.logout();

select is(
  pg_temp.mail_to('anna@example.com') ->> 'subject',
  'Bestätige deinen Platz auf der emotely-Warteliste',
  'a German sign-up gets a German subject'
);
select ok(
  pg_temp.mail_to('anna@example.com') ->> 'text' like 'Hallo,%',
  'and a German body'
);
select ok(
  pg_temp.mail_to('anna@example.com') ->> 'text' like
    '%https://getemotely.com/de/confirm?t=' || pg_temp.token_of('anna@example.com') || '%',
  'that links the German confirm page with the row''s token'
);
select ok(
  pg_temp.mail_to('anna@example.com') ->> 'html' like
    '%href="https://getemotely.com/de/confirm?t=' || pg_temp.token_of('anna@example.com') || '"%',
  'the HTML version carries the same German link'
);
select ok(
  pg_temp.mail_to('anna@example.com') ->> 'html' like '%Meine Adresse bestätigen%',
  'and a German button'
);
select is(
  pg_temp.mail_to('anna@example.com') - 'subject' - 'text' - 'html',
  jsonb_build_object(
    'from', 'emotely <hello@getemotely.com>',
    'reply_to', 'hello@getemotely.com',
    'to', jsonb_build_array('anna@example.com'),
    'tags', jsonb_build_array(jsonb_build_object('name', 'kind', 'value', 'waitlist_confirm'))
  ),
  'sender, recipient and tag are the same in every language'
);

-- English stays English -------------------------------------------------------------

select pg_temp.anon();
select pg_temp.from_ip('203.0.113.21');
insert into public.waitlist (email, source) values ('ben@example.com', 'landing');
insert into public.waitlist (email, source, locale) values ('cleo@example.com', 'landing', 'en');
select pg_temp.logout();

select results_eq(
  $$select locale from public.waitlist where email = 'ben@example.com'$$,
  $$values ('en'::text)$$,
  'a sign-up without a language is English'
);
select is(
  pg_temp.mail_to('ben@example.com') ->> 'subject',
  'Confirm your spot on the emotely waitlist',
  'and gets the English mail'
);
select ok(
  pg_temp.mail_to('ben@example.com') ->> 'text' like
    '%https://getemotely.com/confirm?t=' || pg_temp.token_of('ben@example.com') || '%',
  'linking the English confirm page'
);
select is(
  pg_temp.mail_to('cleo@example.com') ->> 'subject',
  'Confirm your spot on the emotely waitlist',
  'so does one that says English'
);
select ok(
  pg_temp.mail_to('cleo@example.com') ->> 'html' like
    '%href="https://getemotely.com/confirm?t=' || pg_temp.token_of('cleo@example.com') || '"%',
  'in HTML too'
);

-- Only the site's languages ---------------------------------------------------------

select pg_temp.anon();
select pg_temp.from_ip('203.0.113.22');
select throws_ok(
  $$insert into public.waitlist (email, locale) values ('dora@example.com', 'fr')$$,
  '23514',
  null,
  'a language the site does not speak is refused'
);
select throws_ok(
  $$update public.waitlist set locale = 'de'$$,
  '42501',
  null,
  'nobody can change a row''s language afterwards'
);
select pg_temp.logout();

select * from finish();
rollback;
