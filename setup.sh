#!/usr/bin/env bash
# KIT-CLASS: MIXED — the KIT half below is real and working (git hooks, the board sanity check,
# the .env seed); the RUNTIME half is a marked fill-in that only you can write. See
# process/EXTRACTION.md.
#
# setup.sh — the one front door for a fresh clone of this repository.
#
# Two halves, in this order:
#
#   1. THE KIT HALF (real, working, idempotent, language-agnostic)
#        - wire the commit-message role-prefix guard (core.hooksPath)
#        - sanity-check the board: the status folders, progress.md § Log, ARCHIVE.md § Archived,
#          the configuration seam
#        - seed .env from .env.example on first run (never overwrites; .env is gitignored)
#
#   2. THE RUNTIME HALF (a fill-in — see the fenced block marked FILL ME)
#        - install your language's toolchain / dependencies
#        - run your test gate once as a sanity check
#
# Bash + git only. Safe to re-run.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"

log()  { printf '%s\n' "$*" >&2; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
setup.sh — prepare a fresh clone for work.

USAGE:
  ./setup.sh              Wire the hooks, check the board, seed .env, bootstrap the runtime.
  ./setup.sh --kit-only   Run only the kit half (no runtime bootstrap, no gate run).
  ./setup.sh --help       This text.

Idempotent: re-running is safe and re-checks everything.
EOF
}

KIT_ONLY=false
case "${1:-}" in
  -h|--help)  usage; exit 0 ;;
  --kit-only) KIT_ONLY=true ;;
  "")         ;;
  *)          die "Unknown argument '$1'. See ./setup.sh --help." ;;
esac

FAILURES=0
note_fail() { warn "$*"; FAILURES=$((FAILURES + 1)); }

# =============================================================================
# 1. THE KIT HALF — real, working, and the same in every project.
# =============================================================================

log "── Kit setup ────────────────────────────────────────────────────────────"

# --- 1a. The commit-message role-prefix guard -------------------------------
# hooksPath lives in the shared .git/config, so the guard is active from EVERY
# worktree — including the auxiliary trunk checkout the board scripts commit from.
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -f "$ROOT/scripts/githooks/commit-msg" ]; then
    chmod +x "$ROOT/scripts/githooks"/* 2>/dev/null || true
    git -C "$ROOT" config core.hooksPath scripts/githooks
    log "✓ git hooks wired: core.hooksPath = scripts/githooks (commit-message role-prefix guard)."
  else
    note_fail "scripts/githooks/commit-msg is missing — the role-prefix guard cannot be wired."
  fi
else
  note_fail "$ROOT is not a git repository — run 'git init' first (see README § Day one)."
fi

# --- 1b. The board sanity check --------------------------------------------
# The folder IS the status, so a missing folder is a missing status. Two headings
# are read by scripts and are checked here for the same reason.
STATUS_FOLDERS="todo in_progress dev_complete qa_complete blocked done history"
for f in $STATUS_FOLDERS; do
  if [ -d "$ROOT/progress/$f" ]; then
    [ -e "$ROOT/progress/$f/.gitkeep" ] || warn "progress/$f/ has no .gitkeep — git will drop it when it empties."
  else
    note_fail "progress/$f/ is missing — the board is incomplete."
  fi
done

if [ -f "$ROOT/progress.md" ]; then
  grep -qE '^##[[:space:]]+Log' "$ROOT/progress.md" \
    || note_fail "progress.md has no '## Log' heading — the drift report probes for it."
else
  note_fail "progress.md is missing."
fi

if [ -f "$ROOT/ARCHIVE.md" ]; then
  grep -qE '^##[[:space:]]+Archived[[:space:]]*$' "$ROOT/ARCHIVE.md" \
    || note_fail "ARCHIVE.md has no '## Archived' heading — the archive sweep inserts beneath it."
else
  note_fail "ARCHIVE.md is missing."
fi

[ -f "$ROOT/scripts/config.sh" ] \
  || note_fail "scripts/config.sh is missing — the configuration seam (prefix, PRD prefix, project name)."

if [ -f "$ROOT/scripts/verify.sh" ]; then
  [ -x "$ROOT/scripts/verify.sh" ] \
    || note_fail "scripts/verify.sh is not executable — the landing gate refuses on exactly that (chmod +x it)."
else
  warn "no scripts/verify.sh yet — the landing gate REFUSES to land without an executable, committed gate runner."
  warn "      Create it with: ./scripts/kit-init.sh --gate-command '<your test command>'  (or write it by hand.)"
fi

if [ "$FAILURES" -eq 0 ]; then log "✓ board sanity check passed."; fi

# --- 1c. Seed .env on first run --------------------------------------------
# .env is gitignored and MUST NEVER be committed. Only .env.example is tracked.
ENV_SEEDED=false
if [ ! -f "$ROOT/.env" ] && [ -f "$ROOT/.env.example" ]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  ENV_SEEDED=true
  log "✓ seeded .env from .env.example — fill it in; it is gitignored and never committed."
fi

if [ "$KIT_ONLY" = true ]; then
  log ""
  log "Kit half done (--kit-only). Runtime bootstrap skipped."
  [ "$FAILURES" -eq 0 ] || die "$FAILURES kit problem(s) above."
  exit 0
fi

# =============================================================================
# 2. THE RUNTIME HALF — <fill: your language runtime bootstrap + your test gate>
# =============================================================================
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ FILL ME. Everything between the two FILL markers is a placeholder. Until │
# │ it is written, `./setup.sh` prepares the process but not the project.    │
# │                                                                          │
# │ WHAT MUST GO HERE, and nothing else:                                     │
# │   1. Install the toolchain's dependencies into a project-local, throwaway │
# │      location, from the committed lockfile — not globally, and not from   │
# │      whatever the network has today. Isolation is what makes this         │
# │      idempotent and a contributor's machine reproducible.                │
# │   2. Run the test gate ONCE and report PASS/FAIL, without aborting the    │
# │      script: a red suite on a fresh clone is information, and swallowing  │
# │      it is how a broken trunk stays unnoticed. Prefer invoking            │
# │      `./scripts/verify.sh` so there is exactly ONE definition of "the     │
# │      gate" (process/contracts/verify-gate.md) rather than a second one    │
# │      here that will drift.                                               │
# │                                                                          │
# │ WHAT MUST NOT GO HERE:                                                   │
# │   • Anything that reaches a live external system, mutates real data, or   │
# │     needs a credential to succeed. Setup runs on an unconfigured machine. │
# │   • A second copy of the gate's command list. One runner, one order.      │
# │   • Anything non-idempotent. This script is re-run, often.                │
# │                                                                          │
# │ Keep it honest: if a step cannot be automated, print the manual           │
# │ instruction rather than pretending it ran.                                │
# └──────────────────────────────────────────────────────────────────────────┘

log ""
log "── Runtime setup ────────────────────────────────────────────────────────"

# ---------------------------- FILL: BEGIN ------------------------------------
#
# Example shapes, for orientation only — delete the one you do not use and
# replace it with the real thing. NONE of these run as shipped.
#
#   # a compiled language with a lockfile:
#   command -v <toolchain> >/dev/null 2>&1 || die "<toolchain> not found — install it first."
#   <toolchain> <install-from-lockfile-command>
#
#   # an interpreted language with a project-local environment:
#   [ -d "$ROOT/<env-dir>" ] || <toolchain> <create-env-command> "$ROOT/<env-dir>"
#   "$ROOT/<env-dir>/<bin>/<installer>" <install-from-lockfile-command>
#
RUNTIME_READY=false
GATE="not run — the runtime half of setup.sh is still a fill-in"

if [ "$RUNTIME_READY" = false ]; then
  warn "runtime bootstrap is NOT IMPLEMENTED — setup.sh § 'THE RUNTIME HALF' is still a fill-in."
  warn "      Write it before the first issue; see the FILL ME block in this file."
else
  # Run the gate through the ONE runner, so there is no second definition of it.
  if [ -x "$ROOT/scripts/verify.sh" ]; then
    if "$ROOT/scripts/verify.sh"; then GATE="verify.sh: PASS"; else GATE="verify.sh: FAIL — investigate before you start work"; fi
  else
    GATE="not run — no executable scripts/verify.sh"
  fi
fi
# ----------------------------- FILL: END -------------------------------------

# =============================================================================
# The closing report.
# =============================================================================

ENV_NOTE="gitignored"
if [ "$ENV_SEEDED" = true ]; then ENV_NOTE="gitignored; just seeded from .env.example"; fi

cat >&2 <<EOF

────────────────────────────────────────────────────────────────────────────
Setup complete.   Gate: $GATE

The board:            ls progress/todo/  ;  ./scripts/check-board.sh
Operating manual:     process/MANUAL.md
This project's law:   CLAUDE.md      ·      project facts: PROJECT.md
Credentials:          .env ($ENV_NOTE)
────────────────────────────────────────────────────────────────────────────
EOF

if [ "$FAILURES" -gt 0 ]; then
  die "$FAILURES kit problem(s) reported above — fix them before starting work."
fi
