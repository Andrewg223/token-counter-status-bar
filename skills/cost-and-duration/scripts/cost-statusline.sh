#!/bin/bash
# Cost + duration meter for the Claude Code status line.
#   [Opus] $0.42  12m04s  api 2m10s  +156 -23
# Per-session data, read straight from the status line JSON (one jq call).
# Note: cost is the client-side estimate and may differ from your actual bill.

input=$(cat)
IFS=$'\t' read -r MODEL COST DUR APIDUR ADD DEL < <(printf '%s' "$input" | jq -r \
  '[.model.display_name // "?", (.cost.total_cost_usd // 0), (.cost.total_duration_ms // 0), (.cost.total_api_duration_ms // 0), (.cost.total_lines_added // 0), (.cost.total_lines_removed // 0)] | @tsv')

costf=$(printf '$%.2f' "$COST")
sec=$((DUR / 1000));    m=$((sec / 60));    s=$((sec % 60))
asec=$((APIDUR / 1000)); am=$((asec / 60)); as=$((asec % 60))

printf '[%s] %s  %dm%02ds  \033[90mapi %dm%02ds\033[0m  \033[32m+%s\033[0m \033[31m-%s\033[0m' \
  "$MODEL" "$costf" "$m" "$s" "$am" "$as" "$ADD" "$DEL"
