#!/bin/bash
# Aggregate every session's snapshot in ~/.claude/utility-system/usage/*.json into ONE
# authoritative reading. Account-wide usage only CLIMBS within a window, so the truth is
# the HIGHEST used_percentage among readings whose window has not reset yet (resets_at in
# the future). Highest-wins is deterministic (every window computes the same value, no
# flicker) and a stale low snapshot an idle session re-reports can never win.
#
# ONE jq call. No per-file validation: writers use "<id>.json.tmp.$$" + atomic
# mv, and that tmp suffix doesn't match *.json, so readers never see a partial
# file. (The old per-file validation loop spawned one jq per file — a fork storm.)
#
# Prints one JSON object on stdout.

DIR="$HOME/.claude/utility-system/usage"
EMPTY='{"session_pct":null,"session_resets_at":null,"session_written_at":0,"weekly_pct":null,"weekly_resets_at":null,"weekly_written_at":0}'

shopt -s nullglob
files=("$DIR"/*.json)
[ ${#files[@]} -eq 0 ] && { echo "$EMPTY"; exit 0; }

jq -s '
  # Consider only readings whose window has NOT reset yet (resets_at in the future) — a
  # past reset is a stale window an idle session re-reported. Usage only climbs within a
  # window, so the HIGHEST percentage is the current value (newest write breaks ties).
  # Highest-wins is immune to an idle session re-stamping an old snapshot as "fresh".
  def pick(p; r):
    [ .[] | select(.[p] != null) | select((.[r] // 0) > now) ]
    | sort_by([.[p], (.written_at // 0)])
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
