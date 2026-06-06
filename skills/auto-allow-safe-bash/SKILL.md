---
name: auto-allow-safe-bash
description: A conservative permission allowlist of read-only Bash commands to merge into Claude Code settings, so routine inspection commands (ls, cat, grep, rg, find, git status/log/diff, jq) stop prompting for approval. Use when the user is tired of approving the same harmless read-only commands, wants fewer permission prompts, or wants a safe starter allowlist. Read-only commands only — nothing that writes, deletes, installs, or hits the network.
---

# Auto-allow safe Bash

A starter `permissions.allow` list of **read-only, no-side-effect** Bash commands, so Claude Code stops asking before every `ls` or `git diff`. Merge `settings-snippet.json` into `~/.claude/settings.json`.

## The rule (why it's safe)

Every entry only **reads** state — listing, viewing, searching, inspecting git. Nothing that writes files, deletes, moves, installs, changes config, or makes network calls is included. That's the line: if a command can change your machine or reach the internet, it does **not** belong on an auto-allow list — keep approving those case by case.

Included: `ls cat head tail wc grep rg find tree file stat pwd echo which env date jq sort uniq cut sed -n` and read-only git (`status log diff show branch`, `remote -v`). Note `sed -n` only (no in-place `-i`); `awk` is deliberately excluded (it can write files and shell out).

## Install

Merge the `allow` array in `settings-snippet.json` into your existing `permissions.allow` in `~/.claude/settings.json` (don't overwrite entries you already have).

## Caveats

- Review the list before adding it — your idea of "safe" may differ.
- Matcher syntax can vary by Claude Code version; the built-in `/fewer-permission-prompts` command generates an allowlist tailored to your own transcripts and is the canonical way to extend this.
- Allowlisting `Bash` broadly (the bare `Bash` permission) defeats the point and the safety — don't.
