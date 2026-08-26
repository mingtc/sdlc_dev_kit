#!/usr/bin/env bash
# KIT-CLASS: KIT — the hat gate; PreToolUse hook. See process/EXTRACTION.md.
# Role-declaration gate (PreToolUse: Edit|Write|NotebookEdit).
#
# The manual's § Execution discipline rule 1: "Confirm the hat before changing
# anything." This hook is the mechanical enforcement. Wired in .claude/settings.json
# under hooks.PreToolUse (matcher "Edit|Write|NotebookEdit"); the harness feeds the
# tool-call payload as JSON on stdin and interprets our exit code:
#   • exit 0 → allow the tool call
#   • exit 2 → BLOCK the tool call; our stderr is fed back to the agent
#   • any other non-zero → non-blocking error (the call still proceeds)
#
# Behaviour:
#   • .claude/session-role EXISTS            → allow (the hat is declared).
#   • target is .claude/session-role itself  → allow (BOOTSTRAP: the agent must be
#                                              able to CREATE the role file, else the
#                                              gate is a permanent deadlock).
#   • target is OUTSIDE the repo (scratchpad)→ allow (not our concern).
#   • target is UNDER the repo, no role file → BLOCK (exit 2 + instructive stderr).
#
# A HAT DECLARATION IS SESSION STATE, NEVER REPOSITORY CONTENT
# (process/contracts/role-gate.md § 2). `.claude/session-role` is gitignored by
# kit-init.sh for a measured reason: tracked, it forks per branch, blocks a
# boundary `git switch` with "local changes would be overwritten", and reaches a
# landing gate as a merge conflict over a fact nobody was collaborating on. Four
# agents paid for that in one twelve-hour transplant; one hit the conflict.
#
# SAFETY: the "role file exists → allow" check runs FIRST and unconditionally, before
# any payload parsing, so a parse bug can never lock out a session that HAS declared
# its hat. And if we cannot determine the target path at all, we FAIL-OPEN (allow) —
# never hard-block on a payload we don't understand.
set -uo pipefail

# The repo-relative path of the role file. Kept as a named var on its OWN line so a
# test fixture can DERIVE it (sed) instead of re-hardcoding a literal.
ROLE_REL=".claude/session-role"

# Repo root: the harness exports CLAUDE_PROJECT_DIR for hook commands; prefer it.
# Fall back to this script's location (scripts/hooks/require-role.sh → repo root is
# two levels up). Canonicalize with `pwd -P` so the prefix test below compares
# physical paths consistently on both sides (symlink/FUSE mounts resolve the same).
REPO_ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." 2>/dev/null && pwd -P || true)"
fi
REPO_ROOT="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P || printf '%s' "$REPO_ROOT")"
ROLE_FILE="$REPO_ROOT/$ROLE_REL"

# Drain the JSON payload the harness feeds on stdin (consume it whether or not we
# end up parsing, so the harness's write completes cleanly).
payload="$(cat 2>/dev/null || true)"

# ── ALLOW #1 — the hat is declared. FIRST + unconditional (bulletproof).
if [ -n "$REPO_ROOT" ] && [ -e "$ROLE_FILE" ]; then
  exit 0
fi

# Extract the mutation target: Edit/Write → .tool_input.file_path;
# NotebookEdit → .tool_input.notebook_path. jq preferred, python3 fallback, then a
# best-effort grep (only if both are absent). cwd (for a rare relative path) too.
target=""
cwd=""
if command -v jq >/dev/null 2>&1; then
  target="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
fi
if [ -z "$target" ] && command -v python3 >/dev/null 2>&1; then
  target="$(printf '%s' "$payload" | python3 -c 'import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input", {}) or {}
    sys.stdout.write(str(ti.get("file_path") or ti.get("notebook_path") or ""))
except Exception:
    pass' 2>/dev/null || true)"
fi
if [ -z "$target" ]; then
  target="$(printf '%s' "$payload" \
    | grep -oE '"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"$/\1/' || true)"
fi

# ── ALLOW (fail-open) — no determinable target or no repo root → nothing to gate.
if [ -z "$target" ] || [ -z "$REPO_ROOT" ]; then
  exit 0
fi

# Resolve the target to an absolute, canonical path. It may not exist yet (a Write of
# a brand-new file, possibly in a brand-new subdir), so canonicalize the NEAREST
# EXISTING ANCESTOR physically (`pwd -P`) and re-attach the not-yet-existing tail —
# otherwise a literal /var vs canonical /private/var mismatch would break the
# under-repo prefix test against a `pwd -P` repo root.
abs="$target"
case "$abs" in
  /*) ;;
  *)  [ -z "$cwd" ] && cwd="$PWD"
      abs="$cwd/$abs" ;;
esac
probe="$abs"
tail=""
while [ ! -d "$probe" ] && [ "$probe" != "/" ] && [ -n "$probe" ]; do
  tail="$(basename "$probe")${tail:+/}$tail"
  probe="$(dirname "$probe")"
done
canon_base="$(cd "$probe" 2>/dev/null && pwd -P || true)"
[ -n "$canon_base" ] && abs="${canon_base%/}${tail:+/}$tail"

# ── ALLOW #2 — bootstrap exemption: writing the role file itself is always allowed
#    (otherwise the agent could never create it → permanent deadlock).
if [ "$abs" = "$ROLE_FILE" ]; then
  exit 0
fi

# ── ALLOW #3 — target is outside the repo (e.g. the scratchpad) → not gated.
case "$abs" in
  "$REPO_ROOT"/*) ;;   # under repo → fall through to BLOCK
  *) exit 0 ;;
esac

# ── BLOCK — a repo file mutation with no declared hat. exit 2 → stderr to the agent.
{
  echo "✗ Role-declaration gate: no $ROLE_REL — refusing to mutate a repo file."
  echo ""
  echo "  Target: $abs"
  echo ""
  echo "  Confirm your hat BEFORE changing anything (the manual's § Execution discipline):"
  echo "    write $ROLE_REL with a single line:  <Role> <scope>"
  echo "      e.g.  Dev <PREFIX>-001"
  echo "    (or — ONLY when the operator explicitly waived the hat —"
  echo "     none — operator override: <reason>)"
  echo ""
  echo "  Then retry the edit. Read-only work needs no role; paths outside the repo are never gated."
} >&2
exit 2
