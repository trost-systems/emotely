-- The waitlist mail in the reader's language (#252). The German landing page
-- (/de) takes sign-ups in German; the double-opt-in mail was English for
-- everyone. Now the form sends the language of its page, the row keeps it,
-- and the mail is written in it and links that language's confirm page.
--
-- Deploy order: CI pushes this migration and Vercel deploys the site
-- independently. The column has a default, so a site that does not send a
-- language yet keeps working once this is live; a site that sends one before
-- this is live is answered 400 PGRST204 by PostgREST, which the form treats
-- as "no such column" and retries without it (apps/web/lib/waitlist.dart).

alter table public.waitlist
  add column locale text not null default 'en'
    check (locale in ('en', 'de'));
comment on column public.waitlist.locale is
  'The site language the address signed up in (en, de); the confirmation mail is written in it.';

-- anon may now insert three columns: the language joins the address and its
-- source. Nothing else changes: no select, no update, no other column.
grant insert (locale) on public.waitlist to anon;

-- The mail, in the row's language -------------------------------------------------
--
-- Same function as in 20260912213000_waitlist_double_opt_in.sql, with the
-- words and the link chosen by new.locale. English stays the fallback for
-- any value the check might one day allow before its words exist here.
create or replace function public.waitlist_confirmation_mail()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  site constant text := 'https://getemotely.com';
  german constant boolean := new.locale = 'de';
  home text := site || case when german then '/de' else '' end;
  key text;
  link text;
  subject text;
  body_text text;
  body_html text;
begin
  select decrypted_secret into key
    from vault.decrypted_secrets
    where name = 'resend_api_key';
  if key is null then
    raise warning 'waitlist: no resend_api_key in vault, no confirmation mail for %', new.email;
    return null;
  end if;

  link := home || '/confirm?t=' || new.confirm_token;
  if german then
    subject := 'Bestätige deinen Platz auf der emotely-Warteliste';
    body_text :=
      'Hallo,' || E'\n\n'
      || 'jemand, hoffentlich du, hat mit dieser Adresse frühen Zugang zu '
      || 'emotely angefragt. Bestätige sie, und dein Platz ist reserviert:'
      || E'\n\n'
      || link || E'\n\n'
      || 'Warst du das nicht, ignoriere diese E-Mail: Es passiert nichts, und '
      || 'die Adresse wird nach einer Woche gelöscht.' || E'\n\n'
      || 'Peter' || E'\n' || 'emotely · ' || home;
    body_html :=
      '<p>Hallo,</p>'
      || '<p>jemand, hoffentlich du, hat mit dieser Adresse frühen Zugang zu '
      || 'emotely angefragt. Bestätige sie, und dein Platz ist reserviert:</p>'
      || '<p><a href="' || link || '">Meine Adresse bestätigen</a></p>'
      || '<p>Warst du das nicht, ignoriere diese E-Mail: Es passiert nichts, '
      || 'und die Adresse wird nach einer Woche gelöscht.</p>'
      || '<p>Peter<br>emotely · <a href="' || home || '">' || home || '</a></p>';
  else
    subject := 'Confirm your spot on the emotely waitlist';
    body_text :=
      'Hi,' || E'\n\n'
      || 'Someone, hopefully you, asked for early access to emotely with '
      || 'this address. Confirm it and your spot is held:' || E'\n\n'
      || link || E'\n\n'
      || 'If that was not you, ignore this mail: nothing happens, and the '
      || 'address is deleted after a week.' || E'\n\n'
      || 'Peter' || E'\n' || 'emotely · ' || home;
    body_html :=
      '<p>Hi,</p>'
      || '<p>Someone, hopefully you, asked for early access to emotely with '
      || 'this address. Confirm it and your spot is held:</p>'
      || '<p><a href="' || link || '">Confirm my address</a></p>'
      || '<p>If that was not you, ignore this mail: nothing happens, and the '
      || 'address is deleted after a week.</p>'
      || '<p>Peter<br>emotely · <a href="' || home || '">' || home || '</a></p>';
  end if;

  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || key
    ),
    body := jsonb_build_object(
      'from', 'emotely <hello@getemotely.com>',
      'reply_to', 'hello@getemotely.com',
      'to', jsonb_build_array(new.email),
      'subject', subject,
      'text', body_text,
      'html', body_html,
      'tags', jsonb_build_array(
        jsonb_build_object('name', 'kind', 'value', 'waitlist_confirm')
      )
    ),
    timeout_milliseconds := 5000
  );
  return null;
end;
$$;
comment on function public.waitlist_confirmation_mail() is
  'Hands the double-opt-in mail for a new waitlist row to Resend via pg_net, in the row''s language.';

revoke execute on function public.waitlist_confirmation_mail()
  from public, anon, authenticated;
