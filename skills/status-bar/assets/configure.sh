#!/bin/bash
# Status Bar — visual configurator (the in-terminal app).
# Toggle status-bar panels and features, pick a layout, see a live preview, save.
# Keys:  up/down (or k/j) move   space toggle/cycle   s save   q quit
#
# Run it directly in your terminal:  sb    (alias installed by install.sh)
# It writes ~/.claude/status-bar/config and syncs settings.json.

DIR="$HOME/.claude/status-bar"
CFG="$DIR/config"
mkdir -p "$DIR"

# defaults, then load current config
PANEL_USAGE=on; PANEL_CONTEXT=on; PANEL_COST=off; PANEL_ACTIVE=on; PANEL_GIT=off; LAYOUT=auto
NOTIFIER=off; SUBAGENT=off; SAFEBASH=off
[ -r "$CFG" ] && . "$CFG"

ROWS=(usage context cost active git layout notifier subagent safebash)
LABEL_usage="Plan usage";   DESC_usage="5h session + weekly (All Models) limits"
LABEL_context="Context";    DESC_context="context-window fill for this session"
LABEL_cost="Cost";          DESC_cost="session cost (\$) — API billing only"
LABEL_active="Active time"; DESC_active="how long this session has run"
LABEL_git="Git";            DESC_git="branch, staged/modified, open PR"
LABEL_layout="Layout";      DESC_layout="auto = one row, wraps when narrow"
LABEL_notifier="Notifications"; DESC_notifier="desktop ping on done / needs-input (macOS)"
LABEL_subagent="Subagent rows"; DESC_subagent="custom rows in the subagent panel"
LABEL_safebash="Auto-allow Bash"; DESC_safebash="stop prompting for read-only commands"

cur=0
FILL=$(printf '\342\226\223'); EMP=$(printf '\342\226\221')
BOLD=$'\033[1m'; DIM=$'\033[90m'; INV=$'\033[7m'; RST=$'\033[0m'
GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'

cleanup() { printf '\033[?25h\033[?1049l'; }    # show cursor, leave alt screen
trap cleanup EXIT
printf '\033[?1049h\033[?25l'                    # alt screen, hide cursor

state() { case "$1" in usage) echo "$PANEL_USAGE";; context) echo "$PANEL_CONTEXT";; cost) echo "$PANEL_COST";; active) echo "$PANEL_ACTIVE";; git) echo "$PANEL_GIT";; notifier) echo "$NOTIFIER";; subagent) echo "$SUBAGENT";; safebash) echo "$SAFEBASH";; esac; }

bar() { local p=$1 f=$((p/10)) e i b=""; e=$((10-f)); i=0
  while [ $i -lt $f ]; do b+="$FILL"; i=$((i+1)); done
  i=0; while [ $i -lt $e ]; do b+="$EMP"; i=$((i+1)); done; printf '%s' "$b"; }
col() { local p=$1; if [ $p -ge 90 ]; then printf '\033[31m'; elif [ $p -ge 70 ]; then printf '%s' "$YEL"; else printf '%s' "$GRN"; fi; }

# sample segments for the live preview (illustrative numbers)
preview_line() {
  local segs=()
  [ "$PANEL_USAGE" = on ]   && segs+=("SESSION $(col 47)$(bar 47)$RST 47% ${DIM}2h13m$RST" "WEEK $(col 24)$(bar 24)$RST 24% ${DIM}Fri 13:00$RST")
  [ "$PANEL_CONTEXT" = on ] && segs+=("CONTEXT ${CYN}$(bar 32)$RST 32%")
  [ "$PANEL_COST" = on ]    && segs+=("COST \$0.42")
  [ "$PANEL_ACTIVE" = on ]  && segs+=("active ${DIM}16h10m$RST")
  [ "$PANEL_GIT" = on ]     && segs+=("GIT ${CYN}main$RST ${GRN}+2$RST ${YEL}~5$RST")
  [ ${#segs[@]} -eq 0 ] && { printf '%s(no panels enabled)%s' "$DIM" "$RST"; return; }
  if [ "$LAYOUT" = stack ]; then
    local s; for s in "${segs[@]}"; do printf '  %s\n' "$s"; done
  else
    local out="${segs[0]}" i=1; while [ $i -lt ${#segs[@]} ]; do out="$out   ${segs[$i]}"; i=$((i+1)); done
    printf '  %s\n' "$out"
  fi
}

draw() {
  printf '\033[H\033[2J'
  printf '%s Status Bar %s  %sconfigure your terminal status bar%s\n\n' "$INV$BOLD" "$RST" "$DIM" "$RST"
  local i name lbl desc val mark
  for i in "${!ROWS[@]}"; do
    name="${ROWS[$i]}"; eval "lbl=\$LABEL_$name; desc=\$DESC_$name"
    if [ "$name" = layout ]; then mark="[ $LAYOUT ]"
    else val=$(state "$name"); if [ "$val" = on ]; then mark="${GRN}[x]$RST"; else mark="${DIM}[ ]$RST"; fi; fi
    if [ "$i" -eq "$cur" ]; then printf ' %s>%s %b  %-12s %s%s%s\n' "$BOLD" "$RST" "$mark" "$lbl" "$DIM" "$desc" "$RST"
    else printf '   %b  %-12s %s%s%s\n' "$mark" "$lbl" "$DIM" "$desc" "$RST"; fi
  done
  printf '\n %sPreview%s\n' "$BOLD" "$RST"
  preview_line
  printf '\n %sup/down%s move   %sspace%s toggle / cycle layout   %ss%s save   %sesc/q%s exit\n' "$DIM" "$RST" "$DIM" "$RST" "$DIM" "$RST" "$DIM" "$RST"
  [ -n "$MSG" ] && printf '\n %s%s%s\n' "$GRN" "$MSG" "$RST"
}

toggle() {
  local name="${ROWS[$cur]}"
  case "$name" in
    usage)    [ "$PANEL_USAGE" = on ] && PANEL_USAGE=off || PANEL_USAGE=on ;;
    context)  [ "$PANEL_CONTEXT" = on ] && PANEL_CONTEXT=off || PANEL_CONTEXT=on ;;
    cost)     [ "$PANEL_COST" = on ] && PANEL_COST=off || PANEL_COST=on ;;
    active)   [ "$PANEL_ACTIVE" = on ] && PANEL_ACTIVE=off || PANEL_ACTIVE=on ;;
    git)      [ "$PANEL_GIT" = on ] && PANEL_GIT=off || PANEL_GIT=on ;;
    notifier) [ "$NOTIFIER" = on ] && NOTIFIER=off || NOTIFIER=on ;;
    subagent) [ "$SUBAGENT" = on ] && SUBAGENT=off || SUBAGENT=on ;;
    safebash) [ "$SAFEBASH" = on ] && SAFEBASH=off || SAFEBASH=on ;;
    layout)   case "$LAYOUT" in auto) LAYOUT=row;; row) LAYOUT=stack;; *) LAYOUT=auto;; esac ;;
  esac
}

save() {
  {
    echo "# Status Bar config (written by the configurator)"
    echo "PANEL_USAGE=$PANEL_USAGE"
    echo "PANEL_CONTEXT=$PANEL_CONTEXT"
    echo "PANEL_COST=$PANEL_COST"
    echo "PANEL_ACTIVE=$PANEL_ACTIVE"
    echo "PANEL_GIT=$PANEL_GIT"
    echo "LAYOUT=$LAYOUT"
    echo "NOTIFIER=$NOTIFIER"
    echo "SUBAGENT=$SUBAGENT"
    echo "SAFEBASH=$SAFEBASH"
  } > "$CFG"
  if [ -x "$DIR/sync-settings.sh" ]; then "$DIR/sync-settings.sh" >/dev/null 2>&1; fi
  MSG="Saved. New panels show on the status line's next refresh."
}

MSG=""
draw
while true; do
  IFS= read -rsn1 key
  # ESC alone quits; ESC + [A/[B is an arrow key. After ESC, read the next bytes
  # with a short timeout: nothing follows -> bare ESC (quit); [A/[B -> arrows.
  if [ "$key" = $'\033' ]; then
    read -rsn2 -t 0.1 rest
    case "$rest" in '[A') key=up ;; '[B') key=down ;; *) key=quit ;; esac
  fi
  case "$key" in
    up|k)     cur=$(( (cur - 1 + ${#ROWS[@]}) % ${#ROWS[@]} )); MSG="" ;;
    down|j)   cur=$(( (cur + 1) % ${#ROWS[@]} )); MSG="" ;;
    ' '|'')   toggle; MSG="" ;;
    s|S)      save ;;
    q|Q|quit) break ;;
  esac
  draw
done
