---
name: context-meter
description: Install a Claude Code status line that shows context-window usage for the current session — a coloured bar, the percentage used, and tokens used vs the window size. Use when the user wants to watch how full the context window is getting, asks for a context meter, token meter, or context bar in the status line, or wants an at-a-glance warning as they approach the context limit. One small script plus one statusLine settings entry.
---

# Context-window meter

A Claude Code status line showing how full the context window is, for the current session:

```
[Opus] ctx ▓▓▓░░░░░░░ 32% 64k/200k
```

Bar colours by load (green < 70%, yellow 70–89%, red 90%+). Reads `context_window.used_percentage`, `total_input_tokens`, and `context_window_size` straight from the status line JSON — one `jq` call, per session, no shared state.

## Install

```sh
cp scripts/context-statusline.sh ~/.claude/context-statusline.sh
chmod +x ~/.claude/context-statusline.sh
# merge settings-snippet.json into ~/.claude/settings.json
```

Requires `jq`. Claude Code runs **one** status line, so this replaces any current `statusLine`. To show context alongside cost or git, combine the scripts (see the repo README's note on composing meters).
