-- The change notice (#108): one plain mail, before a material change to a
-- privacy notice takes effect, to confirmed waitlist addresses and to
-- account holders, each address once, in its language, with a record of
-- who was told and when. Run as postgres, the only role that may; no client
-- role reaches any of it. The Resend key is a throwaway created inside the
-- transaction, so nothing leaves the database: pg_net sends only on commit.
begin;
select plan(42);

-- Fixtures -------------------------------------------------------------------------

-- The waitlist's own triggers (rate limit per IP, confirmation mail) are not
-- what is under test, and a run of sign-ups without an IP would trip the
-- limit; they come back with the rollback.
alter table public.waitlist disable trigger waitlist_guard;
alter table public.waitlist disable trigger waitlist_confirmation_mail;

-- Ana: an English account. Bea: a German account (the app kept "de"), also
-- on the waitlist. Cem: a German waitlist address. Dan: an account that
-- never entered its sign-in code. Eve: a waitlist address never confirmed.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-00000000000a', 'ana@example.com', now(), '{}'),
  ('00000000-0000-0000-0000-00000000000b', 'bea@example.com', now(),
    '{"app_locale": "de"}'),
  ('00000000-0000-0000-0000-00000000000d', 'dan@example.com', null, '{}');
insert into public.waitlist (id, email, locale, confirmed_at)
values
  ('00000000-0000-0000-0000-0000000000b1', 'bea@example.com', 'en', now()),
  ('00000000-0000-0000-0000-0000000000c1', 'cem@example.com', 'de', now()),
  ('00000000-0000-0000-0000-0000000000e1', 'eve@example.com', 'en', null);

create function pg_temp.message() returns jsonb language sql as $$
  select jsonb_build_object(
    'en', jsonb_build_object(
      'subject', 'What changes about your journal',
      'body', 'Hi,' || E'\n\n' || 'From December on, entries are read over time.'
    ),
    'de', jsonb_build_object(
      'subject', 'Was sich an deinem Tagebuch ändert',
      'body', 'Hallo,' || E'\n\n' || 'Ab Dezember werden Einträge über die Zeit gelesen.'
    )
  )
$$;
create function pg_temp.effective() returns date language sql as $$
  select current_date + 30
$$;
-- The batch pg_net queued, as JSON: one element per mail.
create function pg_temp.batch() returns jsonb language sql as $$
  select convert_from(body, 'utf8')::jsonb from net.http_request_queue
    where url = 'https://api.resend.com/emails/batch'
    order by id desc limit 1
$$;
create function pg_temp.mail_to(address text) returns jsonb language sql as $$
  select m from jsonb_array_elements(pg_temp.batch()) m
    where m -> 'to' ->> 0 = address
$$;

-- Nobody but postgres ------------------------------------------------------------

select ok(
  not has_schema_privilege('anon', 'change_notice', 'usage')
    and not has_schema_privilege('authenticated', 'change_notice', 'usage')
    and not has_schema_privilege('service_role', 'change_notice', 'usage'),
  'no client role, not even the service role, may reach the schema'
);
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'change_notice'
      and (has_function_privilege('anon', p.oid, 'execute')
        or has_function_privilege('authenticated', p.oid, 'execute')
        or has_function_privilege('service_role', p.oid, 'execute'))
  ),
  'nor execute any of its functions'
);
select ok(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'change_notice' and c.relkind = 'r'
      and (has_table_privilege('anon', c.oid, 'select')
        or has_table_privilege('authenticated', c.oid, 'select')
        or has_table_privilege('service_role', c.oid, 'select'))
  ),
  'nor read the record'
);
select ok(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'change_notice' and c.relkind = 'r'
      and not c.relrowsecurity
  ),
  'and the record has row-level security on, with no policy to open it'
);

-- The dry run --------------------------------------------------------------------

select is(
  change_notice.preview('both', pg_temp.effective(), pg_temp.message())
    -> 'recipients',
  '{"total": 3, "account": 2, "waitlist": 1, "en": 1, "de": 2}'::jsonb,
  'both sets, each address once: an account on the waitlist is told as the account'
);
select is(
  change_notice.preview('waitlist', pg_temp.effective(), pg_temp.message())
    -> 'recipients',
  '{"total": 2, "account": 0, "waitlist": 2, "en": 1, "de": 1}'::jsonb,
  'the waitlist alone: confirmed addresses only, each in its own language'
);
select is(
  change_notice.preview('accounts', pg_temp.effective(), pg_temp.message())
    -> 'recipients',
  '{"total": 2, "account": 2, "waitlist": 0, "en": 1, "de": 1}'::jsonb,
  'the accounts alone: only those that signed in, German when the app kept "de"'
);
select is(
  (change_notice.preview('both', pg_temp.effective(), pg_temp.message())
    ->> 'lead_days')::int,
  30,
  'the dry run says how far ahead of the change the notice goes out'
);
select is(
  jsonb_path_query_array(
    change_notice.preview('both', pg_temp.effective(), pg_temp.message()),
    '$.mails[*] ? (@.recipients > 0) .kind'
  ),
  '["account", "account", "waitlist"]'::jsonb,
  'it renders every kind and language that has a reader'
);
select ok(
  (select m ->> 'text' from jsonb_array_elements(
      change_notice.preview('both', pg_temp.effective(), pg_temp.message())
        -> 'mails') m
    where m ->> 'kind' = 'account' and m ->> 'locale' = 'en')
    like 'Hi,' || E'\n\n' || 'From December on, entries are read over time.'
      || E'\n\n' || '-- ' || E'\n' || 'This change takes effect on '
      || trim(to_char(pg_temp.effective(), 'FMMonth FMDD, YYYY')) || '.%',
  'the English mail is the given text, then the date the change takes effect'
);
select ok(
  (select m ->> 'text' from jsonb_array_elements(
      change_notice.preview('both', pg_temp.effective(), pg_temp.message())
        -> 'mails') m
    where m ->> 'kind' = 'account' and m ->> 'locale' = 'en')
    like '%because you have an emotely account%'
      || 'https://getemotely.com/app-privacy%reply to this mail%',
  'and why the reader gets it, the notice it is about, and how to answer'
);
select ok(
  (select m ->> 'text' from jsonb_array_elements(
      change_notice.preview('both', pg_temp.effective(), pg_temp.message())
        -> 'mails') m
    where m ->> 'kind' = 'waitlist' and m ->> 'locale' = 'de')
    like 'Hallo,%Die Änderung gilt ab dem %'
      || '%auf der emotely-Warteliste bestätigt%'
      || 'https://getemotely.com/de/privacy%',
  'the German waitlist mail is German throughout and links the German site notice'
);
select is(
  (select m ->> 'subject' from jsonb_array_elements(
      change_notice.preview('both', pg_temp.effective(), pg_temp.message())
        -> 'mails') m
    where m ->> 'kind' = 'account' and m ->> 'locale' = 'de'),
  'Was sich an deinem Tagebuch ändert',
  'the subject is the one given for the language'
);
select is(
  change_notice.preview(
    'both', pg_temp.effective(), pg_temp.message() - 'de'
  ) -> 'recipients' -> 'en',
  '3'::jsonb,
  'without a German text, everyone is written to in English'
);
select is_empty(
  $$select 1 from net.http_request_queue
    union all select 1 from change_notice.notices
    union all select 1 from change_notice.deliveries$$,
  'a dry run sends nothing and records nothing'
);

-- What the dry run refuses -------------------------------------------------------

select throws_ok(
  format(
    $$select change_notice.preview('everyone', %L, %L)$$,
    pg_temp.effective(), pg_temp.message()
  ),
  '22023', null,
  'the audience is accounts, waitlist or both'
);
select throws_ok(
  format(
    $$select change_notice.preview('both', current_date, %L)$$,
    pg_temp.message()
  ),
  '22023', null,
  'a change that takes effect today is not notified before it takes effect'
);
select throws_ok(
  format(
    $$select change_notice.preview('both', %L, %L)$$,
    pg_temp.effective(), pg_temp.message() - 'en'
  ),
  '22023', null,
  'English is the one language every notice needs'
);
select throws_ok(
  format(
    $$select change_notice.preview('both', %L, %L)$$,
    pg_temp.effective(),
    pg_temp.message() || '{"fr": {"subject": "x", "body": "y"}}'
  ),
  '22023', null,
  'a language the waitlist and the app do not speak is refused'
);
select throws_ok(
  format(
    $$select change_notice.preview('both', %L, %L)$$,
    pg_temp.effective(),
    jsonb_set(pg_temp.message(), '{en,subject}', to_jsonb(E'two\nlines'::text))
  ),
  '22023', null,
  'a subject is one line'
);
select throws_ok(
  format(
    $$select change_notice.preview('both', %L, %L)$$,
    pg_temp.effective(),
    jsonb_set(pg_temp.message(), '{de,body}', '""'::jsonb)
  ),
  '22023', null,
  'a body is not empty'
);

-- The send -------------------------------------------------------------------------

select throws_ok(
  format(
    $$select change_notice.send('both', %L, %L)$$,
    pg_temp.effective(), pg_temp.message()
  ),
  'P0001', null,
  'without the Resend key the send fails loudly rather than telling nobody'
);

select vault.create_secret('re_test_key', 'resend_api_key', 'test only');

select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 3, "remaining": 0}'::jsonb,
  'a send queues every recipient of the dry run'
);
select results_eq(
  $$select method::text, url, headers ->> 'Authorization', headers ->> 'Content-Type',
      headers ->> 'Idempotency-Key' is not null
    from net.http_request_queue$$,
  $$values ('POST', 'https://api.resend.com/emails/batch', 'Bearer re_test_key', 'application/json', true)$$,
  'as one batch request to Resend, with the key from Vault and an idempotency key'
);
select is(
  (select array_agg(m -> 'to' ->> 0 order by m -> 'to' ->> 0)
    from jsonb_array_elements(pg_temp.batch()) m),
  array['ana@example.com', 'bea@example.com', 'cem@example.com'],
  'one mail per address, one address per mail: nobody sees another reader'
);
select is(
  pg_temp.mail_to('bea@example.com') - 'text',
  jsonb_build_object(
    'from', 'emotely <hello@getemotely.com>',
    'reply_to', 'hello@getemotely.com',
    'to', jsonb_build_array('bea@example.com'),
    'subject', 'Was sich an deinem Tagebuch ändert',
    'tags', jsonb_build_array(
      jsonb_build_object('name', 'kind', 'value', 'change_notice'),
      jsonb_build_object('name', 'notice', 'value',
        (select id::text from change_notice.notices))
    )
  ),
  'plain text from hello@, in the reader''s language, tagged with the notice'
);
select ok(
  pg_temp.mail_to('bea@example.com') ->> 'text' like '%emotely-Konto%'
    and pg_temp.mail_to('cem@example.com') ->> 'text' like '%Warteliste%'
    and pg_temp.mail_to('ana@example.com') ->> 'text' like '%emotely account%',
  'each reader is told why they get it: the account, or the waitlist'
);
select results_eq(
  $$select kind, user_id, waitlist_id, locale from change_notice.deliveries
    order by kind, locale$$,
  $$values
    ('account', '00000000-0000-0000-0000-00000000000b'::uuid, null::uuid, 'de'),
    ('account', '00000000-0000-0000-0000-00000000000a'::uuid, null::uuid, 'en'),
    ('waitlist', null::uuid, '00000000-0000-0000-0000-0000000000c1'::uuid, 'de')$$,
  'the record names each reader by id, never by address'
);
select ok(
  not exists (
    select 1 from information_schema.columns
    where table_schema = 'change_notice' and column_name ilike '%mail%'
  ),
  'and the record has no column an address could sit in'
);
select is(
  (select rendered from change_notice.notices),
  change_notice.preview('both', pg_temp.effective(), pg_temp.message()) -> 'mails'
    #- '{0,recipients}' #- '{1,recipients}' #- '{2,recipients}' #- '{3,recipients}',
  'the notice keeps the exact mails it sent, as the dry run rendered them'
);
select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 0, "remaining": 0}'::jsonb,
  'sending the same notice again tells nobody twice'
);
select is(
  (select count(*)::int from net.http_request_queue),
  1,
  'and asks Resend for nothing'
);

-- Did Resend take it --------------------------------------------------------------

insert into net._http_response (id, status_code, content, created)
select id, 200,
  '{"data": [{"id": "re-1"}, {"id": "re-2"}, {"id": "re-3"}]}', now()
from net.http_request_queue;

select is(
  change_notice.check((select id from change_notice.notices)),
  '{"queued": 3, "accepted": 3, "failed": 0, "unanswered": 0}'::jsonb,
  'check reads Resend''s answer into the record'
);
select is(
  (select array_agg(resend_id order by position) from change_notice.deliveries),
  array['re-1', 're-2', 're-3'],
  'each delivery keeps the id Resend gave its mail, which Resend''s log can show'
);

-- A refused batch is sent again ---------------------------------------------------

insert into public.waitlist (id, email, locale, confirmed_at)
values ('00000000-0000-0000-0000-0000000000f1', 'fay@example.com', 'en', now());
select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 1, "remaining": 0}'::jsonb,
  'an address confirmed since is told on the next run'
);
insert into net._http_response (id, status_code, content, created)
select max(id), 422, '{"name": "validation_error"}', now()
from net.http_request_queue;
select is(
  change_notice.check((select id from change_notice.notices)),
  '{"queued": 4, "accepted": 3, "failed": 1, "unanswered": 0}'::jsonb,
  'a refused batch is recorded as failed'
);
select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 1, "remaining": 0}'::jsonb,
  'and its readers are queued again on the next run'
);

-- Resend's free tier ---------------------------------------------------------------

-- Fifty more addresses than today's budget has room for.
insert into public.waitlist (email, locale, confirmed_at)
select 'reader' || n || '@example.com', 'en', now()
from generate_series(1, 60) n;
-- Today already spent 5 (three accepted, one failed, one queued again).
select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 45, "remaining": 15}'::jsonb,
  'a run sends at most what is left of the day''s 50 and says how many wait'
);
select throws_ok(
  format(
    $$select change_notice.send('both', %L, %L)$$,
    pg_temp.effective(), pg_temp.message()
  ),
  'P0001', null,
  'with the day spent, a second run fails clearly instead of overrunning Resend'
);
update change_notice.deliveries set queued_at = queued_at - interval '25 hours';
select is(
  change_notice.send('both', pg_temp.effective(), pg_temp.message())
    - 'notice_id',
  '{"queued": 15, "remaining": 0}'::jsonb,
  'the next day the rest goes out'
);
select is(
  (select count(distinct notice_id)::int from change_notice.deliveries),
  1,
  'one notice, however many runs it takes'
);

-- The record outlives the account, not the person -----------------------------------

delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select results_eq(
  $$select count(*)::int, count(user_id)::int from change_notice.deliveries
    where kind = 'account' and locale = 'en'$$,
  $$values (1, 0)$$,
  'a deleted account leaves the fact that a mail went out, not who it went to'
);

select * from finish();
rollback;
