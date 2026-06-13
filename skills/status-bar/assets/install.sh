#!/bin/bash
# Installer for Status Bar.
# Deploys the runtime to ~/.claude/status-bar/, writes a default config, and wires
# the status line (+ notifier/subagent/safebash per config) into settings.json.
# To turn functions on/off, edit ~/.claude/status-bar/config (see that file).

set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DIR="$HOME/.claude/status-bar"
mkdir -p "$DIR/usage"

command -v jq >/dev/null 2>&1 || { echo "Please install jq first (brew install jq)."; exit 1; }

# Make every future Claude Code session status-bar-aware. Adds a small, clearly
# marked, idempotent block to ~/CLAUDE.md so any chat can toggle panels/settings
# on request, instantly — there is no popup (the status line is display-only), so
# "ask the chat" is the control surface. Re-running refreshes the block in place
# and never touches anything else; a timestamped backup is taken first.
hardwire_claude_md() {
  local cm="$HOME/CLAUDE.md" S="<!-- status-bar:start -->" E="<!-- status-bar:end -->"
  if [ -s "$cm" ]; then cp "$cm" "$cm.bak.$(date +%Y%m%d-%H%M%S)"; fi
  [ -f "$cm" ] || : > "$cm"
  # strip any previous status-bar block, then drop trailing blank lines
  awk -v s="$S" -v e="$E" 'index($0,s){skip=1} skip!=1{print} index($0,e){skip=0}' "$cm" \
    | awk 'NF{last=NR} {l[NR]=$0} END{for(i=1;i<=last;i++)print l[i]}' > "$cm.sbtmp.$$"
  {
    cat "$cm.sbtmp.$$"
    if [ -s "$cm.sbtmp.$$" ]; then printf '\n'; fi
    cat <<BLOCK
$S
## Status Bar (installed skill)

A status bar renders in this terminal from \`~/.claude/status-bar/\`. Every
function is toggled in one file: \`~/.claude/status-bar/config\` (each key \`on\`/\`off\`).

When the user asks to turn a panel on/off, change the layout, or flip a settings
feature, just edit that file — don't ask, don't try to open a popup (there is
none; the status line is display-only). Keys:

    PANEL_USAGE    SESSION + WEEK plan-usage bars (subscription only)
    PANEL_CONTEXT  context-window %
    PANEL_COST     session cost (\$) (API / pay-per-use only)
    PANEL_ACTIVE   how long the session has run
    PANEL_GIT      git branch / staged / modified / PR
    PANEL_MENU     the "ask chat to toggle" hint line
    LAYOUT         auto | row | stack
    NOTIFIER / SUBAGENT / SAFEBASH   settings features

Panels apply on the bar's next refresh. After changing NOTIFIER, SUBAGENT, or
SAFEBASH, run \`~/.claude/status-bar/sync-settings.sh\`.
$E
BLOCK
  } > "$cm.sbtmp2.$$" && mv -f "$cm.sbtmp2.$$" "$cm"
  rm -f "$cm.sbtmp.$$"
}

for f in statusbar.sh sync-settings.sh notify.sh subagent-statusline.sh; do
  cp "$SRC/$f" "$DIR/$f"
done
chmod +x "$DIR"/*.sh
[ -f "$DIR/config" ] || cp "$SRC/config.default" "$DIR/config"
# retire the old cross-window aggregator + its cache (usage is now read per-session, no jq)
rm -f "$DIR/usage-read.sh" "$DIR/usage-synced" "$DIR"/usage/*.json 2>/dev/null

# wire settings.json (status line + notifier/subagent/safebash per config)
"$DIR/sync-settings.sh"

# teach every future chat how to toggle the bar (adds a block to ~/CLAUDE.md)
hardwire_claude_md

echo "Status Bar installed."
echo "  Turn functions on/off by editing:  $DIR/config"
echo "  ...or just ask any Claude chat (e.g. \"turn off the git panel\") — the"
echo "     installer taught your ~/CLAUDE.md how, so it edits the file for you."
echo "  Panel changes show on the status line's next refresh."
echo "  (After changing NOTIFIER / SUBAGENT / SAFEBASH, run: $DIR/sync-settings.sh)"
