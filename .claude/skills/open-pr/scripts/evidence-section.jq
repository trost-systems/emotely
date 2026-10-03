# The before/after section evidence.sh writes into a pull request's body
# (#172), as raw text.
#
# Input: the plan (evidence-plan.jq). Arguments:
#   $urls   the uploaded files, label -> URL: "base:01-journal",
#           "head:01-journal", ..., "base:video", "head:video"
#   $meta   {base, head, speed}: the two commits and the video's speed
#   $start, $end  the markers that let a re-run find and replace it
#
# Each screen is one table row, before and after side by side, each image
# shown 300 px wide (uploaded 600 px wide, sharp on a 2x screen) over its
# caption. Markdown has no image width, hence the <img> tags. A video URL
# alone in its paragraph is what GitHub turns into a player.

def title: .slug | gsub("_"; " ") | (.[:1] | ascii_upcase) + .[1:];
def cell($side; $word):
  (title) as $title
  | $urls["\($side):\(.n)-\(.slug)"] as $url
  | if $url then
      "<img src=\"\($url)\" width=\"300\" alt=\"\($title) (\(.route)) \($word) this change\"><br>\($title), \($word)"
    else "\($title), \($word): no screenshot" end;
def video($side; $word):
  $urls["\($side):video"] as $url
  | if $url then ["\($word):", "", $url, ""] else [] end;

[
  $start,
  "## Before and after",
  "",
  "The screens this pull request changes, on the base (`\($meta.base)`) and on its head (`\($meta.head)`): an iOS simulator signed in as the smoke account, with made-up content only. Written by `.claude/skills/open-pr/scripts/evidence.sh`; running it again replaces this section.",
  "",
  "| Before | After |",
  "| :---: | :---: |",
  (.screens[] | "| \(cell("base"; "before")) | \(cell("head"; "after")) |"),
  "",
  (if (.omitted | length) > 0 then
     "Left out, over the cap on screens: \(.omitted | map("`\(.)`") | join(", ")).", ""
   else empty end),
  (if $urls["base:video"] or $urls["head:video"] then
     "Video of the walk at \($meta.speed)x speed.", "",
     (video("base"; "Before") + video("head"; "After"))[]
   else empty end),
  $end
] | join("\n")
