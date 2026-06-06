---
name: done-and-input-notifier
description: Wire Claude Code hooks to fire a macOS desktop notification when a run finishes (Stop) or when Claude needs your input (Notification), so you can look away during long runs and get pinged. Use when the user wants to be notified, alerted, or pinged when Claude finishes or is waiting on them, wants desktop notifications from Claude Code, or keeps missing when a long task completes. One small hook script plus a hooks settings entry.
---

# Done / needs-you notifier

Two Claude Code hooks that send a macOS desktop notification:
- **Stop** → "Claude Code — done" when a run finishes.
- **Notification** → "Claude Code — needs you" when Claude is waiting on you (e.g. a permission prompt).

So you can switch windows during a long run and get pinged when it's done or stuck.

## Install

```sh
cp scripts/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
# merge settings-snippet.json into ~/.claude/settings.json (under "hooks")
```

Requires `jq`. macOS only as written (uses `osascript`); on Linux swap the `osascript` line in `notify.sh` for `notify-send "$TITLE" "$MSG"`.

The hook receives the event JSON on stdin; the script uses its `.message` when present and falls back to a default. The title is passed as the first argument, so you can give Stop and Notification different titles (as the snippet does).

## Notes

- Hooks run shell commands, so the workspace must be trusted (same gate as the status line).
- Claude Code also has built-in notification settings; this hook approach is for full control over wording, channel, and which events fire.
