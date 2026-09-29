# The performance survey's history (#242), narrowed: the records of one
# device (by key, model, name or `<model>:<version>`, any part of it, any
# case), one screen, over the last $days days, oldest first.
#
# Input: every record (jq -s). Arguments: $device, $screen ("" for any),
# $days (--argjson), $now (an ISO 8601 time, or "" for now), $json
# (--argjson: records, one per line, instead of a table).

def names: [.key, .model, .name, "\(.model):\(.version)"] | map(ascii_downcase);

(if $now == "" then now else $now | fromdateiso8601 end) as $until
| ($device | ascii_downcase) as $wanted
| map(select(
    ($wanted == "" or any(.device | names[]; contains($wanted)))
    and ($screen == "" or .screen == $screen)
    and (.at | fromdateiso8601) >= $until - $days * 86400))
| sort_by(.at)
| if $json then .[]
  else
    ["at", "source", "commit", "device", "Hz", "screen", "frames", "build p50/p90/p99 ms",
     "raster p50/p90/p99 ms", "missed 60/120 Hz %", "startup ms", "requests"],
    (.[] | [.at, .source, .commit, "\(.device.model):\(.device.version)", .refresh_hz, .screen, .frames,
            "\(.build_ms.p50)/\(.build_ms.p90)/\(.build_ms.p99)",
            "\(.raster_ms.p50)/\(.raster_ms.p90)/\(.raster_ms.p99)",
            "\(.missed_60_percent)/\(.missed_120_percent)", .startup_ms,
            (.requests | to_entries | map("\(.key) \(.value)") | join(", "))])
    | @tsv
  end
