#!/bin/bash
# Claude Utility System — status-bar renderer.
# Reads the config, renders ONLY the enabled panels as modular segments, then
# composes them into one row (wrapping to stacked rows when narrow). Designed to
# be cheap: the account-wide usage panel uses a shared cache (one session
# computes, the rest read); the other panels read this session's JSON directly.

input=$(cat)
DIR="$HOME/.claude/utility-system"
[ -r "$DIR/config" ] && . "$DIR/config"
: "${PANEL_USAGE:=on}"; : "${PANEL_CONTEXT:=on}"; : "${PANEL_COST:=off}"; : "${PANEL_ACTIVE:=on}"; : "${PANEL_GIT:=off}"; : "${LAYOUT:=auto}"

now=$(date +%s)
FILL=$(printf '\342\226\223'); EMP=$(printf '\342\226\221')
PLAINBAR="##########"        # ASCII twin of a 10-cell bar, for width math
SEGS=(); PLAINS=()

add() { SEGS+=("$1"); PLAINS+=("$2"); }   # $1 = coloured segment, $2 = plain ASCII twin (for width)

mkbar() { local p=$1 f e i b=""; [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
  f=$((p/10)); e=$((10-f)); i=0
  while [ $i -lt $f ]; do b+="$FILL"; i=$((i+1)); done
  i=0; while [ $i -lt $e ]; do b+="$EMP"; i=$((i+1)); done
  printf '%s' "$b"; }
colpct() { local p=$1; if [ "$p" -ge 90 ]; then printf '\033[31m'; elif [ "$p" -ge 70 ]; then printf '\033[33m'; else printf '\033[32m'; fi; }
# context bar uses a distinct hue (cyan) so it reads differently from the plan-limit
# bars; turns red only when nearly full (about to compact).
colctx() { local p=$1; if [ "$p" -ge 90 ]; then printf '\033[31m'; else printf '\033[36m'; fi; }
int() { printf '%.0f' "${1:-0}" 2>/dev/null || echo 0; }
# format a token count like the native counter: 413100 -> 413.1k, 257000 -> 257k, 1000000 -> 1M
fmtk() { local n=${1:-0} u d
  if [ "$n" -ge 1000000 ]; then u=$((n/1000000)); d=$(( (n%1000000 + 50000)/100000 )); [ "$d" -ge 10 ] && { u=$((u+1)); d=0; }; [ "$d" -eq 0 ] && printf '%dM' "$u" || printf '%d.%dM' "$u" "$d"
  elif [ "$n" -ge 1000 ]; then u=$((n/1000)); d=$(( (n%1000 + 50)/100 )); [ "$d" -ge 10 ] && { u=$((u+1)); d=0; }; [ "$d" -eq 0 ] && printf '%dk' "$u" || printf '%d.%dk' "$u" "$d"
  else printf '%d' "$n"; fi; }

# ---------- panel: plan usage (account-wide, shared-cache, low-CPU) ----------
panel_usage() {
  mkdir -p "$DIR/usage"
  local SID="unknown"
  [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && SID="${BASH_REMATCH[1]}"
  SID="${SID//[^A-Za-z0-9_.-]/_}"
  local OWN="$DIR/usage/$SID.json" om
  om=$(stat -f %m "$OWN" 2>/dev/null || echo 0)
  # Only record when this tick actually carries rate_limits (a real observation),
  # so written_at always means "freshly seen" — never a stale value re-stamped.
  if [[ "$input" == *'"rate_limits"'* ]] && [ $((now - om)) -ge 5 ]; then
    local OLD; OLD=$(jq -c . "$OWN" 2>/dev/null || echo '{}')
    if printf '%s' "$input" | jq --argjson old "$OLD" '{
        session_pct:(.rate_limits.five_hour.used_percentage//$old.session_pct//null),
        session_resets_at:(.rate_limits.five_hour.resets_at//$old.session_resets_at//null),
        weekly_pct:(.rate_limits.seven_day.used_percentage//$old.weekly_pct//null),
        weekly_resets_at:(.rate_limits.seven_day.resets_at//$old.weekly_resets_at//null),
        written_at:(now|floor)}' > "$OWN.tmp.$$" 2>/dev/null; then mv -f "$OWN.tmp.$$" "$OWN"; else rm -f "$OWN.tmp.$$"; fi
  fi
  local C="$DIR/usage-synced" cts=0 SP="" SR="" WP="" WR="" WSTR=""
  [ -r "$C" ] && IFS=$'\t' read -r cts SP SR WP WR WSTR < "$C"; cts=${cts:-0}
  if [ ! -r "$C" ] || [ $((now - cts)) -ge 8 ]; then
    read -r SP SR WP WR < <("$DIR/usage-read.sh" | jq -r '[(.session_pct//""),(.session_resets_at//""),(.weekly_pct//""),(.weekly_resets_at//"")]|@tsv')
    find "$DIR/usage" -name '*.json' -mmin +720 -delete 2>/dev/null
    if [ -n "$WR" ]; then if [ "$WR" -le "$now" ] 2>/dev/null; then WSTR=now; else WSTR=$(date -r "$WR" '+%a %H:%M'); fi; else WSTR=""; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$SP" "$SR" "$WP" "$WR" "$WSTR" > "$C.tmp.$$" && mv -f "$C.tmp.$$" "$C"
  fi
  if [ -n "$SP" ]; then local p rs="" d; p=$(int "$SP")
    if [ -n "$SR" ]; then d=$((SR - now)); if [ $d -le 0 ]; then rs=now; else rs="$((d/3600))h$(((d%3600)/60))m"; fi; fi
    add "$(printf 'USAGE %b%s\033[0m %d%% \033[90m%s\033[0m' "$(colpct $p)" "$(mkbar $p)" "$p" "$rs")" "USAGE $PLAINBAR $p% $rs"
  fi
  if [ -n "$WP" ]; then local p; p=$(int "$WP")
    add "$(printf 'WEEK %b%s\033[0m %d%% \033[90m%s\033[0m' "$(colpct $p)" "$(mkbar $p)" "$p" "$WSTR")" "WEEK $PLAINBAR $p% $WSTR"
  fi
}

# ---------- panel: context window (per session) ----------
panel_context() {
  # Matches Claude's native context counter exactly: the count is total_input_tokens
  # (input + cache reads/writes) — precisely what used_percentage is computed from.
  # Output tokens are NOT part of the context-window "used" figure.
  local M IN S UP; IFS=$'\t' read -r M IN S UP < <(printf '%s' "$input" | jq -r \
    '[.model.display_name//"?", (.context_window.total_input_tokens//-1), (.context_window.context_window_size//200000), (.context_window.used_percentage//-1)] | @tsv')
  [ -z "$IN" ] || [ "$IN" = "-1" ] && return
  [ "$S" -le 0 ] && S=200000
  local p
  if [ -n "$UP" ] && [ "$UP" != "-1" ]; then p=$(int "$UP"); else p=$(( IN * 100 / S )); fi
  [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
  local used sz; used=$(fmtk "$IN"); sz=$(fmtk "$S")
  add "$(printf 'CONTEXT %b%s\033[0m %d%% \033[90m%s/%s\033[0m' "$(colctx $p)" "$(mkbar $p)" "$p" "$used" "$sz")" "CONTEXT $PLAINBAR $p% $used/$sz"
}

# ---------- panel: cost, $ only (per session, API/pay-per-use) ----------
panel_cost() {
  local C; C=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
  local cf; cf=$(printf '$%.2f' "$C")
  add "$(printf 'COST %s' "$cf")" "COST $cf"
}

# ---------- element: active time (how long this session has run; any billing) ----------
panel_active() {
  local D; D=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
  local sec=$((D/1000)) h m t; h=$((sec/3600)); m=$(((sec%3600)/60))
  if [ "$h" -gt 0 ]; then t="${h}h${m}m"; else t="${m}m$((sec%60))s"; fi
  add "$(printf 'active \033[90m%s\033[0m' "$t")" "active $t"
}

# ---------- panel: git + PR (per session, git cached 3s) ----------
panel_git() {
  local DIRP SID PRN PRS; IFS=$'\t' read -r DIRP SID PRN PRS < <(printf '%s' "$input" | jq -r \
    '[.workspace.current_dir//".", .session_id//"x", (.pr.number//""), (.pr.review_state//"")] | @tsv')
  local CG="/tmp/cus-git-$SID" fresh=0
  if [ -f "$CG" ]; then [ $(( now - $(stat -f %m "$CG" 2>/dev/null || echo 0) )) -lt 3 ] && fresh=1; fi
  if [ "$fresh" = 0 ]; then
    if git -C "$DIRP" rev-parse --git-dir >/dev/null 2>&1; then
      printf '%s\t%s\t%s\n' "$(git -C "$DIRP" branch --show-current 2>/dev/null)" \
        "$(git -C "$DIRP" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')" \
        "$(git -C "$DIRP" diff --numstat 2>/dev/null | wc -l | tr -d ' ')" > "$CG"
    else printf '\t\t\n' > "$CG"; fi
  fi
  local BR SG MD; IFS=$'\t' read -r BR SG MD < "$CG"
  [ -z "$BR" ] && [ -z "$PRN" ] && return
  local col="GIT" plain="GIT"
  if [ -n "$BR" ]; then col="$col \033[36m$BR\033[0m"; plain="$plain $BR"; fi
  if [ -n "$SG" ] && [ "$SG" -gt 0 ]; then col="$col \033[32m+$SG\033[0m"; plain="$plain +$SG"; fi
  if [ -n "$MD" ] && [ "$MD" -gt 0 ]; then col="$col \033[33m~$MD\033[0m"; plain="$plain ~$MD"; fi
  if [ -n "$PRN" ]; then col="$col PR#$PRN"; plain="$plain PR#$PRN"; [ -n "$PRS" ] && { col="$col ($PRS)"; plain="$plain ($PRS)"; }; fi
  add "$(printf '%b' "$col")" "$plain"
}

# Billing-aware: a Pro/Max subscription exposes rate_limits and is bounded by usage
# limits (not $); API/pay-per-use has no rate_limits and is billed by $ cost. Show
# only what's relevant to the current chat's billing mode.
case "$input" in *'"rate_limits"'*) SUB=1;; *) SUB=0;; esac

[ "$PANEL_USAGE" = on ] && [ "$SUB" = 1 ] && panel_usage     # usage limits: subscription only
[ "$PANEL_CONTEXT" = on ] && panel_context
[ "$PANEL_COST" = on ] && [ "$SUB" = 0 ] && panel_cost       # $ cost: API/pay-per-use only
[ "$PANEL_ACTIVE" = on ] && panel_active                     # session active-time: any billing
[ "$PANEL_GIT" = on ] && panel_git

n=${#SEGS[@]}; [ "$n" -eq 0 ] && exit 0

# compose
tot=0; for p in "${PLAINS[@]}"; do tot=$((tot + ${#p})); done; tot=$((tot + 3*(n-1)))
cols=${COLUMNS:-80}
if [ "$LAYOUT" = stack ] || { [ "$LAYOUT" = auto ] && [ "$tot" -gt $((cols-1)) ]; }; then
  for s in "${SEGS[@]}"; do printf '%s\n' "$s"; done
else
  out="${SEGS[0]}"; i=1
  while [ "$i" -lt "$n" ]; do out="$out   ${SEGS[$i]}"; i=$((i+1)); done
  printf '%s\n' "$out"
fi
