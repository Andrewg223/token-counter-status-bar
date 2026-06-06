#!/bin/bash
# Hook notifier: fire a macOS desktop notification from a Claude Code hook.
# Arg 1 = title. Reads the hook JSON on stdin and uses its .message if present.
# Wire it to the Stop and Notification events (see settings-snippet.json).
#
# Linux: replace the osascript line with:  notify-send "$TITLE" "$MSG"

input=$(cat)
TITLE="${1:-Claude Code}"
MSG=$(printf '%s' "$input" | jq -r '.message // .reason // empty' 2>/dev/null)
[ -z "$MSG" ] && MSG="ready"
# strip quotes/backslashes so they can't break the AppleScript string
MSG=${MSG//\\/}; MSG=${MSG//\"/}
osascript -e "display notification \"$MSG\" with title \"$TITLE\"" >/dev/null 2>&1
exit 0
