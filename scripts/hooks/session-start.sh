#!/usr/bin/env bash
# KIT-CLASS: KIT — SessionStart hook; clears .claude/session-role. See process/EXTRACTION.md.
# SessionStart hook.
#
# Wired in .claude/settings.json under hooks.SessionStart. On every session start
# the harness runs this and adds our stdout to the new session's context. Two jobs:
#   1. Clear .claude/session-role so each session must RE-CONFIRM its hat
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

# The repo-relative path of the role file. Kept as a named var on its OWN line so a
# test fixture can DERIVE it (sed) instead of re-hardcoding a literal — the same name
# and the same reason as the pre-tool hook's, because a guard that derives the path
# from one hook and finds a literal in the other cannot check the pair.
ROLE_REL=".claude/session-role"

# 1. Freshness — clear the declared hat.
rm -f "$ROOT/$ROLE_REL" 2>/dev/null || true

# 2. Board drift — surface it into context (stdout is added to the session).
if [ -x "$ROOT/scripts/check-board.sh" ]; then
  "$ROOT/scripts/check-board.sh" 2>&1 || true
fi

exit 0
