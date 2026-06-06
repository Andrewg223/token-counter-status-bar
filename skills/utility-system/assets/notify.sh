#!/bin/bash
# Desktop notification from a Claude Code hook (used by the Notifications feature).
# Arg 1 = title; reads the hook JSON on stdin and uses its .message if present.
# Linux: replace the osascript line with:  notify-send "$TITLE" "$MSG"
input=$(cat)
TITLE="${1:-Claude Code}"
MSG=$(printf '%s' "$input" | jq -r '.message // .reason // empty' 2>/dev/null)
[ -z "$MSG" ] && MSG="ready"
MSG=${MSG//\\/}; MSG=${MSG//\"/}
osascript -e "display notification \"$MSG\" with title \"$TITLE\"" >/dev/null 2>&1
exit 0
