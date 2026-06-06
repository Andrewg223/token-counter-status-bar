---
name: cost-and-duration
description: Install a Claude Code status line that shows the current session's estimated cost, elapsed wall-clock time, time spent waiting on the API, and lines added/removed. Use when the user wants to track session cost or spend, wants a timer or duration in the status line, asks how long or how expensive a session has been, or wants lines-changed visible. One small script plus one statusLine settings entry.
---

# Cost and duration meter

A Claude Code status line showing session cost and time:

```
[Opus] $0.42  12m04s  api 2m10s  +156 -23
```

- `$0.42` — estimated session cost (`cost.total_cost_usd`, client-side estimate; may differ from your actual bill).
- `12m04s` — wall-clock since session start; `api 2m10s` — time spent waiting on the API.
- `+156 -23` — lines added / removed.

Per session, one `jq` call.

## Install

```sh
cp scripts/cost-statusline.sh ~/.claude/cost-statusline.sh
chmod +x ~/.claude/cost-statusline.sh
# merge settings-snippet.json into ~/.claude/settings.json
```

Requires `jq`. Claude Code runs **one** status line, so this replaces any current `statusLine`. To show cost alongside context or git, combine the scripts (see the repo README's note on composing meters).
