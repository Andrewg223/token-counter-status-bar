---
name: status-bar
description: A modular Claude Code "status bar" — a status bar built from toggleable panels (plan usage, context window, cost, git/PR) plus settings features (desktop notifications, subagent rows, a read-only Bash allowlist), all configured from one visual in-terminal app. Use when the user wants to add, change, turn on/off, or configure their Claude Code status bar or any of these meters/features; when they ask to "open the configurator", "set up my status bar", "show usage/context/cost/git in the terminal"; or when they want a single place to manage these terminal utilities. Installs runtime to ~/.claude/status-bar/, wires settings.json; functions are turned on/off by editing ~/.claude/status-bar/config.
---

# Status Bar

One modular system for the Claude Code terminal experience. Everything is a toggleable part of a larger whole, configured from a single visual app.

**Status-bar panels** (compose into one responsive bar; billing-aware — each hides when not relevant):
- **Plan usage** — 5h session + weekly (All-Models) limits, synced to one value across all terminals. *(subscription only)*
- **Context** — context-window fill as a percentage (Claude's own `used_percentage`, matching `/context`).
- **Cost** — session cost in dollars. *(API / pay-per-use only)*
- **Active** — how long this session has been running.
- **Git** — branch, staged/modified counts, open PR + review state.

**Settings features** (synced into `settings.json`):
- **Notifications** — desktop ping (macOS) when a run finishes or needs input.
- **Subagent rows** — custom formatting for the subagent panel.
- **Auto-allow Bash** — a conservative read-only allowlist so routine commands stop prompting.

**Extra:** a `session-namer.sh` alias snippet (`cc`) to launch Claude with a folder-derived session name (opt-in; not a settings toggle).

## Turn functions on/off

Edit **`~/.claude/status-bar/config`** — it's the list of every function; set each `on` or `off`:

```
PANEL_USAGE=on     # SESSION + WEEK plan-usage bars   (subscription only)
PANEL_CONTEXT=on   # context-window %
PANEL_COST=off     # session cost ($)                 (API / pay-per-use only)
PANEL_ACTIVE=on    # how long this session has run
PANEL_GIT=off      # git branch, staged/modified, open PR
LAYOUT=auto        # auto = one row, wraps when narrow | row | stack
NOTIFIER=off       # desktop notification on done / needs-input
SUBAGENT=off       # custom rows in the subagent panel
SAFEBASH=off       # auto-allow read-only Bash
```

Panel changes show on the bar's next refresh. After changing NOTIFIER / SUBAGENT / SAFEBASH, run `~/.claude/status-bar/sync-settings.sh`.

> There is no interactive popup, by design: a custom `/command` always invokes the model, Claude Code's native dialogs aren't user-extensible, and the status line is display-only (it can't be turned into a keyboard/clickable menu). Editing the config file is the simple, model-free way to toggle.

## Install

```sh
cp -R skills/status-bar ~/.claude/skills/
~/.claude/skills/status-bar/assets/install.sh
```

The installer deploys the runtime to `~/.claude/status-bar/`, writes a default config, wires the status line into `settings.json`, and adds the `sb` alias. Requires `jq`; macOS for the notifier (`osascript`).

## For Claude (when the user wants to change their status bar)

1. Make sure it's installed (run `assets/install.sh` if `~/.claude/status-bar/` is missing).
2. To change which functions show, edit `~/.claude/status-bar/config` (e.g. `PANEL_GIT=on`). Panel changes apply on the next refresh; after changing NOTIFIER / SUBAGENT / SAFEBASH also run `~/.claude/status-bar/sync-settings.sh`.

## How it stays cheap

Adding terminals doesn't multiply work. The account-wide usage panel uses a shared cache: one session computes the synced value, every other terminal just reads it; a normal render tick spawns only `date`/`stat`, no `jq`. (This avoids the fork/exec storm that pins macOS `sysmond` when a heavy status line refreshes every second in every window.) Per-session panels (context, cost, git) read this session's JSON directly. The bar composes only the panels you enabled, on one row that wraps to stacked rows when the terminal is narrow.

## Files (`assets/`)

- `statusbar.sh` — the status line: renders enabled panels, composes layout.
- `usage-read.sh` — shared aggregator for the usage panel.
- `sync-settings.sh` — writes our entries into `settings.json` (preserves yours; timestamped backup).
- `config` — the toggle list (on/off per function).
- `install.sh` — deploy + wire + alias.
- `notify.sh`, `subagent-statusline.sh`, `session-namer.sh`, `config.default`.

`sync-settings.sh` only ever touches its own entries and backs up `settings.json` before each change; your other settings are preserved.
