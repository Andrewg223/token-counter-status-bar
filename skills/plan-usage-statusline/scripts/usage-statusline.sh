#!/bin/bash
# Plan-usage status line — ONE shared refresh; every other terminal just reads it.
#
# Cost model (the point of this design):
#   - Heavy aggregation (read all session files, pick the synced value) runs at
#     most once per REFRESH seconds across ALL terminals: whichever tick finds
#     the shared cache stale rebuilds it; everyone else just reads the cache.
#     So opening more terminals does NOT multiply the heavy work.
#   - A session records its own tiny snapshot at most once per COOL seconds
#     (this is the only way its rate_limits can be captured — Claude hands them
#     to the statusline command, nowhere else).
#   - A normal "just read and print" tick spawns two trivial commands (date,
#     stat) and no jq.

input=$(cat)
DIR="$HOME/.claude/usage"; CACHE="$HOME/.claude/usage-synced"
[ -d "$DIR" ] || mkdir -p "$DIR"
COOL=5        # this session re-records its own snapshot at most this often
REFRESH=8     # the shared aggregate is rebuilt (by one session) at most this often
now=$(date +%s)

# session id (pure bash, no spawn)
SID="unknown"
[[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && SID="${BASH_REMATCH[1]}"
SID="${SID//[^A-Za-z0-9_.-]/_}"
OWN="$DIR/$SID.json"

# --- data tap: record THIS session's snapshot, throttled to once per COOL ---
own_mtime=$(stat -f %m "$OWN" 2>/dev/null || echo 0)
if [ $(( now - own_mtime )) -ge "$COOL" ]; then
  TMP="$OWN.tmp.$$"
  OLD=$(jq -c . "$OWN" 2>/dev/null || echo '{}')
  if printf '%s' "$input" | jq --argjson old "$OLD" '{
        session_pct:       (.rate_limits.five_hour.used_percentage // $old.session_pct       // null),
        session_resets_at: (.rate_limits.five_hour.resets_at       // $old.session_resets_at // null),
        weekly_pct:        (.rate_limits.seven_day.used_percentage // $old.weekly_pct        // null),
        weekly_resets_at:  (.rate_limits.seven_day.resets_at       // $old.weekly_resets_at  // null),
        written_at:        (now | floor)
      }' > "$TMP" 2>/dev/null; then mv -f "$TMP" "$OWN"; else rm -f "$TMP" 2>/dev/null; fi
fi

# --- shared aggregate: rebuilt by ONE session per REFRESH; everyone else reads it ---
cts=0; SP=""; SR=""; WP=""; WR=""; WSTR=""
IFS=$'\t' read -r cts SP SR WP WR WSTR < "$CACHE" 2>/dev/null
cts=${cts:-0}
if [ ! -r "$CACHE" ] || [ $(( now - cts )) -ge "$REFRESH" ]; then
  read -r SP SR WP WR < <("$HOME/.claude/usage-read.sh" \
    | jq -r '[(.session_pct//""),(.session_resets_at//""),(.weekly_pct//""),(.weekly_resets_at//"")]|@tsv')
  find "$DIR" -name '*.json' -mmin +720 -delete 2>/dev/null
  if [ -n "$WR" ]; then
    if [ "$WR" -le "$now" ] 2>/dev/null; then WSTR="now"; else WSTR=$(date -r "$WR" '+%a %H:%M'); fi
  else WSTR=""; fi
  CTMP="$CACHE.tmp.$$"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$SP" "$SR" "$WP" "$WR" "$WSTR" > "$CTMP" && mv -f "$CTMP" "$CACHE"
fi

# --- render (pure bash; session countdown computed live so it stays current) ---
FILL=$(printf '\342\226\223'); EMPTY=$(printf '\342\226\221')
render_seg() {  # $1=label $2=pct $3=reset_string ; sets OUT and W
  local label="$1" pct="$2" reset="$3" bar="" i filled empty color pctstr
  if [ -z "$pct" ]; then OUT="$label --"; W=$(( ${#label} + 3 )); return; fi
  pct=$(printf '%.0f' "$pct"); [ "$pct" -gt 100 ] && pct=100; [ "$pct" -lt 0 ] && pct=0
  filled=$((pct / 10)); empty=$((10 - filled))
  for ((i = 0; i < filled; i++)); do bar+="$FILL"; done
  for ((i = 0; i < empty;  i++)); do bar+="$EMPTY"; done
  color='\033[32m'; [ "$pct" -ge 70 ] && color='\033[33m'; [ "$pct" -ge 90 ] && color='\033[31m'
  pctstr="${pct}%"
  OUT=$(printf '%s %b%s\033[0m %s \033[90m%s\033[0m' "$label" "$color" "$bar" "$pctstr" "$reset")
  W=$(( ${#label} + 1 + 10 + 1 + ${#pctstr} + 1 + ${#reset} ))
}

SRS=""
if [ -n "$SR" ]; then
  d=$(( SR - now ))
  if [ "$d" -le 0 ]; then SRS="now"; else SRS="$(( d / 3600 ))h$(( (d % 3600) / 60 ))m"; fi
fi
render_seg "SESSION" "$SP" "$SRS";  S="$OUT"; SW="$W"
render_seg "WEEKLY"  "$WP" "$WSTR"; WK="$OUT"; WW="$W"

cols=${COLUMNS:-80}; SEP="   "
if [ $(( SW + ${#SEP} + WW )) -le $(( cols - 1 )) ]; then
  printf '%s%s%s\n' "$S" "$SEP" "$WK"
else
  printf '%s\n%s\n' "$S" "$WK"
fi
