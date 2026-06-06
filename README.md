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

### plan-usage-statusline
A status line showing your Claude plan usage — current 5-hour session and weekly (All-Models) windows — as compact coloured bars with reset times:

```
SESSION ▓▓▓▓░░░░░░ 42% 2h13m   WEEKLY ▓▓░░░░░░░░ 24% Fri 13:00
```

One row that wraps to two when the terminal is narrow. The value is synced to a single number across every terminal and session, and it costs almost no CPU: one session computes the shared value, every other terminal just reads it. Requires a Pro/Max plan and Claude Code v2.1.153+. See [`skills/plan-usage-statusline/SKILL.md`](skills/plan-usage-statusline/SKILL.md).

## Install

Copy a skill folder into your skills directory:

```sh
cp -R skills/plan-usage-statusline ~/.claude/skills/
```

Then follow that skill's `SKILL.md` for any extra setup (the status line skill also drops two scripts into `~/.claude/` and adds one entry to `settings.json`).

Each skill is self-contained under `skills/<name>/` — a `SKILL.md` plus its scripts/assets.

## License

MIT. The structure is free to copy, fork, and adapt.
