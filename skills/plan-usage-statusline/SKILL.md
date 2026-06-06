---
name: plan-usage-statusline
description: Install a Claude Code status line that shows plan usage limits — current 5-hour session usage and weekly (All Models) usage — as compact coloured bars with reset times, on one row that wraps to two when the terminal is narrow. The value is synced to one shared number across every terminal and session, and it costs almost no CPU (one session computes, the rest just read). Use this when the user wants to see their Claude plan / rate-limit usage in the terminal, asks for a usage meter, status bar, or header showing session or weekly limits or percentages, wants the same usage value shown consistently across multiple terminal windows, or reports a usage status line that eats CPU or flashes. Builds two small shell scripts plus one statusLine settings entry; no servers, no daemons, no background processes.
---

# Plan usage status line

A Claude Code [status line](https://code.claude.com/docs/en/statusline) that shows how much of your plan you've used, always visible at the bottom of Claude Code:

```
SESSION ▓▓▓▓░░░░░░ 42% 2h13m   WEEKLY ▓▓░░░░░░░░ 24% Fri 13:00
```

- **SESSION** — the current 5-hour rolling window (`rate_limits.five_hour`).
- **WEEKLY** — the weekly, All-Models window (`rate_limits.seven_day`).
- Bars are colour-coded: green < 70%, yellow 70–89%, red 90%+.
- Each shows the percentage used and when the window resets.
- One row when it fits; it wraps to two rows automatically when the terminal is narrow, so values are never truncated.

It requires a **Claude Pro/Max plan** (the `rate_limits` fields only appear for subscribers, after the first API response in a session) and **Claude Code v2.1.153+** (for the `COLUMNS` width the responsive wrap uses).

## Why it's built this way

The plan-usage percentages are only exposed in one place: the JSON Claude Code pipes to a status line command. They are not in any file or API you can poll. So:

1. **Data tap (per session).** Every Claude session writes its own snapshot of `rate_limits` to `~/.claude/usage/<session_id>.json`. This is the only way the numbers can be captured — each session sees its own.
2. **Shared aggregate (one computes, the rest read).** A single authoritative value is derived from all session files by `usage-read.sh`: newest reset-window wins, highest percentage within a window wins (usage only climbs), newest write breaks ties. This runs at most once every few seconds *across all terminals*, not once per terminal — so opening more windows does not multiply the work. The result is cached at `~/.claude/usage-synced`.
3. **Cheap render (every terminal).** Each terminal just reads the shared cache and prints it. A normal "read" tick spawns only `date` and `stat` — no `jq` — so it's imperceptible even with many windows open.

This makes every terminal show the **same** value (no per-window disagreement) at near-zero CPU. An earlier naive version that ran the full aggregation in every window every second caused a fork/exec storm that pinned macOS's `sysmond`; this design avoids that.

## Install

```sh
# 1. scripts
cp scripts/usage-statusline.sh ~/.claude/usage-statusline.sh
cp scripts/usage-read.sh       ~/.claude/usage-read.sh
chmod +x ~/.claude/usage-statusline.sh ~/.claude/usage-read.sh

# 2. point Claude Code's status line at it (merge into ~/.claude/settings.json)
#    see settings-snippet.json in this folder:
#    "statusLine": { "type": "command", "command": "~/.claude/usage-statusline.sh", "refreshInterval": 10 }
```

Requires `jq` (`brew install jq`) and `bash`. Restart or send one message in Claude Code; the bar appears after the first API response.

Quick test without Claude:

```sh
now=$(date +%s)
echo "{\"session_id\":\"t\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":42,\"resets_at\":$((now+9000))},\"seven_day\":{\"used_percentage\":24,\"resets_at\":$((now+200000))}}}" | ~/.claude/usage-statusline.sh
```

## Tuning

- `refreshInterval` in `settings.json` controls how often the bar refreshes while you're idle (it always updates on every message). Lower = snappier resize/countdown, more frequent (but still cheap) refresh; higher = calmer. `10` is a good default; `1` updates near-instantly but refreshes every second.
- `COOL` / `REFRESH` at the top of `usage-statusline.sh` control how often a session re-records its snapshot and how often the shared aggregate is rebuilt.
- To blank the in-Claude bar but keep the data (e.g. if you render it elsewhere), the script's only output is the final two `printf` lines.

## Files

- `scripts/usage-statusline.sh` — the status line command: data tap + shared-aggregate refresh + render.
- `scripts/usage-read.sh` — the aggregator: reduces all session snapshots to one authoritative value (single `jq` call).
- `settings-snippet.json` — the `statusLine` entry to merge into `~/.claude/settings.json`.

## Notes / limits

- Numbers are fresh only while a Claude session is open and refreshing; between sessions the bar shows the last-known value, with the reset countdown still ticking.
- There is no separate per-model (e.g. Opus-only) weekly figure available from the status line JSON — only the All-Models weekly number.
- macOS-flavoured `date`/`stat` flags (`date -r`, `stat -f`); on Linux swap to `date -d @EPOCH` and `stat -c %Y`.
