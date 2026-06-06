---
description: Open the Status Bar admin panel (status-bar configurator)
---

The user wants to open the **Status Bar** admin panel — the interactive full-screen configurator for their terminal status bar (toggle panels and features, live preview, save).

It is an interactive TUI, so it must run in the user's own terminal — the assistant's tool runner has no interactive TTY and cannot drive it. Reply with ONLY this: tell the user to launch the panel by typing, in the prompt,

    ! sb

(or `! ~/.claude/status-bar/configure.sh` if the `sb` alias isn't set yet). Note that arrow keys move, space toggles a panel / cycles the layout, **s** saves, and **Esc** or **q** returns to the main window. Do not run it yourself.
