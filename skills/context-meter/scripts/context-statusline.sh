#!/bin/bash
# Context-window meter for the Claude Code status line.
#   [Opus] ctx ▓▓▓░░░░░░░ 32% 64k/200k
# Per-session data, read straight from the status line JSON (one jq call).

input=$(cat)
IFS=$'\t' read -r MODEL PCT INTOK SIZE < <(printf '%s' "$input" | jq -r \
  '[.model.display_name // "?", (.context_window.used_percentage // -1), (.context_window.total_input_tokens // 0), (.context_window.context_window_size // 200000)] | @tsv')

hk() { local n="${1:-0}"; if [ "$n" -ge 1000 ]; then printf '%dk' "$((n / 1000))"; else printf '%d' "$n"; fi; }

if [ -z "$PCT" ] || [ "$PCT" = "-1" ]; then printf '[%s]' "$MODEL"; exit 0; fi
PCTI=$(printf '%.0f' "$PCT"); [ "$PCTI" -gt 100 ] && PCTI=100; [ "$PCTI" -lt 0 ] && PCTI=0

FILL=$(printf '\342\226\223'); EMP=$(printf '\342\226\221')
bar=""; i=0
while [ "$i" -lt $((PCTI / 10)) ]; do bar+="$FILL"; i=$((i + 1)); done
while [ "$i" -lt 10 ]; do bar+="$EMP"; i=$((i + 1)); done

col='\033[32m'; [ "$PCTI" -ge 70 ] && col='\033[33m'; [ "$PCTI" -ge 90 ] && col='\033[31m'
printf '[%s] ctx %b%s\033[0m %d%% \033[90m%s/%s\033[0m' "$MODEL" "$col" "$bar" "$PCTI" "$(hk "$INTOK")" "$(hk "$SIZE")"
