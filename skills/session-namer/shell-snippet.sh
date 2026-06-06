# Add to ~/.zshrc or ~/.bashrc.
# Launch Claude Code with a session name derived from the folder + time,
# e.g. ~/projects/checkout -> "checkout-1432". Extra args pass through.
cc() {
  claude --name "${PWD##*/}-$(date +%H%M)" "$@"
}
