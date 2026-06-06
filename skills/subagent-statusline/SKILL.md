---
name: subagent-statusline
description: Customise the rows shown in the Claude Code subagent panel (the subagentStatusLine setting) — replace the default name/description/token row with your own formatting, e.g. label, type, and token count. Use when the user wants to change how subagents are displayed while they run, wants token counts or custom labels in the agent panel, or wants to hide or restyle subagent rows. One small script plus a subagentStatusLine settings entry.
---

# Subagent status line

Custom rows for the Claude Code subagent panel. Each visible subagent row is replaced with your own format:

```
explore       Explore   3500 tok
verify auth   general   1200 tok
```

The command receives one JSON object with a `tasks` array (`id`, `name`, `type`, `status`, `label`, `tokenCount`, `startTime`, `cwd`, …) and prints **one JSON line per row to override**: `{"id": "<task id>", "content": "<row body>"}`. Omit a task's `id` to keep its default row; emit an empty `content` to hide it.

## Install

```sh
cp scripts/subagent-statusline.sh ~/.claude/subagent-statusline.sh
chmod +x ~/.claude/subagent-statusline.sh
# merge settings-snippet.json into ~/.claude/settings.json (key: subagentStatusLine)
```

Requires `jq`. This is independent of the main `statusLine`, so it composes with any of the status-line skills.

## Customise

`content` is rendered as-is, including ANSI colours and OSC 8 links. Edit the jq string in the script to add fields (status, elapsed from `startTime`, cwd) or colour. Keep it short — the panel rows are narrow.
