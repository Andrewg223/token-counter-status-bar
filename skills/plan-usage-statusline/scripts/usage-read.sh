#!/bin/bash
# Aggregate every session's snapshot in ~/.claude/usage/*.json into ONE
# authoritative reading: newest reset-window wins; within a window the highest
# used_percentage wins (usage only climbs); newest write breaks ties. The rule
# is deterministic, so every window computes the identical value.
#
# ONE jq call. No per-file validation: writers use "<id>.json.tmp.$$" + atomic
# mv, and that tmp suffix doesn't match *.json, so readers never see a partial
# file. (The old per-file validation loop spawned one jq per file — a fork storm.)
#
# Prints one JSON object on stdout.

DIR="$HOME/.claude/usage"
EMPTY='{"session_pct":null,"session_resets_at":null,"session_written_at":0,"weekly_pct":null,"weekly_resets_at":null,"weekly_written_at":0}'

shopt -s nullglob
files=("$DIR"/*.json)
[ ${#files[@]} -eq 0 ] && { echo "$EMPTY"; exit 0; }

jq -s '
  def pick(p; r):
    [ .[] | select(.[p] != null) ]
    | sort_by([(.[r] // -1), .[p], (.written_at // 0)])
    | last;
  (pick("session_pct"; "session_resets_at")) as $s |
  (pick("weekly_pct";  "weekly_resets_at"))  as $w |
  {
    session_pct:        ($s.session_pct        // null),
    session_resets_at:  ($s.session_resets_at  // null),
    session_written_at: ($s.written_at         // 0),
    weekly_pct:         ($w.weekly_pct         // null),
    weekly_resets_at:   ($w.weekly_resets_at   // null),
    weekly_written_at:  ($w.written_at         // 0)
  }
' "${files[@]}" 2>/dev/null || echo "$EMPTY"
