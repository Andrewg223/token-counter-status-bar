#!/bin/bash
# Custom rows for the Claude Code subagent panel (subagentStatusLine).
# Input: one JSON object with a `tasks` array (id, name, type, status, label,
# tokenCount, startTime, cwd, ...). Output: one JSON line per row to override,
# {"id": "<task id>", "content": "<row body>"}.
#
# Renders:  <label/name>  <type>  <tokenCount> tok
# Omit a task's id to keep its default row; emit "" content to hide a row.
# content is rendered as-is, so you can add ANSI colour codes inside the jq
# string if you want (e.g. wrap .type in a dim-grey code and a reset).

input=$(cat)
printf '%s' "$input" | jq -rc '
  .tasks[]? | {
    id: .id,
    content: (
      (.label // .name // "agent")
      + "  " + (.type // "")
      + "  " + ((.tokenCount // 0) | tostring) + " tok"
    )
  }'
