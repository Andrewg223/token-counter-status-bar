# Status Bar

A modular utility layer for the Claude Code terminal — a **status bar built from toggleable panels** plus a few **settings features**, all managed from one **visual in-terminal app**. The repo is the system; each panel and feature is a part you switch on or off.

![Status Bar](assets/statusbar.png)

Open the configurator with **`! sb`** — toggle panels and features, live preview, `s` to save, `Esc` to close:

```
 Status Bar   configure your terminal status bar

  > [x]  Plan usage      5h session + weekly (All Models) limits
    [x]  Context         context-window fill for this session
    [ ]  Cost            session cost ($) — API billing only
    [x]  Active time     how long this session has run
    [x]  Git             branch, staged/modified, open PR
    [ auto ] Layout      auto = one row, wraps when narrow
    [ ]  Notifications   desktop ping on done / needs-input (macOS)
    [ ]  Subagent rows   custom rows in the subagent panel
    [ ]  Auto-allow Bash  stop prompting for read-only commands

 Preview
  SESSION ▓▓▓▓░░░░░░ 47% 2h13m   WEEK ▓▓░░░░░░░░ 24% Fri 13:00   CONTEXT ▓▓▓░░░░░░░ 32%   active 17h39m

 up/down move   space toggle / cycle layout   s save   esc/q exit
```

## Parts of the system

**Status-bar panels** — compose into one responsive bar (one row, wraps to stacked rows when narrow). Panels are **billing-aware** and hide when not relevant to the current chat:
- **Plan usage** — 5h session + weekly (All-Models) limits, coloured bars + reset times, synced to one value across every terminal at near-zero CPU. *(subscription only)*
- **Context** — context-window fill as a percentage (Claude's own `used_percentage`, matching `/context`).
- **Cost** — session cost in dollars. *(API / pay-per-use only — it's notional on a subscription)*
- **Active** — how long this session has been running.
- **Git** — branch, staged/modified counts, open PR + review state.

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

Then open the panel by typing **`! sb`** in the Claude prompt (or just `sb` in any terminal). The `!` runs it in your real terminal and returns to Claude on exit. In the panel: arrow keys move, **space** toggles or cycles the layout, live preview, **s** save, **Esc**/**q** to return. Requires `jq`; macOS for the notifier.

**Why `! sb` and not a `/command`:** a custom slash command always goes through the model (you'd see it "think"), and Claude Code's native dialogs aren't user-extensible. The `!` bang-prefix is the only way to open an interactive panel instantly with no model involvement.

## How it stays cheap

Opening more terminals doesn't multiply work. The account-wide usage panel uses a shared cache — one session computes the value, the rest just read it; a normal render spawns only `date`/`stat`, no `jq`. This avoids the fork/exec storm that pins macOS `sysmond` when a heavy status line refreshes every second in every window. Per-session panels read this session's JSON directly.

## Scope — system, not content

This is a **system** tool: how you operate Claude Code (status bar, settings, notifications, ergonomics). It deliberately contains **no** content generation, domain, or work-process logic. The test: *drop it into a stranger's Claude Code with none of your projects — does it still work?* Yes. That's the line.

## License

MIT. Free to copy, fork, and adapt.
