#!/bin/bash
# Aggregate every session's snapshot in ~/.claude/status-bar/usage/*.json into ONE
# authoritative reading. The NEWEST window wins (latest resets_at): an idle session
# re-reports the cached rate_limits of an OLD window, and that window's resets_at can
# still be in the future, so window recency — not magnitude — separates live from stale.
# Within the same window usage only CLIMBS, so the HIGHEST used_percentage is current.
#
# ONE jq call. No per-file validation: writers use "<id>.json.tmp.$$" + atomic
# mv, and that tmp suffix doesn't match *.json, so readers never see a partial
# file. (The old per-file validation loop spawned one jq per file — a fork storm.)
#
# Prints one JSON object on stdout.

DIR="$HOME/.claude/status-bar/usage"
EMPTY='{"session_pct":null,"session_resets_at":null,"session_written_at":0,"weekly_pct":null,"weekly_resets_at":null,"weekly_written_at":0}'

shopt -s nullglob
files=("$DIR"/*.json)
[ ${#files[@]} -eq 0 ] && { echo "$EMPTY"; exit 0; }

jq -s '
  # Consider only readings whose window has NOT reset yet (resets_at in the future).
  # Sort by window recency FIRST: a cached payload from an idle session belongs to an
  # older window (smaller resets_at) and must lose to any reading from the live window,
  # even if its percentage is higher. Within the same window usage only climbs, so the
  # HIGHEST percentage is the current value (newest write breaks ties).
  def pick(p; r):
    [ .[] | select(.[p] != null) | select((.[r] // 0) > now) ]
    | sort_by([.[r], .[p], (.written_at // 0)])
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
