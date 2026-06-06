#!/bin/bash
# TEMPLATE — a low-CPU status line where ONE session computes a shared value and
# every other terminal just reads it. Copy this, fill in the two marked spots.
#
# Use this pattern when the status line needs data that is (a) the same across
# sessions and/or (b) expensive to compute. Without it, every terminal recomputes
# the same thing on every tick — and at a 1s refresh across several windows that
# fork/exec storm pins macOS's process monitor (sysmond) and lags your typing.
#
# The three rules:
#   1. CHEAP READ every tick: read a cached value and print it (pure bash; no jq,
#      no external work). This is what every "pulling" terminal does.
#   2. ONE REFRESH per interval: whichever tick finds the cache older than
#      REFRESH seconds rebuilds it. Others find it fresh and skip. So adding
#      terminals does not multiply the heavy work.
#   3. ATOMIC WRITE: write to a temp file and mv into place, so a reader never
#      sees a half-written cache.

input=$(cat)
CACHE="$HOME/.claude/MYMETRIC-synced"     # <-- name your cache
REFRESH=8                                  # seconds between shared rebuilds
now=$(date +%s)

# --- cheap read (every terminal, every tick) ---
ts=0; VALUE=""
IFS=$'\t' read -r ts VALUE < "$CACHE" 2>/dev/null
ts=${ts:-0}

# --- one session rebuilds when stale ---
if [ ! -r "$CACHE" ] || [ $(( now - ts )) -ge "$REFRESH" ]; then
  # ===== SPOT 1: compute your (possibly expensive) value here =====
  # e.g. aggregate files, call a CLI once, hit an API once. Keep it here so it
  # runs at most once per REFRESH across ALL terminals.
  VALUE="replace-me"
  # ===============================================================
  printf '%s\t%s\n' "$now" "$VALUE" > "$CACHE.tmp.$$" && mv -f "$CACHE.tmp.$$" "$CACHE"
fi

# --- render (pure bash; no spawns beyond the one `date` above) ---
# ===== SPOT 2: format VALUE for display (bars, colours, etc.) =====
printf 'metric: %s' "$VALUE"
# =================================================================
