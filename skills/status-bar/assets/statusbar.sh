#!/bin/bash
# Status Bar — status-bar renderer.
# Reads the config, renders ONLY the enabled panels as modular segments, then
# composes them into one row (wrapping to stacked rows when narrow). Designed to
# be cheap: the account-wide usage panel uses a shared cache (one session
# computes, the rest read); the other panels read this session's JSON directly.

input=$(cat)
DIR="$HOME/.claude/status-bar"
[ -r "$DIR/config" ] && . "$DIR/config"
: "${PANEL_USAGE:=on}"; : "${PANEL_CONTEXT:=on}"; : "${PANEL_COST:=off}"; : "${PANEL_ACTIVE:=on}"; : "${PANEL_GIT:=off}"; : "${PANEL_MENU:=on}"; : "${LAYOUT:=auto}"

now=$(date +%s)
FILL=$(printf '\342\226\223'); EMP=$(printf '\342\226\221')
PLAINBAR="##########"        # ASCII twin of a 10-cell bar, for width math
SEGS=(); PLAINS=()

# The account-wide usage SSOT: ONE shared file, written and read by every window, so the
# 5h + weekly numbers are identical in all terminals (context/cost/git stay per-session).
USAGE_SSOT="$DIR/usage-ssot"

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

# ---------- panel: plan usage (ONE account-wide SSOT, synced across every window) ----------
# The 5h session + weekly limits are ACCOUNT-wide: at any instant there is one true value,
# the same for every terminal. So all windows share ONE file ($USAGE_SSOT), merge their own
# observation into it, and display it — switch windows and the number is identical, and a
# window that is behind still shows what another window just published. Each observation is
# the rate_limits Claude Code put in this render (the server's figure, the same /usage shows).
#
# "FRESHEST GENUINE READING WINS." The earlier all-time-max rule was wrong: the weekly figure
# genuinely DECREASES (rolling 7-day window / server recompute) at a constant resets_at, and an
# idle terminal re-emits its last high reading on EVERY render — so a max accumulator froze at an
# old peak for up to a week. The fix has two parts:
#   1. Per metric the SSOT carries percent + resets_at + an observed-at wall stamp. A reading wins
#      when its resets_at is NEWER, or (same window) it was observed at-or-after the stored stamp.
#      That lets a later genuine reading move the value DOWN as well as up.
#   2. Each window remembers its own last raw reading (a tiny per-session file under $DIR keyed by
#      session_id). A reading that DIFFERS from this window's last-seen (or is its first ever) is a
#      genuine new server observation and may write; a byte-identical re-emit is an idle tick and
#      writes NOTHING — so a frozen window can never refresh a stale peak.
# Display still reads the shared SSOT, so every window shows one account-wide value. No jq, no
# external process on this path; atomic tmp+mv writes; per-session state is pruned on write.
panel_usage() {
  local SP="" SR="" SOA="" WP="" WR="" WOA=""
  # Read the SSOT defensively. The 6 fields (SP|SR|SOA|WP|WR|WOA) are '|'-delimited:
  # '|' is NOT IFS-whitespace, so `read` keeps empty fields in place positionally. (Tab
  # would collapse leading/middle empties — a weekly-only line ||​|WP|WR|WOA would slide
  # the weekly percent into the SESSION slot and fabricate "SESSION 40%".)
  # Then validate SEMANTICS, not just presence: percents (_f1/_f4) must be 0-100 and
  # observed-at stamps (_f3/_f6) must be 10+-digit epochs; any field may be empty. A legacy
  # tab 4-field file (SP\tSR\tWP\tWR) contains no '|', so it lands wholly in _f1 (non-numeric)
  # and is rejected. Anything off-format -> treat the whole line as empty rather than render garbage.
  if [ -r "$USAGE_SSOT" ]; then
    local _f1 _f2 _f3 _f4 _f5 _f6 _f7
    IFS='|' read -r _f1 _f2 _f3 _f4 _f5 _f6 _f7 < "$USAGE_SSOT"
    if [ -z "$_f7" ] \
       && { [ -z "$_f1" ] || { [[ "$_f1" =~ ^[0-9.]+$ ]] && [ "$(int "$_f1")" -le 100 ]; }; } \
       && { [ -z "$_f4" ] || { [[ "$_f4" =~ ^[0-9.]+$ ]] && [ "$(int "$_f4")" -le 100 ]; }; } \
       && { [ -z "$_f3" ] || [[ "$_f3" =~ ^[0-9]{10,}$ ]]; } \
       && { [ -z "$_f6" ] || [[ "$_f6" =~ ^[0-9]{10,}$ ]]; } \
       && { [ -z "$_f2" ] || [[ "$_f2" =~ ^[0-9]+$ ]]; } \
       && { [ -z "$_f5" ] || [[ "$_f5" =~ ^[0-9]+$ ]]; }; then
      SP="$_f1"; SR="$_f2"; SOA="$_f3"; WP="$_f4"; WR="$_f5"; WOA="$_f6"
    fi
  fi

  if [[ "$input" == *'"rate_limits"'* ]]; then
    # my own observation from this render — five_hour = 5h session, seven_day = weekly.
    # Each field read independently (robust to key order / added fields); floats are fine.
    local oSP="" oSR="" oWP="" oWR="" changed=0
    [[ "$input" =~ \"five_hour\"[^}]*\"used_percentage\"[[:space:]]*:[[:space:]]*([0-9.]+) ]] && oSP="${BASH_REMATCH[1]}"
    [[ "$input" =~ \"five_hour\"[^}]*\"resets_at\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && oSR="${BASH_REMATCH[1]}"
    [[ "$input" =~ \"seven_day\"[^}]*\"used_percentage\"[[:space:]]*:[[:space:]]*([0-9.]+) ]] && oWP="${BASH_REMATCH[1]}"
    [[ "$input" =~ \"seven_day\"[^}]*\"resets_at\"[[:space:]]*:[[:space:]]*([0-9]+) ]] && oWR="${BASH_REMATCH[1]}"

    # Is this a GENUINE fresh observation for this window, or a byte-identical idle re-emit?
    # Compare the raw reading against this window's last-seen, stored per session under $DIR.
    local sid="x"
    [[ "$input" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] && sid="${BASH_REMATCH[1]}"
    local SEEN="$DIR/usage-seen-$sid" cur="$oSP|$oSR|$oWP|$oWR" prev="" genuine=1
    [ -r "$SEEN" ] && IFS= read -r prev < "$SEEN"
    [ "$cur" = "$prev" ] && genuine=0
    if [ "$genuine" = 1 ]; then
      printf '%s\n' "$cur" > "$SEEN.tmp.$$" && mv -f "$SEEN.tmp.$$" "$SEEN"
      # prune stale per-session state (>1 day old) so files don't accumulate
      find "$DIR" -maxdepth 1 -name 'usage-seen-*' -type f -mtime +1 -delete 2>/dev/null
      # freshest-genuine-wins: newer window (resets_at advanced) always wins; within the same
      # window the reading observed at-or-after the stored stamp wins — letting values fall.
      # ("Freshest" = most-recently-RENDERED genuine reading; the server's observation time isn't
      # in the payload. So a window's first post-idle reading can briefly win even if stale — but it
      # self-heals on the next changed reading from any window, unlike the old permanent max-ratchet.)
      if [ -n "$oSR" ] && { [ -z "$SR" ] || [ "$oSR" -gt "$SR" ] || { [ "$oSR" -eq "$SR" ] && [ "$now" -ge "${SOA:-0}" ]; }; }; then
        SP="$oSP"; SR="$oSR"; SOA="$now"; changed=1
      fi
      if [ -n "$oWR" ] && { [ -z "$WR" ] || [ "$oWR" -gt "$WR" ] || { [ "$oWR" -eq "$WR" ] && [ "$now" -ge "${WOA:-0}" ]; }; }; then
        WP="$oWP"; WR="$oWR"; WOA="$now"; changed=1
      fi
      # publish the advanced SSOT so every other window sees it (atomic). '|'-delimited so
      # empty leading/middle fields (e.g. a weekly-only reading) survive the read-back intact.
      [ "$changed" = 1 ] && { printf '%s|%s|%s|%s|%s|%s\n' "$SP" "$SR" "$SOA" "$WP" "$WR" "$WOA" > "$USAGE_SSOT.tmp.$$" && mv -f "$USAGE_SSOT.tmp.$$" "$USAGE_SSOT"; }
    fi
  fi

  if [ -n "$SP" ]; then local p rs="" d; p=$(int "$SP"); [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
    if [ -n "$SR" ]; then d=$((SR - now)); if [ $d -le 0 ]; then rs=now; else rs="$((d/3600))h$(((d%3600)/60))m"; fi; fi
    add "$(printf 'SESSION %b%s\033[0m %d%% \033[90m%s\033[0m' "$(colpct $p)" "$(mkbar $p)" "$p" "$rs")" "SESSION $PLAINBAR $p% $rs"
  fi
  if [ -n "$WP" ]; then local p WSTR=""; p=$(int "$WP"); [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
    if [ -n "$WR" ]; then if [ "$WR" -le "$now" ] 2>/dev/null; then WSTR=now; else WSTR=$(date -r "$WR" '+%a %H:%M'); fi; fi
    add "$(printf 'WEEK %b%s\033[0m %d%% \033[90m%s\033[0m' "$(colpct $p)" "$(mkbar $p)" "$p" "$WSTR")" "WEEK $PLAINBAR $p% $WSTR"
  fi
}

# ---------- panel: context window (per session) ----------
panel_context() {
  # Percentage only — Claude's own used_percentage (matches /context). No token
  # count shown (the count had a moving definition; the % is unambiguous).
  # Scalars come from the one shared jq pass (extract_json), not a per-panel fork.
  local IN="$J_CTX_IN" S="$J_CTX_SIZE" UP="$J_CTX_UP"
  [ -z "$IN" ] || [ "$IN" = "-1" ] && return
  [ "$S" -le 0 ] && S=200000
  local p
  if [ -n "$UP" ] && [ "$UP" != "-1" ]; then p=$(int "$UP"); else p=$(( IN * 100 / S )); fi
  [ "$p" -gt 100 ] && p=100; [ "$p" -lt 0 ] && p=0
  add "$(printf 'CONTEXT %b%s\033[0m %d%%' "$(colctx $p)" "$(mkbar $p)" "$p")" "CONTEXT $PLAINBAR $p%"
}

# ---------- panel: cost, $ only (per session, API/pay-per-use) ----------
panel_cost() {
  local cf; cf=$(printf '$%.2f' "$J_COST")
  add "$(printf 'COST %s' "$cf")" "COST $cf"
}

# ---------- element: active time (how long this session has run; any billing) ----------
panel_active() {
  local D="$J_DUR"
  local sec=$((D/1000)) h m t; h=$((sec/3600)); m=$(((sec%3600)/60))
  if [ "$h" -gt 0 ]; then t="${h}h${m}m"; else t="${m}m$((sec%60))s"; fi
  add "$(printf 'active \033[90m%s\033[0m' "$t")" "active $t"
}

# ---------- panel: git + PR (per session, git cached 15s) ----------
panel_git() {
  local DIRP="$J_DIR" SID="$J_SID" PRN="$J_PRN" PRS="$J_PRS"
  local CG="/tmp/sb-git-$SID" fresh=0
  # git is the heaviest panel (3 subprocesses + repo I/O). Cache 15s: at refreshInterval=3 it then
  # runs ~once per 15s instead of nearly every render. Branch/diff rarely change second-to-second.
  if [ -f "$CG" ]; then [ $(( now - $(stat -f %m "$CG" 2>/dev/null || echo 0) )) -lt 15 ] && fresh=1; fi
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

# ---------- panel: menu hint (how to control the bar — via the chat) ----------
# The bar has no clickable/keyboard menu (the status line is display-only). The
# control surface is the chat: a CLAUDE.md block (added at install) lets any
# session toggle panels/settings on request. This line advertises that.
panel_menu() {
  local t="ask chat to toggle panels / settings"
  add "$(printf '\033[90mMENU %s\033[0m' "$t")" "MENU $t"
}

# ---------- one shared jq pass (power: 3 jq forks -> 1 per render) ----------
# The non-usage panels (context, cost, active, git) used to each fork their own jq. This pulls
# every scalar they need in ONE jq call into globals; each panel then reads vars (no fork).
# Only the last two fields (PR number/state) can be empty, and they are trailing, so the @tsv
# round-trips cleanly. usage parses with bash regex and does not use this. Run only when a
# jq-consuming panel is actually enabled, so the all-off case still forks zero jq.
extract_json() {
  IFS=$'\t' read -r J_MODEL J_CTX_IN J_CTX_SIZE J_CTX_UP J_COST J_DUR J_DIR J_SID J_PRN J_PRS \
    < <(printf '%s' "$input" | jq -r '[.model.display_name//"?", (.context_window.total_input_tokens//-1), (.context_window.context_window_size//200000), (.context_window.used_percentage//-1), (.cost.total_cost_usd//0), (.cost.total_duration_ms//0), (.workspace.current_dir//"."), (.session_id//"x"), (.pr.number//""), (.pr.review_state//"")] | @tsv')
}

# Billing-aware: a Pro/Max subscription exposes rate_limits and is bounded by usage
# limits (not $); API/pay-per-use has no rate_limits and is billed by $ cost. Show
# only what's relevant to the current chat's billing mode.
#
# STICKY across the machine: not every render carries rate_limits (an idle tick omits it),
# but billing mode doesn't change. A subscription is known the moment ANY window has written
# the usage SSOT, so idle / cold-start renders keep showing usage instead of flipping to the
# cost panel. An API-only machine never sees rate_limits and never creates the SSOT → SUB=0.
if [[ "$input" == *'"rate_limits"'* ]] || [ -r "$USAGE_SSOT" ]; then SUB=1; else SUB=0; fi

# do the single jq pass once, only if a jq-consuming panel will actually render
need_json=0
[ "$PANEL_CONTEXT" = on ] && need_json=1
[ "$PANEL_ACTIVE" = on ] && need_json=1
[ "$PANEL_GIT" = on ] && need_json=1
[ "$PANEL_COST" = on ] && [ "$SUB" = 0 ] && need_json=1
[ "$need_json" = 1 ] && extract_json

[ "$PANEL_USAGE" = on ] && [ "$SUB" = 1 ] && panel_usage     # usage limits: subscription only
[ "$PANEL_CONTEXT" = on ] && panel_context
[ "$PANEL_COST" = on ] && [ "$SUB" = 0 ] && panel_cost       # $ cost: API/pay-per-use only
[ "$PANEL_ACTIVE" = on ] && panel_active                     # session active-time: any billing
[ "$PANEL_GIT" = on ] && panel_git
[ "$PANEL_MENU" = on ] && panel_menu                         # control-hint line: any billing

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
