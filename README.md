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

## How it stays cheap

Opening more terminals doesn't multiply work. The usage panel reads each session's own `rate_limits` — the figure Claude Code already pulled from the server and put in this render's input — with plain bash (no `jq`, no cross-window aggregation). A normal render spawns only `date`/`stat`. This avoids the fork/exec storm that pins macOS `sysmond` when a heavy status line refreshes every second in every window. The other panels read this session's input directly too.

**Accurate, not guessed.** Each session shows the server's own number verbatim, so a limit reset can't desync the bar — there's no shared cache holding a stale value to disagree with it. The window you're working in is always the server's current figure for that session; an idle window shows its last real reading until its next turn. (Making an *idle* window update in real time would require an independent authenticated pull from Anthropic's usage endpoint — possible, but it needs access to your Claude Code auth token.)

## Scope — system, not content

This is a **system** tool: how you operate Claude Code (status bar, settings, notifications, ergonomics). It deliberately contains **no** content generation, domain, or work-process logic. The test: *drop it into a stranger's Claude Code with none of your projects — does it still work?* Yes. That's the line.

## License

MIT. Free to copy, fork, and adapt.
