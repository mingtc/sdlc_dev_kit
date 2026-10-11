#!/usr/bin/env bash
# KIT-CLASS: KIT — SessionStart hook; clears the hat file. See process/EXTRACTION.md.
# SessionStart hook.
#
# Wired in .claude/settings.json.example under hooks.SessionStart (active once copied to
# .claude/settings.json). On every session start the harness runs this and adds our stdout to the
# new session's context. Two jobs:
#   1. Clear the hat file (path: scripts/lib/hat-file.sh) so each session must RE-CONFIRM its hat
#      (require-role.sh then blocks repo mutations until the new hat is declared).
#   2. Run scripts/check-board.sh so the NEW session opens with last session's
#      board-drift misses (unlogged moves, over-threshold columns, id collisions)
#      in context — the drift check paired with the freshness clear.
#
# FAIL-SOFT: a hook must never block a session start, so every step is best-effort
# and we always exit 0.
set -uo pipefail

# scripts/hooks/session-start.sh → repo root is two levels up. Prefer the harness's
# CLAUDE_PROJECT_DIR when present.
ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." 2>/dev/null && pwd || true)"
fi

# 1. Freshness — clear the declared hat. The path is the one lib's; with no lib there is no path
#    to clear, and the hook never blocks a session start.
# shellcheck source=../lib/hat-file.sh
if [ -r "$ROOT/scripts/lib/hat-file.sh" ]; then
  . "$ROOT/scripts/lib/hat-file.sh"
  [ -n "${KIT_HAT_FILE_REL:-}" ] && rm -f "$ROOT/$KIT_HAT_FILE_REL" 2>/dev/null
fi

# 2. Board drift — surface it into context (stdout is added to the session).
# The harness cuts a hook's stdout to a short preview above roughly 10,000 bytes, so the
# report is printed whole only up to OUT_BUDGET; past it, the arm headings and every finding
# line (⚠) are printed, cut at the budget, the verdict last, with the command for the full text.
OUT_BUDGET=8000
if [ -x "$ROOT/scripts/check-board.sh" ]; then
  REPORT="$("$ROOT/scripts/check-board.sh" 2>&1 || true)"
  if [ "$(printf '%s\n' "$REPORT" | LC_ALL=C wc -c | tr -d ' ')" -le "$OUT_BUDGET" ]; then
    printf '%s\n' "$REPORT"
  else
    VERDICT="$(printf '%s\n' "$REPORT" | LC_ALL=C grep -E '^── board-drift:' | tail -1)"
    NOTE="── check-board.sh: the full report is over this hook's ${OUT_BUDGET}-byte output budget; run scripts/check-board.sh for all of it. Arm headings and findings:"
    FIXED="$(printf '%s\n%s\n' "$NOTE" "$VERDICT" | LC_ALL=C wc -c | tr -d ' ')"
    printf '%s\n' "$NOTE"
    printf '%s\n' "$REPORT" | LC_ALL=C grep -vE '^── board-drift:' | LC_ALL=C grep -E '^\[[a-z][0-9]*\]|⚠' \
      | LC_ALL=C awk -v room="$((OUT_BUDGET - FIXED))" 'seen[$0]++ {next} {room -= length($0) + 1; if (room < 0) exit; print}' || true
    printf '%s\n' "$VERDICT"
  fi
fi

exit 0
