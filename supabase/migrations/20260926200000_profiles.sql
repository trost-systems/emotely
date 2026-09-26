-- The profile: what the user asked to be called (#204).
--
-- Onboarding asks "what should I call you?" before sign-up and keeps the
-- answer on the phone; once the account exists the app writes it here, and
-- from then on the journal greets by it and the companion is given it. The
-- name is personal data collected to provide the service (Art. 6 (1) (b)
-- GDPR), so the row lives next to the rest of the user's data, under the
-- same ownership model (ADR 0010): the app writes it with the user's JWT and
-- row-level security is the whole authorization model.
--
-- A user without a row simply has no name yet — the app runs the name step
-- once after sign-in in that case — so nothing creates a row on sign-up and
-- there is no trigger on auth.users.

create table public.profiles (
  -- The user is the key: one profile per user, and nothing to choose between.
  -- Defaults to the caller like sessions and entries do, so the app never has
  -- to send its own id and cannot send someone else's (RLS below).
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  display_name text not null,
  -- True when the name is one the app picked on "Skip" (Pebble, Maple, ...)
  -- rather than one the user typed: the companion uses a placeholder
  -- playfully and sparingly, and the Profile screen invites replacing it.
  name_is_placeholder boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- What a name may be is the product rule, held here so no client can store
  -- a different one: 1 to 40 characters, trimmed, any script. Three named
  -- constraints rather than one, so a refusal says which rule it broke.
  --
  -- **Characters are Unicode code points** (`char_length`), not bytes — a
  -- byte limit would give a Latin name 40 characters and a Japanese one 13 —
  -- and not grapheme clusters, the "characters" a person sees. Postgres has
  -- no grapheme segmentation, and one written here would drift from the
  -- Unicode version the phone's keyboard follows. Code points are what both
  -- ends can count identically: the app counts `runes`, not `length` (UTF-16
  -- units, which would count an emoji twice) and not `characters`
  -- (graphemes, which would let through a name this constraint refuses). The
  -- cost is that a name built from multi-code-point graphemes — a family
  -- emoji, a decomposed accent — fits fewer than 40 visible characters; 40
  -- code points is still comfortably more than a name in any script needs.
  constraint profiles_display_name_length
    check (char_length(display_name) between 1 and 40),
  -- Trimmed means what the app's trim means. Dart's String.trim removes every
  -- Unicode White_Space character plus the byte order mark, and so does
  -- nothing short of that list: Postgres' `btrim` only removes ASCII space,
  -- and `\s` depends on the database's locale. The list is spelled out so the
  -- rule is the same on every database this migration runs on.
  constraint profiles_display_name_trimmed
    check (display_name !~ (
      '^[\u0009-\u000d \u0085   -     　﻿]'
      '|[\u0009-\u000d \u0085   -     　﻿]$'
    )),
  -- The name is spliced into a greeting and into the companion's prompt, so
  -- a control character (Unicode category Cc) is refused anywhere in it: a
  -- line break in a name would read as a new line of the prompt. The name
  -- field is single-line, so no honest input carries one.
  constraint profiles_display_name_no_control
    check (display_name !~ '[\u0001-\u001f\u007f-\u009f]')
);
comment on table public.profiles is
  'What the user asked to be called; one row per user, deleted with the account.';
comment on column public.profiles.display_name is
  '1-40 Unicode code points, trimmed as Dart trims, no control characters.';
comment on column public.profiles.name_is_placeholder is
  'True when the app chose the name on Skip rather than the user typing it.';

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function extensions.moddatetime(updated_at);

-- Authorization ---------------------------------------------------------------

alter table public.profiles enable row level security;

-- Privileges are granted explicitly, never inherited from defaults: the anon
-- key alone gets nothing. The user may read, create and rename their own row
-- and nothing more:
--
-- - **No delete.** The profile goes with the account (`delete_account()`
--   deletes the auth user and this row cascades), never on its own, so there
--   is no signed-in state with a half-removed name to handle.
-- - **Column-scoped writes.** The timestamps are the server's, so the grant
--   leaves them out and a client cannot backdate `created_at` or freeze
--   `updated_at`. `user_id` stays writable so a PostgREST upsert that names
--   it (`ON CONFLICT ... DO UPDATE SET user_id = excluded.user_id`) works;
--   the policies' `with check` pins it to the caller either way.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (user_id, display_name, name_is_placeholder)
  on public.profiles to authenticated;
grant update (user_id, display_name, name_is_placeholder)
  on public.profiles to authenticated;

-- One policy per command rather than `for all`, so that granting delete by
-- mistake later would still delete nothing: no policy permits it.
create policy "users read their own profile" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "users create their own profile" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "users rename their own profile" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
