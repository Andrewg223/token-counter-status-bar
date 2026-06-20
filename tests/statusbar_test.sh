#!/bin/bash
# ============================================================================
# Status Bar — behavioural test harness  (the SPEC, owned by the orchestrator)
#
# Black-box: each test spins up an ISOLATED $HOME containing
# .claude/status-bar/{config, statusbar.sh}, feeds crafted statusline JSON on
# stdin exactly as Claude Code does, and asserts on the ANSI-stripped output.
# Nothing here touches the real ~/.claude. Implementation-agnostic: we assert
# what the user SEES, never internal file formats — the developer is free to
# choose the internals as long as the rendered behaviour is correct.
#
# Script under test: $SB_SCRIPT  (default: repo assets/statusbar.sh)
# Run:   bash tests/statusbar_test.sh
# Exit:  0 = all pass, 1 = one or more fail.  Output is PASS:/FAIL: lines.
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SB_SCRIPT="${SB_SCRIPT:-$HERE/../skills/status-bar/assets/statusbar.sh}"
NOW="$(date +%s)"

if [ ! -r "$SB_SCRIPT" ]; then echo "FAIL: script under test not found: $SB_SCRIPT"; exit 1; fi
command -v jq >/dev/null || { echo "FAIL: jq not installed"; exit 1; }
command -v perl >/dev/null || { echo "FAIL: perl not installed"; exit 1; }

PASS=0; FAIL=0; FAILED_NAMES=()

# ---- helpers ---------------------------------------------------------------
strip() { perl -pe 's/\e\[[0-9;]*m//g'; }   # remove ANSI colour

mkhome() {            # $1 = config body (KEY=val lines).  echoes a fresh HOME
  local h; h="$(mktemp -d)"; mkdir -p "$h/.claude/status-bar"
  cp "$SB_SCRIPT" "$h/.claude/status-bar/statusbar.sh"
  printf '%s\n' "$1" > "$h/.claude/status-bar/config"
  printf '%s' "$h"
}

render() {            # $1 = HOME, $2 = payload json   -> stripped single-row output
  HOME="$1" COLUMNS=900 bash "$1/.claude/status-bar/statusbar.sh" <<<"$2" | strip | tr '\n' '|'
}

# mkpayload: build a statusline JSON.  Args via env-style key=val on the line:
#   sid, m5(5h %), r5(5h resets_at), m7(7d %), r7(7d resets_at),
#   ctx(context %), dur(duration ms), rl(1=include rate_limits,0=omit)
# Any of m5/m7 left empty omits that sub-field; rl=0 omits the whole block.
mkpayload() {
  local sid="$1" m5="$2" r5="$3" m7="$4" r7="$5" ctx="$6" dur="$7" rl="$8"
  local rlblock=""
  if [ "$rl" = 1 ]; then
    rlblock=',"rate_limits":{"five_hour":{'
    [ -n "$m5" ] && rlblock+="\"used_percentage\":$m5"
    [ -n "$m5" ] && [ -n "$r5" ] && rlblock+=","
    [ -n "$r5" ] && rlblock+="\"resets_at\":$r5"
    rlblock+='},"seven_day":{'
    [ -n "$m7" ] && rlblock+="\"used_percentage\":$m7"
    [ -n "$m7" ] && [ -n "$r7" ] && rlblock+=","
    [ -n "$r7" ] && rlblock+="\"resets_at\":$r7"
    rlblock+='}}'
  fi
  printf '{"session_id":"%s","transcript_path":"/tmp/x.jsonl","cwd":"/tmp","model":{"id":"claude-opus-4-8[1m]","display_name":"Opus 4.8 (1M context)"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp","added_dirs":[]},"version":"2.1.183","output_style":{"name":"default"},"cost":{"total_cost_usd":1.5,"total_duration_ms":%s,"total_lines_added":1,"total_lines_removed":0},"context_window":{"total_input_tokens":84520,"context_window_size":1000000,"used_percentage":%s,"remaining_percentage":92},"exceeds_200k_tokens":false%s}' \
    "$sid" "$dur" "$ctx" "$rlblock"
}

USAGE_CFG='PANEL_USAGE=on
PANEL_CONTEXT=on
PANEL_COST=on
PANEL_ACTIVE=on
PANEL_GIT=off
PANEL_MENU=off
LAYOUT=row'

ok()   { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf 'FAIL: %s\n     %s\n' "$1" "$2"; }

# assert output (arg3) contains (arg2);  name=arg1
has()  { case "$3" in *"$2"*) ok "$1";; *) bad "$1" "expected to contain [$2] but got: $3";; esac; }
hasnt(){ case "$3" in *"$2"*) bad "$1" "expected NOT to contain [$2] but got: $3";; *) ok "$1";; esac; }

R5=$((NOW + 9000))      # 5h window resets in 2h30m
R7=$((NOW + 360000))    # weekly resets in ~4.2d

# ===========================================================================
# T1  Fresh install, real-ish render: weekly 1% shown correctly
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)")
has  "T1a session pct shown"  "SESSION" "$OUT"
has  "T1b weekly pct shown"   "WEEK"    "$OUT"
has  "T1c weekly is 1%"       "1%"      "$OUT"
hasnt "T1d weekly not stuck-high (no 40%)" "40%" "$OUT"

# ===========================================================================
# T2  REGRESSION: a stale-high value already published must NOT stick when a
#     fresh lower reading arrives.  This is the user's exact bug.
#     Window A publishes 40% (it was true earlier), then the SAME window
#     observes the real drop to 1%.  Bar must show 1%, never 40%.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload S1 30 "$R5" 40 "$R7" 8 60000 1)" >/dev/null   # publishes 40
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)")          # genuine drop to 1
has   "T2a weekly now reads 1%"          "1%"  "$OUT"
hasnt "T2b weekly no longer stuck at 40" "40%" "$OUT"

# ===========================================================================
# T3  Monotonic 5h climb in one window: 2 -> 4 -> 5  shows the latest (5).
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload S1 2 "$R5" 0 "$R7" 8 60000 1)" >/dev/null
render "$H" "$(mkpayload S1 4 "$R5" 1 "$R7" 8 60000 1)" >/dev/null
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)")
has  "T3 5h shows latest 5%" "SESSION" "$OUT"
case "$OUT" in *"SESSION"*"5%"*) ok "T3b session is 5%";; *) bad "T3b session is 5%" "got: $OUT";; esac

# ===========================================================================
# T4  Frozen-high idle window must NOT pollute. Window A is stuck re-emitting
#     40% (idle, fetched during the 40 era). Window B is active and observes
#     the real value 1%. After B's fresh reading, A keeps re-emitting 40 on
#     every tick — the bar must stay at 1%, not snap back to 40%.
#     (Requires recency/change awareness, not all-time max.)
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload Aidle 5 "$R5" 40 "$R7" 8 60000 1)" >/dev/null  # A first-seen: 40
render "$H" "$(mkpayload Bact  5 "$R5" 40 "$R7" 8 60000 1)" >/dev/null  # B first-seen: 40
render "$H" "$(mkpayload Bact  5 "$R5" 1  "$R7" 8 60000 1)" >/dev/null  # B observes drop -> 1 (fresh)
render "$H" "$(mkpayload Aidle 5 "$R5" 40 "$R7" 8 60000 1)" >/dev/null  # A re-emits stale 40 (no change)
OUT=$(render "$H" "$(mkpayload Aidle 5 "$R5" 40 "$R7" 8 60000 1)")      # A re-emits again
has   "T4a weekly stays at fresh 1%"        "1%"  "$OUT"
hasnt "T4b stale 40 from idle window gone"  "40%" "$OUT"

# ===========================================================================
# T5  Cross-window consistency: an idle window B (frozen low, re-emitting 2%)
#     should DISPLAY the account-wide freshest value published by active A (5%),
#     not its own stale 2%.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload Bidle 2 "$R5" 0 "$R7" 8 60000 1)" >/dev/null   # B first-seen 2 (publishes 2)
render "$H" "$(mkpayload Aact  2 "$R5" 0 "$R7" 8 60000 1)" >/dev/null   # A first-seen 2
render "$H" "$(mkpayload Aact  5 "$R5" 1 "$R7" 8 60000 1)" >/dev/null   # A climbs to 5 (fresh)
OUT=$(render "$H" "$(mkpayload Bidle 2 "$R5" 0 "$R7" 8 60000 1)")       # B renders, still frozen at 2
case "$OUT" in *"SESSION"*"5%"*) ok "T5 idle window shows account freshest 5%";; *) bad "T5 idle window shows account freshest 5%" "got: $OUT";; esac

# ===========================================================================
# T6  Weekly window ROLLOVER: resets_at advances and percent resets to ~0.
#     New window (larger resets_at) must win immediately even from a high prior.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload S1 5 "$R5" 80 "$R7" 8 60000 1)" >/dev/null     # last week 80%
NEWR7=$((R7 + 604800))
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 2 "$NEWR7" 8 60000 1)")       # new week, 2%
has   "T6a new week shows 2%"        "2%"  "$OUT"
hasnt "T6b old 80% gone on rollover" "80%" "$OUT"

# ===========================================================================
# T7  Context panel reads Claude's own used_percentage (8% from the real fixture)
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(cat "$HERE/fixtures/real-render.json")")
has  "T7a context panel present" "CONTEXT" "$OUT"
case "$OUT" in *"CONTEXT"*"8%"*) ok "T7b context is 8%";; *) bad "T7b context is 8%" "got: $OUT";; esac

# ===========================================================================
# T8  Active time formats duration: 428982 ms -> 7m8s
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 428982 1)")
has  "T8 active time 7m8s" "active 7m8s" "$OUT"

# ===========================================================================
# T9  Billing sticky: once usage has been seen, a later render WITHOUT
#     rate_limits still shows usage (from the cache), not the cost panel.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)" >/dev/null      # establishes subscription
OUT=$(render "$H" "$(mkpayload S1 "" "" "" "" 8 60000 0)")              # no rate_limits this tick
has   "T9a usage still shown (sticky)" "SESSION" "$OUT"
hasnt "T9b cost panel not shown for subscription" "COST" "$OUT"

# ===========================================================================
# T10  API-only machine: rate_limits NEVER appears, no cache -> show COST, no usage
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 "" "" "" "" 8 60000 0)")
has   "T10a cost panel shown"      "COST"    "$OUT"
hasnt "T10b no session usage"      "SESSION" "$OUT"
hasnt "T10c no weekly usage"       "WEEK"    "$OUT"

# ===========================================================================
# T11  Malformed rate_limits: resets_at present but used_percentage MISSING.
#     Must not blank the panel into a garbage/empty bar or crash. Either the
#     panel is omitted cleanly or the prior good value is retained — never an
#     empty/percent-less SESSION segment.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)" >/dev/null      # good prior value
OUT=$(render "$H" "$(mkpayload S1 "" "$R5" "" "$R7" 8 60000 1)")        # pct missing this tick
# if SESSION appears it must carry a % (not a dangling label); never shows blank "SESSION  %"
case "$OUT" in
  *"SESSION"*"%"*) ok "T11 session never rendered without a percent";;
  *"SESSION"*)     bad "T11 session never rendered without a percent" "got dangling SESSION: $OUT";;
  *)               ok "T11 session never rendered without a percent";;
esac

# ===========================================================================
# T12  Reset countdown formatting: future 5h -> "Xh Ym" style; past -> "now"
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 5 "$((NOW+9000))" 1 "$R7" 8 60000 1)")
case "$OUT" in *"2h"*"m"*) ok "T12a future reset shows hXmYm countdown";; *) bad "T12a future reset shows countdown" "got: $OUT";; esac
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 5 "$((NOW-100))" 1 "$R7" 8 60000 1)")
has  "T12b past reset shows 'now'" "now" "$OUT"

# ===========================================================================
# T13  Bars never exceed 10 cells / never go negative-width. Feed 5h=150, 7d=-5.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
OUT=$(render "$H" "$(mkpayload S1 150 "$R5" 0 "$R7" 8 60000 1)")
# the filled bar uses U+2593; count must be <=10. Just assert it renders & shows 100%.
has  "T13 over-100 clamps to 100%" "100%" "$OUT"

# ===========================================================================
# T14  LEGACY ssot: a pre-existing OLD 4-field file (SP\tSR\tWP\tWR) must be
#      treated as empty, never misread into a fabricated panel. With no fresh
#      rate_limits this tick, the bar must show NO usage panels and NO "100%"
#      garbage. (Reproduces the real on-disk file that broke the first fix.)
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
printf '5\t1781959800\t40\t1782475200\n' > "$H/.claude/status-bar/usage-ssot"   # old 4-field format
OUT=$(render "$H" "$(mkpayload S1 "" "" "" "" 8 60000 0)")                        # idle render, no rate_limits
hasnt "T14a no fabricated 100% from legacy ssot" "100%"   "$OUT"
hasnt "T14b no fabricated WEEK from legacy ssot"  "WEEK"   "$OUT"
hasnt "T14c no fabricated SESSION from legacy ssot" "SESSION" "$OUT"

# ===========================================================================
# T15  LEGACY ssot then a GENUINE reading: the old file is discarded and the
#      real values (5h=5, 7d=1) take over cleanly — no leakage of the old 40.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
printf '5\t1781959800\t40\t1782475200\n' > "$H/.claude/status-bar/usage-ssot"
OUT=$(render "$H" "$(mkpayload S1 5 "$R5" 1 "$R7" 8 60000 1)")
has   "T15a weekly shows the genuine 1%"   "1%"   "$OUT"
hasnt "T15b old 40 does not leak"          "40%"  "$OUT"
hasnt "T15c no fabricated 100%"            "100%" "$OUT"

# ===========================================================================
# T16  Garbage / malformed ssot line must be treated as empty, never crash,
#      never render a usage panel from it.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
printf 'garbage\tnot\tnumbers\there\n' > "$H/.claude/status-bar/usage-ssot"
OUT=$(render "$H" "$(mkpayload S1 "" "" "" "" 8 60000 0)")
hasnt "T16a malformed ssot yields no SESSION" "SESSION" "$OUT"
hasnt "T16b malformed ssot yields no WEEK"    "WEEK"    "$OUT"

# ===========================================================================
# T17  WEEKLY-ONLY observation: a render carrying seven_day but NO five_hour
#      makes the script WRITE an ssot line with empty LEADING fields. A second
#      window must read it back as WEEK (not a fabricated SESSION). Guards the
#      read/write asymmetry (tab IFS-whitespace would collapse the leading gap).
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload WK "" "" 40 "$R7" 8 60000 1)" >/dev/null    # five_hour absent, seven_day=40
OUT=$(render "$H" "$(mkpayload OTHER "" "" "" "" 8 60000 0)")        # another window, idle, reads ssot
has   "T17a weekly-only renders WEEK"        "WEEK"    "$OUT"
hasnt "T17b weekly-only does NOT fabricate SESSION" "SESSION" "$OUT"
case "$OUT" in *"WEEK"*"40%"*) ok "T17c weekly-only shows 40% in WEEK slot";; *) bad "T17c weekly-only shows 40% in WEEK slot" "got: $OUT";; esac

# ===========================================================================
# T18  SESSION-ONLY observation (five_hour but no seven_day): symmetric guard —
#      a second window reads it back as SESSION, no fabricated WEEK.
# ===========================================================================
H=$(mkhome "$USAGE_CFG")
render "$H" "$(mkpayload SES 5 "$R5" "" "" 8 60000 1)" >/dev/null
OUT=$(render "$H" "$(mkpayload OTHER "" "" "" "" 8 60000 0)")
has   "T18a session-only renders SESSION" "SESSION" "$OUT"
hasnt "T18b session-only does NOT fabricate WEEK" "WEEK" "$OUT"
case "$OUT" in *"SESSION"*"5%"*) ok "T18c session-only shows 5% in SESSION slot";; *) bad "T18c session-only shows 5% in SESSION slot" "got: $OUT";; esac

# ---- summary ---------------------------------------------------------------
echo "----------------------------------------------------------------------"
echo "TOTAL: $((PASS+FAIL))   PASS: $PASS   FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'FAILED: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
echo "ALL GREEN"
exit 0
