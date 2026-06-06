# Andrew's System Skills

Claude Code skills about **how you work with Claude Code itself** — the system, the harness, the ergonomics. Not what you build with it.

A *system skill* changes or extends the tool: the status line, settings, hooks, the terminal experience, session plumbing. It is general (it works for anyone) and self-contained (drop it in and it runs). These are meant to be shared.

## The line — what belongs here, what doesn't

**Belongs (system level):**
- Status lines and meters (plan usage, context, cost, git state)
- Settings, permissions, and hook patterns
- Terminal/session ergonomics and display
- Anything about operating Claude Code better, independent of the work

**Does NOT belong (the antipattern):**
- Content or copy generation (writing, design, marketing)
- Domain or work-process skills (a project's pipeline, a client's workflow, a PM system)
- Anything that only makes sense inside one person's specific projects

The test: *drop the skill into a stranger's Claude Code with none of your projects or files. Does it still do something useful?* If yes, it's a system skill and it belongs here. If it needs your content, your clients, or your workflow to mean anything, it's a work skill — keep it elsewhere.

## Skills

**Status lines** (Claude Code runs one at a time — see *Composing* below):
- **[plan-usage-statusline](skills/plan-usage-statusline/)** — plan usage: 5-hour session + weekly (All-Models) as coloured bars with reset times, on one row that wraps to two when narrow. Synced to one value across all terminals at near-zero CPU. `SESSION ▓▓▓▓░░░░░░ 42% 2h13m   WEEKLY ▓▓░░░░░░░░ 24% Fri 13:00`
- **[context-meter](skills/context-meter/)** — context-window bar, percentage, and tokens used vs window size. `[Opus] ctx ▓▓▓░░░░░░░ 32% 64k/200k`
- **[cost-and-duration](skills/cost-and-duration/)** — session cost estimate, wall-clock + API time, lines changed. `[Opus] $0.42  12m04s  api 2m10s  +156 -23`
- **[git-and-pr-state](skills/git-and-pr-state/)** — branch, staged/modified counts, open PR + review state (git calls cached 3s). `[Opus] main +2 ~5  PR #1234 (approved)`

**Patterns:**
- **[low-cpu-statusline-pattern](skills/low-cpu-statusline-pattern/)** — the "one session computes a shared value, every other terminal just reads it" recipe + a fill-in template. Use when a status line needs shared or expensive data; avoids the fork/exec storm that pins `sysmond` and lags typing.

**Hooks & notifications:**
- **[done-and-input-notifier](skills/done-and-input-notifier/)** — Stop + Notification hooks that fire a macOS desktop notification when a run finishes or needs your input.

**Permissions:**
- **[auto-allow-safe-bash](skills/auto-allow-safe-bash/)** — a conservative read-only Bash allowlist to stop prompting for `ls`, `git diff`, etc. Read-only only; nothing that writes or hits the network.

**Ergonomics:**
- **[session-namer](skills/session-namer/)** — a shell function that launches Claude with a session name from the folder + time, so multiple sessions are easy to tell apart.
- **[subagent-statusline](skills/subagent-statusline/)** — custom rows for the subagent panel (label, type, token count); composes with any status line.

## Composing status lines

Claude Code runs **one** `statusLine` command. The status-line skills above are drop-in alternatives — install one, or compose several by writing a wrapper that feeds the same JSON (`input=$(cat)`) to each segment and joins the output, or by printing multiple lines (each `echo`/`printf` line is a row). `subagent-statusline` is separate (`subagentStatusLine`) and always composes.

## Install

Copy a skill folder into your skills directory:

```sh
cp -R skills/plan-usage-statusline ~/.claude/skills/
```

Then follow that skill's `SKILL.md` for any extra setup (the status line skill also drops two scripts into `~/.claude/` and adds one entry to `settings.json`).

Each skill is self-contained under `skills/<name>/` — a `SKILL.md` plus its scripts/assets.

## License

MIT. The structure is free to copy, fork, and adapt.
