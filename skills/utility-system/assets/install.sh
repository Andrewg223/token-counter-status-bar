#!/bin/bash
# Installer for Claude Utility System.
# Deploys the runtime to ~/.claude/utility-system/, writes a default config,
# wires the status line (and notifier hooks, per config) into settings.json,
# and adds a `cus` alias that opens the configurator. Idempotent.

set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DIR="$HOME/.claude/utility-system"
mkdir -p "$DIR/usage"

command -v jq >/dev/null 2>&1 || { echo "Please install jq first (brew install jq)."; exit 1; }

for f in statusbar.sh usage-read.sh configure.sh sync-settings.sh notify.sh subagent-statusline.sh; do
  cp "$SRC/$f" "$DIR/$f"
done
chmod +x "$DIR"/*.sh
[ -f "$DIR/config" ] || cp "$SRC/config.default" "$DIR/config"

# wire settings.json (status line + notifier per config)
"$DIR/sync-settings.sh"

# add a `cus` alias to the user's shell rc (idempotent)
ALIAS="alias cus='~/.claude/utility-system/configure.sh'"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  grep -q "utility-system/configure.sh" "$rc" || printf '\n# Claude Utility System\n%s\n' "$ALIAS" >> "$rc"
done

echo "Claude Utility System installed."
echo "  Config:     $DIR/config"
echo "  Configurator: run 'cus' in a new shell, or: $DIR/configure.sh"
echo "  The status line appears in Claude Code after the next message."
