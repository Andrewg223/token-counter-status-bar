---
name: utility-system
description: A modular Claude Code "utility system" — a status bar built from toggleable panels (plan usage, context window, cost, git/PR) plus settings features (desktop notifications, subagent rows, a read-only Bash allowlist), all configured from one visual in-terminal app. Use when the user wants to add, change, turn on/off, or configure their Claude Code status bar or any of these meters/features; when they ask to "open the configurator", "set up my status bar", "show usage/context/cost/git in the terminal"; or when they want a single place to manage these terminal utilities. Installs runtime to ~/.claude/utility-system/, wires settings.json, and provides an interactive configurator (the `cus` command).
---

# Claude Utility System

One modular system for the Claude Code terminal experience. Everything is a toggleable part of a larger whole, configured from a single visual app.

**Status-bar panels** (compose into one responsive bar):
- **Plan usage** — 5h session + weekly (All-Models) limits, synced to one value across all terminals.
- **Context** — context-window fill for this session.
- **Cost** — session cost estimate + elapsed time.
- **Git** — branch, staged/modified counts, open PR + review state.

**Settings features** (synced into `settings.json`):
- **Notifications** — desktop ping (macOS) when a run finishes or needs input.
- **Subagent rows** — custom formatting for the subagent panel.
- **Auto-allow Bash** — a conservative read-only allowlist so routine commands stop prompting.

**Extra:** a `session-namer.sh` alias snippet (`cc`) to launch Claude with a folder-derived session name (opt-in; not a settings toggle).

## The configurator (the app)

Run `cus` (or `~/.claude/utility-system/configure.sh`) in your terminal. It's a full-screen app: arrow keys move, **space** toggles a panel/feature or cycles the layout, with a **live preview** of the bar, **s** to save, **q** to quit. Saving writes the config and syncs `settings.json`.

```
 Claude Utility System   configure your terminal status bar

  > [x]  Plan usage     5h session + weekly (All Models) limits
    [x]  Context        context-window fill for this session
    [ ]  Cost           session cost estimate + elapsed time
    [ ]  Git            branch, staged/modified, open PR
    [ auto ] Layout     auto = one row, wraps when narrow
    [ ]  Notifications  desktop ping on done / needs-input (macOS)
    [ ]  Subagent rows  custom rows in the subagent panel
    [ ]  Auto-allow Bash stop prompting for read-only commands

 Preview
  USAGE ▓▓▓▓░░░░░░ 47% 2h13m   WEEK ▓▓░░░░░░░░ 24% Fri 13:00   CTX ...

 up/down move   space toggle / cycle layout   s save   q quit
```

## Install

```sh
cp -R skills/utility-system ~/.claude/skills/
~/.claude/skills/utility-system/assets/install.sh
```

The installer deploys the runtime to `~/.claude/utility-system/`, writes a default config, wires the status line into `settings.json`, and adds the `cus` alias. Requires `jq`; macOS for the notifier (`osascript`).

## For Claude (when the user wants to change their status bar)

1. Make sure it's installed (run `assets/install.sh` if `~/.claude/utility-system/` is missing).
2. The configurator is **interactive**, so the user runs it themselves — tell them to run `cus`, or suggest `! ~/.claude/utility-system/configure.sh` to launch it in-session.
3. For a non-interactive change, edit `~/.claude/utility-system/config` (e.g. `PANEL_GIT=on`) and run `~/.claude/utility-system/sync-settings.sh`.

## How it stays cheap

Adding terminals doesn't multiply work. The account-wide usage panel uses a shared cache: one session computes the synced value, every other terminal just reads it; a normal render tick spawns only `date`/`stat`, no `jq`. (This avoids the fork/exec storm that pins macOS `sysmond` when a heavy status line refreshes every second in every window.) Per-session panels (context, cost, git) read this session's JSON directly. The bar composes only the panels you enabled, on one row that wraps to stacked rows when the terminal is narrow.

## Files (`assets/`)

- `statusbar.sh` — the status line: renders enabled panels, composes layout.
- `usage-read.sh` — shared aggregator for the usage panel.
- `configure.sh` — the visual configurator app.
- `sync-settings.sh` — writes our entries into `settings.json` (preserves yours; timestamped backup).
- `install.sh` — deploy + wire + alias.
- `notify.sh`, `subagent-statusline.sh`, `session-namer.sh`, `config.default`.

`sync-settings.sh` only ever touches its own entries and backs up `settings.json` before each change; your other settings are preserved.
