#!/bin/bash
# Installer for Status Bar.
# Deploys the runtime to ~/.claude/status-bar/, writes a default config,
# wires the status line (and notifier hooks, per config) into settings.json,
# and adds a `sb` alias that opens the configurator. Idempotent.

set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DIR="$HOME/.claude/status-bar"
mkdir -p "$DIR/usage"

command -v jq >/dev/null 2>&1 || { echo "Please install jq first (brew install jq)."; exit 1; }

for f in statusbar.sh usage-read.sh configure.sh sync-settings.sh notify.sh subagent-statusline.sh; do
  cp "$SRC/$f" "$DIR/$f"
done
chmod +x "$DIR"/*.sh
[ -f "$DIR/config" ] || cp "$SRC/config.default" "$DIR/config"

# wire settings.json (status line + notifier per config)
"$DIR/sync-settings.sh"

# install the /status-bar slash command (opens the admin panel)
if [ -f "$SRC/../commands/status-bar.md" ]; then
  mkdir -p "$HOME/.claude/commands"
  cp "$SRC/../commands/status-bar.md" "$HOME/.claude/commands/status-bar.md"
fi

# add a `sb` alias to the user's shell rc (idempotent)
ALIAS="alias sb='~/.claude/status-bar/configure.sh'"
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] || continue
  grep -q "status-bar/configure.sh" "$rc" || printf '\n# Status Bar\n%s\n' "$ALIAS" >> "$rc"
done

# also install a real `sb` command on PATH if a writable bin dir exists, so `! sb`
# opens the panel in ANY shell (aliases only load in interactive shells).
for bindir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
  if [ -d "$bindir" ] && [ -w "$bindir" ]; then
    printf '#!/bin/bash\nexec "$HOME/.claude/status-bar/configure.sh" "$@"\n' > "$bindir/sb"
    chmod +x "$bindir/sb"
    break
  fi
done

echo "Status Bar installed."
echo "  Config:     $DIR/config"
echo "  Configurator: run 'sb' in a new shell, or: $DIR/configure.sh"
echo "  The status line appears in Claude Code after the next message."
