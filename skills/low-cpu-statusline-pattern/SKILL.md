---
name: low-cpu-statusline-pattern
description: A recipe for building a Claude Code status line that costs almost no CPU even with many terminals open, by having ONE session compute a shared value and every other terminal just read it. Use when a status line needs data that is the same across sessions or is expensive to compute (account-wide rate limits, an API call, an aggregation over files), when a status line is eating CPU or making typing lag, or when the user reports a fork/exec storm or a refresh that runs heavy work every second in every window. Includes a fill-in template script.
---

# Low-CPU status line pattern

If a status line recomputes the same expensive thing in every terminal on every tick, you get a fork/exec storm. At a 1-second refresh across several windows that pins macOS's process monitor (`sysmond`) and lags your typing. The fix is to **compute once, share the result, and make every terminal's job a cheap read**.

## The three rules

1. **Cheap read every tick.** Each terminal reads a cached value and prints it — pure bash, no `jq`, no external work. This is the "pull" path every window runs.
2. **One refresh per interval.** Whichever tick finds the cache older than `REFRESH` seconds rebuilds it; everyone else finds it fresh and skips. So opening more terminals does **not** multiply the heavy work.
3. **Atomic write.** Write to a temp file and `mv` it into place, so a reader never sees a half-written cache. (A temp suffix like `.tmp.$$` also won't match a `*.json` glob, so aggregators skip it.)

## When to use it

- The data is **account-wide / shared** (e.g. plan rate limits): every window should show the same number, so compute it once.
- The data is **expensive** (an aggregation over many files, a CLI call, an API request): don't pay it per window per second.
- You saw **`sysmond` / WindowServer spike** or typing lag after adding a frequently-refreshing status line.

If the data is cheap and per-session (context %, cost — they arrive free in the status line JSON each call), you don't need this; just render directly.

## Template

`scripts/shared-cache-statusline.template.sh` has the skeleton — fill in two spots: how to compute the value, and how to format it. Set it as your `statusLine` command in `settings.json`.

## The lesson behind it

This pattern came from a usage meter that originally ran a full cross-session aggregation (one `jq` per session file) in every window every second — dozens of `jq` per second per window. Measured: `sysmond` pinned, terminal redraw thrashing, typing lag. Moving the aggregation behind a shared cache + age gate dropped a normal tick to two trivial commands and fixed it. See the `plan-usage-statusline` skill for a complete real implementation.
