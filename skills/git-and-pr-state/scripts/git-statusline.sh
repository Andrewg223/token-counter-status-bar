#!/bin/bash
# Git + PR state for the Claude Code status line.
#   [Opus] main +2 ~5  PR #1234 (approved)
# Branch / staged / modified come from git (cached per session for 3s so a big
# repo doesn't lag the bar). PR number + review state come from the JSON.

input=$(cat)
IFS=$'\t' read -r MODEL DIR SID PRNUM PRSTATE < <(printf '%s' "$input" | jq -r \
  '[.model.display_name // "?", .workspace.current_dir // ".", .session_id // "x", (.pr.number // ""), (.pr.review_state // "")] | @tsv')

CACHE="/tmp/git-statusline-$SID"
fresh=0
if [ -f "$CACHE" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
  [ "$age" -lt 3 ] && fresh=1
fi
if [ "$fresh" = 0 ]; then
  if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
    br=$(git -C "$DIR" branch --show-current 2>/dev/null)
    sg=$(git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    md=$(git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\n' "$br" "$sg" "$md" > "$CACHE"
  else
    printf '\t\t\n' > "$CACHE"
  fi
fi
IFS=$'\t' read -r BR SG MD < "$CACHE"

out="[$MODEL]"
[ -n "$BR" ] && out="$out \033[36m$BR\033[0m"
[ -n "$SG" ] && [ "$SG" -gt 0 ] && out="$out \033[32m+$SG\033[0m"
[ -n "$MD" ] && [ "$MD" -gt 0 ] && out="$out \033[33m~$MD\033[0m"
if [ -n "$PRNUM" ]; then
  pc='\033[90m'
  case "$PRSTATE" in
    approved) pc='\033[32m' ;; changes_requested) pc='\033[31m' ;;
    pending) pc='\033[33m' ;; draft) pc='\033[90m' ;;
  esac
  out="$out  ${pc}PR #$PRNUM${PRSTATE:+ ($PRSTATE)}\033[0m"
fi
printf '%b' "$out"
