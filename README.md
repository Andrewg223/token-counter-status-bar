# Status Bar

A modular utility layer for the Claude Code terminal — a **status bar built from toggleable panels** plus a few **settings features**. The repo is the system; each panel and feature is a part you switch on or off in a one-line config file.

![Status Bar](assets/statusbar.png)

**Toggle functions two ways:**

- **Ask the chat** — "turn off the git panel", "show cost", "hide the menu line". The installer adds a small block to your `~/CLAUDE.md`, so any Claude Code session knows where the config lives and edits it for you. (The `MENU` line in the bar is the reminder.)
- **Edit `~/.claude/status-bar/config`** — the list of every function; set each `on` or `off`:

```
# Status Bar — your functions.  on = shown,  off = hidden.
PANEL_USAGE=on        # SESSION + WEEK plan-usage bars   (subscription only)
PANEL_CONTEXT=on      # context-window %
PANEL_COST=off        # session cost ($)                 (API / pay-per-use only)
PANEL_ACTIVE=on       # how long this session has run
PANEL_GIT=off         # git branch, staged/modified, open PR
PANEL_MENU=on         # hint line: "ask chat to toggle panels / settings"
LAYOUT=auto           # auto = one row, wraps when narrow | row | stack
NOTIFIER=off          # desktop notification on done / needs-input (macOS)
SUBAGENT=off          # custom rows in the subagent panel
SAFEBASH=off          # auto-allow read-only Bash
```

Panel changes show on the bar's next refresh. After changing the last three (settings features), run `~/.claude/status-bar/sync-settings.sh`.

## Parts of the system

**Status-bar panels** — compose into one responsive bar (one row, wraps to stacked rows when narrow). Panels are **billing-aware** and hide when not relevant to the current chat:
- **Plan usage** — 5h session + weekly (All-Models) limits, coloured bars + reset times, synced to one value across every terminal at near-zero CPU. *(subscription only)*
- **Context** — context-window fill as a percentage (Claude's own `used_percentage`, matching `/context`).
- **Cost** — session cost in dollars. *(API / pay-per-use only — it's notional on a subscription)*
- **Active** — how long this session has been running.
- **Git** — branch, staged/modified counts, open PR + review state.
- **Menu** — a one-line reminder that you toggle panels and settings by asking the chat (the control surface, since the bar can't be a clickable menu).

**Settings features** — synced into `settings.json` (your other settings preserved):
- **Notifications** — macOS desktop ping when a run finishes or needs input.
- **Subagent rows** — custom formatting for the subagent panel.
- **Auto-allow Bash** — a conservative read-only allowlist so routine commands stop prompting.

**Extra:** a `session-namer` alias to launch Claude with a folder-derived session name.

## Install

```sh
cp -R skills/status-bar ~/.claude/skills/
~/.claude/skills/status-bar/assets/install.sh
```

The installer also adds a small marked block to your **`~/CLAUDE.md`**, so from then on you can just **ask any Claude Code chat** to toggle the bar ("turn off the git panel") and it edits the config for you. You can always edit **`~/.claude/status-bar/config`** by hand too (shown above). Requires `jq`; macOS for the notifier.

**Why ask the chat instead of a popup:** Claude Code can't open an interactive popup for this — a custom `/command` always goes through the model, native dialogs aren't user-extensible, and the status line is display-only (it can't be made into a clickable/keyboard menu). So the chat *is* the control surface: the hardwired `~/CLAUDE.md` block makes "ask the chat" reliable, and the config file is always there as the plain edit-and-save fallback.

## How it stays cheap — and in sync

The 5h + weekly numbers are account-wide — one true value for the whole account — so every terminal shares **one** file (`~/.claude/status-bar/usage-ssot`). Each window merges its own reading (the `rate_limits` Claude Code puts in that render — the server's figure, the same `/usage` shows) into that file and displays it. Switch windows and the number is identical; a window that's behind shows what another just published; an idle window shows the shared value, not a stale one of its own. Extraction is plain bash — no `jq`, no per-window scanning — so a render spawns only `date`/`stat`, avoiding the fork/exec storm that pins macOS `sysmond`. Context, cost and git stay per-session. (Cross-window propagation is one refresh tick; the status line refreshes every 3s.)

**Correct on resets, by construction.** The shared value is the reading from the newest window (latest `resets_at`) and, within it, the highest percent — provably the current usage: a window's `resets_at` only moves forward, so a reset is reflected the instant any window observes it; within a window, usage only climbs. No wall-clock is used anywhere, so an idle window re-emitting an old reading can't "refresh" a stale number — the bug that broke the first cross-window attempt.

## Scope — system, not content

This is a **system** tool: how you operate Claude Code (status bar, settings, notifications, ergonomics). It deliberately contains **no** content generation, domain, or work-process logic. The test: *drop it into a stranger's Claude Code with none of your projects — does it still work?* Yes. That's the line.

## License

MIT. Free to copy, fork, and adapt.
