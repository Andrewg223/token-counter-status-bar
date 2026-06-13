#!/bin/bash
# Sync ~/.claude/settings.json to the Status Bar config. Manages only our own
# entries; anything else you have is preserved. Makes a timestamped backup and
# writes atomically. Safe to run repeatedly.
#   statusLine          -> our statusbar.sh (always)
#   Stop/Notification   -> notify.sh        (NOTIFIER=on; removed when off)
#   subagentStatusLine  -> subagent rows    (SUBAGENT=on; removed when off)
#   permissions.allow   -> read-only Bash   (SAFEBASH=on; removed when off)

DIR="$HOME/.claude/status-bar"
S="$HOME/.claude/settings.json"
[ -r "$DIR/config" ] && . "$DIR/config"
: "${NOTIFIER:=off}"; : "${SUBAGENT:=off}"; : "${SAFEBASH:=off}"

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }
[ -f "$S" ] || echo '{}' > "$S"
cp "$S" "$S.sb.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null

SAFELIST='["Bash(ls:*)","Bash(cat:*)","Bash(head:*)","Bash(tail:*)","Bash(wc:*)","Bash(grep:*)","Bash(rg:*)","Bash(find:*)","Bash(tree:*)","Bash(file:*)","Bash(stat:*)","Bash(pwd)","Bash(echo:*)","Bash(which:*)","Bash(env)","Bash(date)","Bash(jq:*)","Bash(sort:*)","Bash(uniq:*)","Bash(cut:*)","Bash(sed -n:*)","Bash(git status:*)","Bash(git log:*)","Bash(git diff:*)","Bash(git show:*)","Bash(git branch:*)","Bash(git remote -v)"]'

TMP="$S.sb.tmp.$$"
jq \
  --arg sl "~/.claude/status-bar/statusbar.sh" \
  --arg note "$NOTIFIER" --arg sub "$SUBAGENT" --arg sb "$SAFEBASH" \
  --argjson safe "$SAFELIST" '
  def strip(a): (a // []) | map(select(
    (((.hooks // []) | map(.command) | join(" "))) | contains("status-bar/notify.sh") | not));

  # --- status line (always ours) ---
  # 3s: cross-window usage sync propagates within one refresh, and renders are cheap
  # (the usage panel forks no jq). Raise it to lower CPU if you ever need to.
  .statusLine = {type:"command", command:$sl, refreshInterval:3}

  # --- notifier hooks ---
  | .hooks = (.hooks // {})
  | .hooks.Stop = strip(.hooks.Stop)
  | .hooks.Notification = strip(.hooks.Notification)
  | if $note == "on" then
      .hooks.Stop += [{"hooks":[{"type":"command","command":"~/.claude/status-bar/notify.sh \"Claude Code — done\""}]}]
      | .hooks.Notification += [{"hooks":[{"type":"command","command":"~/.claude/status-bar/notify.sh \"Claude Code — needs you\""}]}]
    else . end
  | if (.hooks.Stop // [] | length) == 0 then del(.hooks.Stop) else . end
  | if (.hooks.Notification // [] | length) == 0 then del(.hooks.Notification) else . end
  | if (.hooks | length) == 0 then del(.hooks) else . end

  # --- subagent status line (only touch ours) ---
  | if $sub == "on" then
      .subagentStatusLine = {type:"command", command:"~/.claude/status-bar/subagent-statusline.sh"}
    elif ((.subagentStatusLine.command // "") | contains("status-bar/subagent-statusline.sh")) then
      del(.subagentStatusLine)
    else . end

  # --- safe-bash allowlist (remove ours, then add back if on; keep your entries) ---
  | .permissions = (.permissions // {})
  | .permissions.allow = ((.permissions.allow // []) | map(select(. as $x | ($safe | index($x)) == null)))
  | if $sb == "on" then .permissions.allow = (.permissions.allow + $safe) else . end
  | if (.permissions.allow | length) == 0 then .permissions |= del(.allow) else . end
  | if (.permissions | length) == 0 then del(.permissions) else . end
' "$S" > "$TMP" && mv -f "$TMP" "$S" || { rm -f "$TMP"; echo "sync failed; settings unchanged" >&2; exit 1; }
