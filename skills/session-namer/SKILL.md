---
name: session-namer
description: A shell function that launches Claude Code with a session name auto-derived from the current folder plus the time, so multiple sessions are easy to tell apart in the status line and session list. Use when the user runs several Claude Code sessions at once and can't tell them apart, wants sessions auto-named by project/folder, or is tired of unnamed sessions. A one-function shell snippet; no scripts to install.
---

# Session namer

Launch Claude Code with a name derived from the folder you're in and the time, so sessions are distinguishable at a glance (the name shows in the status line via `session_name` and in the session list):

```
~/projects/checkout  ->  claude --name "checkout-1432"
```

## Install

Add the function from `shell-snippet.sh` to your `~/.zshrc` (or `~/.bashrc`), then `source` it or open a new terminal. Start Claude with `cc` instead of `claude`:

```sh
cc            # names the session "<folder>-<HHMM>"
cc --resume   # extra args pass straight through
```

## Notes

- Uses `claude --name`; you can still rename mid-session with `/rename`.
- Pure shell, no dependencies. Rename the function if `cc` collides with something on your system.
- Tweak the name scheme in the snippet (e.g. add the git branch: `--name "${PWD##*/}-$(git branch --show-current 2>/dev/null)"`).
