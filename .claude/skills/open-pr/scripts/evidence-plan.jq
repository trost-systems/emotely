# Which screens of the feature map a diff changes (#172), for evidence.sh.
#
# Input: the feature map as JSON (`yq -o json`). Arguments:
#   $files  the changed paths, one per line
#   $max    how many screens at most
#   $video  on, off or auto: auto records when a planned screen is a flow
#   $only   comma-separated screens (slug or route) that replace the diff
#
# A feature package's library code and copy (lib/, l10n/) change the
# screens whose `package` it is. The design system and the app itself
# (lib/, l10n/, assets/) change every screen: the screens a feature change
# names come first, the rest fill up to $max, and the plan names what it
# left out. Tests, other utilities, scripts and docs change no screen.
# The plan keeps the map's order, which is the order a walk visits them in:
# the signed-out screens last.

# JournalRoute -> journal, PrivacySettingsRoute -> privacy_settings.
def slug: sub("Route$"; "") | gsub("(?<a>[a-z0-9])(?<b>[A-Z])"; "\(.a)_\(.b)") | ascii_downcase;
def every_screen: test("^apps/mobile/(packages/utility/design_system/(lib|l10n)/|app/(lib|l10n|assets)/)");
def package_of: capture("^apps/mobile/packages/[^/]+/(?<p>[^/]+)/(lib|l10n)/").p;
def two_digits: tostring | if length < 2 then "0" + . else . end;

[.screens | to_entries[] | .value + {index: .key, slug: (.value.route | slug)}] as $all
| ($files | split("\n") | map(select(length > 0))) as $changed
| ($only | split(",") | map(gsub("\\s"; "")) | map(select(length > 0))) as $names
| if ($names | length) > 0 then
    {
      picked: [$names[] as $name
        | ([$all[] | select(.slug == $name or .route == $name)]
          | if length == 0 then error("no screen \"\($name)\" in the feature map") else .[0] end)],
      every: false,
      omitted: []
    }
  else
    ([$changed[] | package_of] | unique) as $packages
    | any($changed[]; every_screen) as $every
    | [$all[] | select(.package as $p | any($packages[]; . == $p))] as $direct
    | (if $every then $direct + [$all[] | select(.package as $p | any($packages[]; . == $p) | not)]
       else $direct end) as $wanted
    | {picked: $wanted[:$max], every: $every, omitted: [$wanted[$max:][] | .route]}
  end
| (.picked | unique_by(.index)) as $picked
| {
    every,
    omitted,
    screens: [$picked | to_entries[] | .value + {n: (.key + 1 | two_digits)}
      | {n, slug, route, package, path, reach, flow: (.flow // false)}]
  }
| .video = (if $video == "on" then true elif $video == "off" then false else any(.screens[]; .flow) end)
