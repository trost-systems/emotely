-- The change notice (#108). Both privacy notices promise an active notice
-- before a material change takes effect: the site notice by email to the
-- waitlist, the app notice to account holders. WP260 rev.01 paras 29-31 ask
-- for a channel devoted to the change, a notice that explains its likely
-- impact, and, for fundamental changes, one sent well in advance. This is
-- that channel and nothing else: one plain-text mail per notice, never a
-- newsletter.
--
-- Three functions are the whole interface, all in a schema no client role
-- may reach (ADR 0010: no service-role path, and here not even the service
-- role): `preview` (the dry run: who, how many, the rendered mails),
-- `send` (queues one batch to Resend through pg_net with the Vault key, the
-- pattern of the waitlist's confirmation mail) and `check` (reads Resend's
-- answer into the record). Only postgres may call them, which in production
-- means `supabase db query --linked` through the maintainer's CLI login; the
-- change-notice skill's script is the one way in, and its send needs a
-- human at a terminal.
--
-- Recipients: account holders who completed sign-in (`accounts`, for a
-- change to the app notice) or confirmed waitlist addresses (`waitlist`, for
-- a change to the site notice); `both` only when both notices change. An
-- address in both sets is one reader, told as the account. Each gets the
-- language the app kept for it (`app_locale`, as the sign-in mail uses) or
-- the one it signed up to the waitlist in, when the notice has a text in it;
-- English otherwise.
--
-- Every reader is told at least 30 days before the change takes effect
-- (Peter, 2026-10-03: one lead time for every material change; WP260 asks
-- for "well in advance" without a number). Every run checks it, so a notice
-- that takes several days to send needs its date that much further out.
--
-- Resend's free tier sends 100 mails a day and 3,000 a month, shared with
-- sign-in codes and waitlist confirmations. A change notice takes at most
-- half of each, over a rolling day and 30 days; a notice with more readers
-- goes out over several runs, one batch request each, and a run past the
-- budget fails instead of starving sign-in. A paid plan raises the
-- constants below, in a migration.

create schema change_notice;
comment on schema change_notice is
  'Mails about a material change to a privacy notice (#108); postgres only.';
revoke all on schema change_notice from public, anon, authenticated, service_role;

-- The record ------------------------------------------------------------------------
--
-- A notice is one message to one audience about one change; the same
-- message sent again continues it rather than starting another. A delivery
-- is one reader in one batch: by id, never by address, so the record proves
-- who was told and when without holding a mailbox. An account deleted later
-- leaves its delivery behind with the id cleared, so "we told N people on
-- this date" stays demonstrable after the person is gone.

create table change_notice.notices (
  id uuid primary key default gen_random_uuid(),
  audience text not null check (audience in ('accounts', 'waitlist', 'both')),
  effective_on date not null,
  -- What the operator wrote, one subject and body per language.
  message jsonb not null,
  -- Every mail as rendered and sent: kind, locale, subject, text.
  rendered jsonb not null,
  -- Of audience, date and message: the same notice run again continues.
  digest text not null unique,
  created_at timestamptz not null default now()
);
comment on table change_notice.notices is
  'One change notice: the audience, the date the change takes effect and the exact mails.';

create table change_notice.deliveries (
  id bigint generated always as identity primary key,
  notice_id uuid not null references change_notice.notices (id),
  kind text not null check (kind in ('account', 'waitlist')),
  user_id uuid references auth.users (id) on delete set null,
  waitlist_id uuid references public.waitlist (id) on delete set null,
  -- The language of the mail sent, not only of the reader.
  locale text not null check (locale in ('en', 'de')),
  -- The pg_net request of the batch, and this mail's place in it: Resend
  -- answers a batch with one id per mail, in order.
  request_id bigint not null,
  position int not null,
  queued_at timestamptz not null default now(),
  -- Filled by check(): Resend's status and id, or why it was refused.
  checked_at timestamptz,
  status_code int,
  resend_id text,
  error text
);
comment on table change_notice.deliveries is
  'One reader of one change notice, by id; Resend''s answer once check() has read it.';

create index deliveries_notice_id_idx on change_notice.deliveries (notice_id);
create index deliveries_queued_at_idx on change_notice.deliveries (queued_at);
create index deliveries_user_id_idx on change_notice.deliveries (user_id);
create index deliveries_waitlist_id_idx on change_notice.deliveries (waitlist_id);

alter table change_notice.notices enable row level security;
alter table change_notice.deliveries enable row level security;
revoke all on change_notice.notices, change_notice.deliveries
  from public, anon, authenticated, service_role;

-- The rules, one place each -----------------------------------------------------

create function change_notice.lead_days() returns int
language sql immutable set search_path = '' as $$ select 30 $$;
comment on function change_notice.lead_days() is
  'Days between every notice and the change it announces, at least.';

-- Half of Resend's free tier, the other half left to sign-in codes and
-- waitlist confirmations; 50 is also within a batch request's 100 mails.
create function change_notice.per_day() returns int
language sql immutable set search_path = '' as $$ select 50 $$;
create function change_notice.per_month() returns int
language sql immutable set search_path = '' as $$ select 1500 $$;

-- Checks and rendering ------------------------------------------------------------

create function change_notice.validate(audience text, effective_on date, message jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  lang text;
  part jsonb;
begin
  if audience is null or audience not in ('accounts', 'waitlist', 'both') then
    raise exception using errcode = '22023',
      message = 'change_notice: audience is accounts, waitlist or both';
  end if;
  if effective_on is null
    or effective_on < current_date + change_notice.lead_days()
  then
    raise exception using errcode = '22023',
      message = format(
        'change_notice: the change must take effect at least %s days from today (on or after %s)',
        change_notice.lead_days(), current_date + change_notice.lead_days()
      );
  end if;
  if jsonb_typeof(message) is distinct from 'object' or not message ? 'en' then
    raise exception using errcode = '22023',
      message = 'change_notice: the message needs an English text ("en")';
  end if;
  for lang, part in select key, value from jsonb_each(message) loop
    if lang not in ('en', 'de') then
      raise exception using errcode = '22023',
        message = format('change_notice: no reader speaks "%s"; the languages are en and de', lang);
    end if;
    if jsonb_typeof(part -> 'subject') is distinct from 'string'
      or btrim(part ->> 'subject') = ''
      or part ->> 'subject' ~ '[\r\n]'
    then
      raise exception using errcode = '22023',
        message = format('change_notice: the %s subject must be one non-empty line', lang);
    end if;
    if jsonb_typeof(part -> 'body') is distinct from 'string'
      or btrim(part ->> 'body') = ''
    then
      raise exception using errcode = '22023',
        message = format('change_notice: the %s body is empty', lang);
    end if;
  end loop;
end;
$$;

-- One mail as a reader of [kind] in [lang] reads it: the operator's text,
-- then a footer that the operator cannot forget: when the change takes
-- effect, why this reader gets the mail, which notice governs their data,
-- and that a reply reaches a person.
create function change_notice.render(kind text, lang text, effective_on date, message jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  site constant text := 'https://getemotely.com';
  german constant boolean := lang = 'de';
  months constant text[] := array[
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
    'September', 'Oktober', 'November', 'Dezember'
  ];
  notice_path text := case when kind = 'account' then '/app-privacy' else '/privacy' end;
  footer text;
begin
  if german then
    footer :=
      'Die Änderung gilt ab dem ' || extract(day from effective_on) || '. '
      || months[extract(month from effective_on)::int] || ' '
      || extract(year from effective_on) || '.' || E'\n'
      || case when kind = 'account'
        then 'Du bekommst diese E-Mail, weil du ein emotely-Konto hast.'
        else 'Du bekommst diese E-Mail, weil diese Adresse auf der '
          || 'emotely-Warteliste bestätigt ist.'
      end
      || ' Sie handelt nur von dieser Änderung: So schreiben wir nur, wenn '
      || 'sich an deinen Daten etwas Wesentliches ändert, nie zu Werbezwecken.'
      || E'\n'
      || 'Die Datenschutzerklärung: ' || site || '/de' || notice_path || E'\n'
      || 'Fragen oder Einwände: Antworte einfach auf diese E-Mail.';
  else
    footer :=
      'This change takes effect on '
      || to_char(effective_on, 'FMMonth FMDD, YYYY') || '.' || E'\n'
      || case when kind = 'account'
        then 'You get this mail because you have an emotely account.'
        else 'You get this mail because this address is confirmed on the '
          || 'emotely waitlist.'
      end
      || ' It is about this change alone: we write like this only when '
      || 'something material changes about your data, never to advertise.'
      || E'\n'
      || 'The privacy notice: ' || site || notice_path || E'\n'
      || 'Questions or objections: reply to this mail.';
  end if;

  return jsonb_build_object(
    'kind', kind,
    'locale', lang,
    'subject', btrim(message -> lang ->> 'subject'),
    'text', rtrim(message -> lang ->> 'body', E' \n\r\t')
      || E'\n\n' || '-- ' || E'\n' || footer
  );
end;
$$;

-- Who is told -----------------------------------------------------------------------
--
-- Everyone [audience] reaches, each address once, with both ids where the
-- address is in both sets: a reader told as one is never told again as the
-- other. `lang` is the language the mail is written in.
create function change_notice.recipients(audience text, message jsonb)
returns table (
  kind text, user_id uuid, waitlist_id uuid, email text, lang text, since timestamptz
)
language sql
stable
set search_path = ''
as $$
  with accounts as (
    select u.id, lower(u.email) as email,
      u.raw_user_meta_data ->> 'app_locale' as app_locale, u.created_at
    from auth.users u
    where audience in ('accounts', 'both')
      and u.email is not null
      and u.email_confirmed_at is not null
      and u.deleted_at is null
      and not u.is_anonymous
  ), waiting as (
    select w.id, w.email, w.locale, w.confirmed_at
    from public.waitlist w
    where audience in ('waitlist', 'both') and w.confirmed_at is not null
  ), readers as (
    select
      case when a.id is not null then 'account' else 'waitlist' end as kind,
      a.id as user_id,
      w.id as waitlist_id,
      coalesce(a.email, w.email) as email,
      case
        when a.app_locale in ('en', 'de') then a.app_locale
        else coalesce(w.locale, 'en')
      end as locale,
      coalesce(a.created_at, w.confirmed_at) as since
    from accounts a full join waiting w on w.email = a.email
  )
  select r.kind, r.user_id, r.waitlist_id, r.email,
    case when message ? r.locale then r.locale else 'en' end,
    r.since
  from readers r
$$;

-- The dry run -----------------------------------------------------------------------

create function change_notice.preview(audience text, effective_on date, message jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  counts jsonb;
  pending int;
  mails jsonb;
  this_digest text := md5(audience || '|' || effective_on || '|' || message::text);
begin
  perform change_notice.validate(audience, effective_on, message);

  select jsonb_build_object(
    'total', count(*),
    'account', count(*) filter (where r.kind = 'account'),
    'waitlist', count(*) filter (where r.kind = 'waitlist'),
    'en', count(*) filter (where r.lang = 'en'),
    'de', count(*) filter (where r.lang = 'de')
  ) into counts
  from change_notice.recipients(audience, message) r;

  select count(*) into pending
  from change_notice.recipients(audience, message) r
  where not exists (
    select 1 from change_notice.deliveries d
      join change_notice.notices n on n.id = d.notice_id
    where n.digest = this_digest
      and (d.checked_at is null or d.status_code between 200 and 299)
      and (d.user_id = r.user_id or d.waitlist_id = r.waitlist_id)
  );

  select jsonb_agg(
    change_notice.render(k.kind, l.lang, effective_on, message)
      || jsonb_build_object('recipients', (
        select count(*) from change_notice.recipients(audience, message) r
        where r.kind = k.kind and r.lang = l.lang
      ))
    order by k.ord, l.ord
  ) into mails
  from (values ('account', 1), ('waitlist', 2)) as k (kind, ord)
  cross join (values ('en', 1), ('de', 2)) as l (lang, ord)
  where message ? l.lang
    and (audience = 'both'
      or (audience = 'accounts' and k.kind = 'account')
      or (audience = 'waitlist' and k.kind = 'waitlist'));

  return jsonb_build_object(
    'audience', audience,
    'effective_on', effective_on,
    'lead_days', effective_on - current_date,
    'recipients', counts,
    'pending', pending,
    -- At most per_day() a day, and every run must still be lead_days()
    -- ahead: the last run is runs_needed - 1 days after the first.
    'runs_needed', ceil(pending::numeric / change_notice.per_day())::int,
    'per_day', change_notice.per_day(),
    'min_lead_days', change_notice.lead_days(),
    'mails', mails
  );
end;
$$;
comment on function change_notice.preview(text, date, jsonb) is
  'The dry run: recipient counts and every mail as it would go out. Sends and records nothing.';

-- Did Resend take it ----------------------------------------------------------------
--
-- pg_net keeps a response for six hours, so this runs soon after a send
-- (the skill's script runs it right away). A batch is all or nothing: a
-- refused one is failed for every reader in it, and the next send queues
-- them again.
create function change_notice.check(notice uuid)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  result jsonb;
begin
  update change_notice.deliveries d
    set checked_at = now(),
      status_code = r.status_code,
      resend_id = case when r.status_code between 200 and 299
        then r.content::jsonb -> 'data' -> d.position ->> 'id' end,
      error = case when r.status_code between 200 and 299 then null
        else coalesce(r.error_msg, left(r.content, 500), 'no answer') end
    from net._http_response r
    where d.notice_id = notice
      and d.checked_at is null
      and r.id = d.request_id;

  select jsonb_build_object(
    'queued', count(*),
    'accepted', count(*) filter (where d.status_code between 200 and 299),
    'failed', count(*) filter (
      where d.checked_at is not null
        and (d.status_code is null or d.status_code not between 200 and 299)
    ),
    'unanswered', count(*) filter (where d.checked_at is null)
  ) into result
  from change_notice.deliveries d
  where d.notice_id = notice;
  return result;
end;
$$;
comment on function change_notice.check(uuid) is
  'Reads Resend''s answers for a notice from pg_net into its deliveries and counts them.';

-- The send --------------------------------------------------------------------------

create function change_notice.send(audience text, effective_on date, message jsonb)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  per_day constant int := change_notice.per_day();
  per_month constant int := change_notice.per_month();
  this_digest text := md5(audience || '|' || effective_on || '|' || message::text);
  key text;
  notice uuid;
  rendered jsonb;
  pending jsonb;
  room int;
  batch_no int;
  batch jsonb;
  request bigint;
  queued int;
begin
  perform change_notice.validate(audience, effective_on, message);
  -- Two sends at once would each see the same readers as not yet told.
  if not pg_try_advisory_xact_lock(hashtext('change_notice.send')) then
    raise exception 'change_notice: another send is running; nothing sent';
  end if;

  select decrypted_secret into key
    from vault.decrypted_secrets
    where name = 'resend_api_key';
  if key is null then
    raise exception 'change_notice: no resend_api_key in vault, nothing sent';
  end if;

  rendered := (
    select jsonb_agg(m - 'recipients')
    from jsonb_array_elements(
      change_notice.preview(audience, effective_on, message) -> 'mails'
    ) m
  );
  insert into change_notice.notices (audience, effective_on, message, rendered, digest)
    values (audience, effective_on, message, rendered, this_digest)
    on conflict on constraint notices_digest_key do nothing;
  select n.id into notice from change_notice.notices n where n.digest = this_digest;

  -- What Resend refused since the last run is sent again below.
  perform change_notice.check(notice);

  select coalesce(jsonb_agg(to_jsonb(r) order by r.since, r.email), '[]')
  into pending
  from change_notice.recipients(audience, message) r
  where not exists (
    select 1 from change_notice.deliveries d
    where d.notice_id = notice
      and (d.checked_at is null or d.status_code between 200 and 299)
      and (d.user_id = r.user_id or d.waitlist_id = r.waitlist_id)
  );
  if jsonb_array_length(pending) = 0 then
    return jsonb_build_object('notice_id', notice, 'queued', 0, 'remaining', 0);
  end if;

  select least(
    per_day - count(*) filter (where d.queued_at > now() - interval '1 day'),
    per_month - count(*)
  ) into room
  from change_notice.deliveries d
  where d.queued_at > now() - interval '30 days';
  if room <= 0 then
    raise exception
      'change_notice: the change-notice budget (% a day, % in 30 days) is spent; % readers wait, run again tomorrow',
      per_day, per_month, jsonb_array_length(pending);
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'from', 'emotely <hello@getemotely.com>',
      'reply_to', 'hello@getemotely.com',
      'to', jsonb_build_array(p.reader ->> 'email'),
      'subject', m ->> 'subject',
      'text', m ->> 'text',
      'tags', jsonb_build_array(
        jsonb_build_object('name', 'kind', 'value', 'change_notice'),
        jsonb_build_object('name', 'notice', 'value', notice::text)
      )
    )
    order by p.ord
  ) into batch
  from jsonb_array_elements(pending) with ordinality as p (reader, ord)
  join jsonb_array_elements(rendered) m
    on m ->> 'kind' = p.reader ->> 'kind' and m ->> 'locale' = p.reader ->> 'lang'
  where p.ord <= room;

  select count(distinct d.request_id) + 1 into batch_no
  from change_notice.deliveries d where d.notice_id = notice;

  request := net.http_post(
    url := 'https://api.resend.com/emails/batch',
    body := batch,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || key,
      'Idempotency-Key', 'change-notice/' || notice || '/' || batch_no
    ),
    timeout_milliseconds := 10000
  );

  insert into change_notice.deliveries
    (notice_id, kind, user_id, waitlist_id, locale, request_id, position)
  select notice,
    p.reader ->> 'kind',
    case when p.reader ->> 'kind' = 'account' then (p.reader ->> 'user_id')::uuid end,
    case when p.reader ->> 'kind' = 'waitlist' then (p.reader ->> 'waitlist_id')::uuid end,
    p.reader ->> 'lang',
    request,
    p.ord - 1
  from jsonb_array_elements(pending) with ordinality as p (reader, ord)
  where p.ord <= room;
  get diagnostics queued = row_count;

  return jsonb_build_object(
    'notice_id', notice,
    'queued', queued,
    'remaining', jsonb_array_length(pending) - queued
  );
end;
$$;
comment on function change_notice.send(text, date, jsonb) is
  'Queues the next batch of a change notice to Resend and records each reader by id. Human-approved only.';

revoke execute on all functions in schema change_notice
  from public, anon, authenticated, service_role;
