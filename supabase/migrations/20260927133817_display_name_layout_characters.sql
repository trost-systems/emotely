-- A display name is one line, and reads in the order it was typed (#214).
--
-- `profiles_display_name_no_control` refuses control characters (Unicode
-- category Cc) so that a name cannot carry a line break into the greeting
-- or the companion's prompt. Two line breaks are not control characters and
-- got through: LINE SEPARATOR U+2028 and PARAGRAPH SEPARATOR U+2029
-- (categories Zl and Zp), which `JSON.stringify` does not escape either. A
-- fourth rule refuses them anywhere in the name; at either end the trimmed
-- rule already did, since both are Unicode White_Space.
--
-- **Which invisible format characters (Cf) are refused, and which are not.**
-- The same rule refuses the bidirectional embeddings and overrides
-- (U+202A-U+202E) and isolates (U+2066-U+2069). Each opens a run of
-- reordered text that lasts past the name: an unclosed RIGHT-TO-LEFT
-- OVERRIDE would print the rest of the greeting backwards, and in the prompt
-- it makes what a reviewer sees differ from what the model reads. No name
-- needs one; a keyboard does not type them. Every other Cf character stays
-- allowed, because names and emoji are made of them:
--
-- - ZERO WIDTH NON-JOINER U+200C spells Persian and many Indic names.
-- - ZERO WIDTH JOINER U+200D builds emoji sequences (families, skin tones,
--   professions), which the length rule already counts code point by code
--   point.
-- - The tag characters U+E0020-U+E007F build the subdivision flags
--   (England, Scotland, Wales).
-- - LEFT-TO-RIGHT and RIGHT-TO-LEFT MARK (U+200E, U+200F) and ARABIC LETTER
--   MARK (U+061C) are zero-width letters of a direction: they settle the
--   neighbouring punctuation of a mixed-script name and open no run, so they
--   cannot reorder anything past the name.
-- - The rest (ZERO WIDTH SPACE, WORD JOINER, a byte order mark inside the
--   name, soft hyphen) are invisible but change neither lines nor order;
--   refusing them would reject pasted names for nothing a reader could see.
--
-- The app's `DisplayName.check` (`layoutCharacter`) and the agent's contract
-- (`userContext` in `packages/contract`) hold the same rule, so a name this
-- table takes is one both accept.
--
-- **Existing rows.** Nothing refused these characters until now, so a row
-- may hold one, and the hosted data is not something to look at to find
-- out. Adding the constraint plainly would then fail the deploy. So:
--
-- 1. The constraint is added `not valid`: from this statement on, every
--    insert and update is checked, so no new row can hold one, but the rows
--    already there are not.
-- 2. Each row that holds one is repaired the way its owner would have
--    typed it: a separator becomes a space, a bidi control is dropped. A
--    repair the other rules refuse (a name that was nothing but bidi
--    controls, or one left with a space at its end) deletes the row
--    instead; an account without a profile is a supported state, and the
--    app asks for the name again at the next sign-in.
-- 3. The constraint is validated, which step 2 made sure cannot fail.
alter table public.profiles
  add constraint profiles_display_name_no_layout_character
    check (display_name !~ '[\u2028\u2029\u202a-\u202e\u2066-\u2069]')
    not valid;

do $$
declare
  broken record;
begin
  for broken in
    select user_id, display_name from public.profiles
    where display_name ~ '[\u2028\u2029\u202a-\u202e\u2066-\u2069]'
  loop
    begin
      update public.profiles
      set display_name = regexp_replace(
        regexp_replace(broken.display_name, '[\u2028\u2029]', ' ', 'g'),
        '[\u202a-\u202e\u2066-\u2069]', '', 'g'
      )
      where user_id = broken.user_id;
    exception when check_violation then
      delete from public.profiles where user_id = broken.user_id;
    end;
  end loop;
end $$;

alter table public.profiles
  validate constraint profiles_display_name_no_layout_character;

comment on column public.profiles.display_name is
  '1-40 Unicode code points, trimmed as Dart trims, no control characters, '
  'no line or paragraph separators, no bidirectional embeddings, overrides '
  'or isolates.';
