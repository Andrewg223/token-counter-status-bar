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

for f in statusbar.sh usage-read.sh sync-settings.sh notify.sh subagent-statusline.sh; do
  cp "$SRC/$f" "$DIR/$f"
done
chmod +x "$DIR"/*.sh
[ -f "$DIR/config" ] || cp "$SRC/config.default" "$DIR/config"

# wire settings.json (status line + notifier/subagent/safebash per config)
"$DIR/sync-settings.sh"

echo "Status Bar installed."
echo "  Turn functions on/off by editing:  $DIR/config"
echo "  Panel changes show on the status line's next refresh."
echo "  (After changing NOTIFIER / SUBAGENT / SAFEBASH, run: $DIR/sync-settings.sh)"
