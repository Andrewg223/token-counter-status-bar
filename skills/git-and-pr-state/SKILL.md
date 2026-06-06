---
name: git-and-pr-state
description: Install a Claude Code status line that shows the current git branch, staged and modified file counts, and any open pull request with its review state. Use when the user wants git branch and status always visible in the status line, wants to see staged/modified counts, or wants the open PR and its review status (approved, changes requested, pending, draft) shown. One small script plus one statusLine settings entry; git calls are cached for 3 seconds so large repos don't lag the bar.
---

# Git and PR state

A Claude Code status line showing git + PR context:

```
[Opus] main +2 ~5  PR #1234 (approved)
```

- `main` — current branch; `+2` staged, `~5` modified.
- `PR #1234 (approved)` — open PR for the branch and its review state, colour-coded (approved green, changes_requested red, pending yellow, draft grey). Comes from the JSON's `pr.*` fields.

Branch/diff counts come from `git`, **cached per session for 3 seconds** (the documented pattern) so `git status` doesn't lag the bar in a big repo.

## Install

```sh
cp scripts/git-statusline.sh ~/.claude/git-statusline.sh
chmod +x ~/.claude/git-statusline.sh
# merge settings-snippet.json into ~/.claude/settings.json
```

Requires `jq` and `git`. Claude Code runs **one** status line, so this replaces any current `statusLine`. To show git alongside context or cost, combine the scripts (see the repo README's note on composing meters).
