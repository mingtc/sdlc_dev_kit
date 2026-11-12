#!/usr/bin/env bash
# KIT-CLASS: KIT — SessionStart hook; clears the hat file. See process/EXTRACTION.md.
# SessionStart hook. The harness calls it bare: it ignores its arguments, so `--help` runs it (clearing the hat file).
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
# report is printed whole only up to OUT_BUDGET. Past it the hook keeps, in this order of claim on the
# budget: the lines it must not lose (every arm heading, every finding line (⚠), the graduation arm's
# `hooks:` and `→ graduation` lines, every `↳ … status 3` line, the one line naming the arms that found
# nothing) — their size is set aside first — and then the body of each `[+name]` arm (a module's or an
# adopter's arm signals a finding in its own words, so none of its lines can be told from a quiet one).
# The body of an arm that returned 3 is kept from its status line backwards, newest first, because an
# arm prints its findings last and its status line after them; the rest is kept in report order while
# room lasts, and a section cut short says so. The verdict is last, with the command for the full text.
# check-board.sh prints its findings first, so the cut falls on the quiet end of the report.
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
    printf '%s\n' "$REPORT" | LC_ALL=C grep -vE '^── board-drift:' \
      | LC_ALL=C awk -v room="$((OUT_BUDGET - FIXED))" '
          function add(kd, t) { if (kd == "M") { if (t in seen) return; seen[t] = 1 } k++; txt[k] = t; kind[k] = kd; secof[k] = sec }
          /^[[:space:]]*$/ { next }
          /^── no findings, folded/ { plus = 0; sec = 0; add("M", $0); next }
          /^\[\+[A-Za-z0-9._-]+\]/ { plus = 1; nsec++; sec = nsec; add("M", $0); next }
          /^\[[a-z][0-9]*\]/ { plus = 0; sec = 0; add("M", $0); next }
          /⚠/ || /^[[:space:]]*(hooks:|→ graduation|↳ )/ { add("M", $0); if ($0 ~ /↳/ && sec) st[sec] = k; next }
          plus { add("O", $0) }
          END {
            marker = "      … (lines of this arm not shown; run scripts/check-board.sh --full)"
            must = 0
            for (j = 1; j <= k; j++) { if (kind[j] == "M") must += length(txt[j]) + 1; else hasO[secof[j]] = 1 }
            rest = room - must
            for (s in hasO) rest -= length(marker) + 1
            for (pass = 1; pass <= 2; pass++) for (s = 1; s <= nsec; s++) if (st[s]) {
              if (pass == 1) pos[s] = st[s] - 1
              got = 0
              for (j = pos[s]; j >= 1 && secof[j] == s; j--) {
                if (kind[j] != "O") continue
                if (rest < length(txt[j]) + 1) { pos[s] = 0; break }
                keep[j] = 1; rest -= length(txt[j]) + 1; pos[s] = j - 1
                if (pass == 1 && ++got >= 8) break
              }
            }
            for (s = 1; s <= nsec; s++) if (!st[s]) {
              for (j = 1; j <= k; j++) {
                if (secof[j] != s || kind[j] != "O") continue
                if (rest < length(txt[j]) + 1) break
                keep[j] = 1; rest -= length(txt[j]) + 1
              }
            }
            mroom = (must <= room) ? must : room
            for (j = 1; j <= k; j++) {
              if (kind[j] == "M") { mroom -= length(txt[j]) + 1; if (mroom < 0) exit; print txt[j]; continue }
              if (keep[j]) { print txt[j]; continue }
              if (!said[secof[j]]) { said[secof[j]] = 1; print marker }
            }
          }' || true
    printf '%s\n' "$VERDICT"
  fi
fi

exit 0
