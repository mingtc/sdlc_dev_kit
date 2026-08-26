#!/usr/bin/env bash
# KIT-CLASS: KIT — the configuration seam itself — edit the prefixes, take the rest as-is. See process/EXTRACTION.md.
# Configuration for the kanban + roles scripts. Sourced by every script that needs
# to know the project's prefix conventions.
#
# THIS FILE IS THE SEAM. Every value a kanban script needs but cannot derive is
# declared here, once. The rule (process/contracts/config-seam.md § 3): if a
# consumer needs a value this seam does not define, that is a GAP IN THE SEAM, and
# it is fixed by adding it here rather than by hard-coding it at the call site.
#
# `scripts/kit-init.sh` stamps ISSUE_PREFIX, PRD_PREFIX and PROJECT_NAME on day
# one; after that, edit them here. A change takes effect on the next script
# invocation — existing files are NOT renamed.
#
# Override at runtime via env var, e.g.:
#   ISSUE_PREFIX=TEST ./scripts/new-issue.sh foo
#
# The kanban worktree scripts resolve the TRUNK (default branch) from
# <remote>/HEAD — see scripts/lib/kanban-worktree.sh's kwt_resolve(), and state
# your trunk in the project adapter (CLAUDE.md § "The trunk"). It is deliberately
# NOT a knob here: a repository has exactly one answer and git already holds it.

# Issue / bug prefix. Used by new-issue.sh, new-bug.sh, new-refactor.sh,
# next-id.sh, archive.sh. Generated filenames look like ${ISSUE_PREFIX}-001-<slug>.md.
#
# `KIT` is the SHIPPED PLACEHOLDER, not a recommendation — kit-init.sh derives the
# old value from this very line so it can rewrite the templates' example ids, so
# the placeholder must be alphanumeric and start with a letter (an <angle-bracket>
# blank would break that derivation). Replace it with your own two-to-five-letter
# prefix on day one: ./scripts/kit-init.sh --prefix XYZ --trunk main
ISSUE_PREFIX="${ISSUE_PREFIX:-KIT}"

# PRD prefix. Used by new-prd.sh.
# Generated filenames look like ${PRD_PREFIX}-001-<slug>.md.
# The default `PRD` is fine for most projects.
PRD_PREFIX="${PRD_PREFIX:-PRD}"

# Project name — the name the role docs and the templates spell out in prose.
# Declared HERE for the seam rule stated in the header. kit-init.sh reads this
# default to learn what name the travelling docs currently carry, which is what
# lets it rewrite them and then COUNT what it left behind instead of promising a
# clean search. That census is the whole reason this value is a seam and not a
# literal scattered through the docs: a transplant that CLAIMED to be clean has
# been measured leaving hundreds of the donor's own tokens behind.
PROJECT_NAME="${PROJECT_NAME:-<project-name>}"

# Validate a caller-supplied issue id and check for collisions (read-only; no
# side effects). The new-* creation scripts are STATELESS: the caller (the agent,
# which has context the scripts don't) determines the next number — typically via
# ./scripts/next-id.sh — and passes it as --id. This just guards the input.
#   Usage:  validate_issue_id "$ID" "$ROOT"   # uses ISSUE_PREFIX; returns non-0 on a hard error
validate_issue_id() {
  local id="$1" root="$2" existing
  if [ -z "$id" ]; then
    echo "Error: --id is required (e.g. --id ${ISSUE_PREFIX}-034)." >&2
    echo "       Get the next id with:  ./scripts/next-id.sh   (then sanity-check it)." >&2
    echo "       These scripts are stateless — the caller passes the number in." >&2
    return 1
  fi
  if ! printf '%s' "$id" | grep -qE "^${ISSUE_PREFIX}-[0-9]+$"; then
    echo "Error: --id '$id' must look like ${ISSUE_PREFIX}-NNN." >&2
    return 1
  fi
  # Hard collision: this id is already a live file anywhere under progress/.
  existing="$(find "$root/progress" -type f -name "${id}-*.md" 2>/dev/null | head -1)"
  if [ -n "$existing" ]; then
    echo "Error: ${id} already exists at ${existing#"$root"/}." >&2
    return 1
  fi
  # Soft collision: this id appears in ARCHIVE.md (an archived issue used it).
  if [ -f "$root/ARCHIVE.md" ] && grep -qE "(^|[^A-Za-z0-9])${id}([^0-9]|\$)" "$root/ARCHIVE.md" 2>/dev/null; then
    echo "Warning: ${id} appears in ARCHIVE.md — it may already belong to an archived issue." >&2
    echo "         Proceeding; ensure this is intentional (./scripts/next-id.sh suggests the next free id)." >&2
  fi
  return 0
}

# THE PUSH-BEFORE-YOU-MOVE TRAP, replicated THREE times independently by three
# different agents on their first day with this kit — the same twenty minutes lost
# each time.
#
# A creation script writes a file into the OPERATOR'S checkout; move-issue.sh reads
# the board inside .kanban-wt/, which is `reset --hard <remote>/<trunk>` on every
# op. So a minted-but-unpushed file is INVISIBLE to the mover, which reports
# "no file matching <ID>-*.md found under progress/" — a true statement with an
# unfindable cause.
#
# POSTURE: PRINT, NOT PERFORM — decided here, once, for every creation script.
# process/contracts/issue-creation.md § 2 makes creation INERT ("it writes the new
# item and nothing else: no state change, no publication"), and § 4.3 makes
# "nothing else changed" the definition of green. A creation script that committed
# and pushed would violate its own contract sheet, and would publish drafts nobody
# had read yet. So the fix is to make the step UNMISSABLE, not automatic.
#
#   Usage:  print_push_before_move "<path/to/created/file.md>"
print_push_before_move() {
  local path="${1:-}" rel
  # `${BASH_SOURCE[0]:-$0}`, never the bare form: THIS FILE IS SOURCED, and the
  # bare form is empty in any shell that does not set BASH_SOURCE. Measured
  # 2026-08-26: under `set -u` (which all three callers run) the expansion below
  # then fails and THIS WARNING NEVER PRINTS — silently skipped, after the card
  # has already been created, which is the exact created-but-unpushed trap this
  # function exists to prevent. The message is the whole point, so the fallback
  # only has to keep it ALIVE: where `$0` resolves to something other than this
  # file's directory the path prints unshortened, which is a cosmetic loss and
  # the correct trade against silence. Latent under the kit's own paths (the
  # three callers are bash-executed, so BASH_SOURCE is always populated there) —
  # fixed because it is reachable, one line, and the last member of its class.
  # The guarded sites are derivable — `grep -rn 'BASH_SOURCE\[0\]:-\$0' scripts`
  # — deliberately not written here as a number.
  rel="${path#"$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/"}"
  echo ""
  echo "  ⚠ PUSH IT BEFORE YOU MOVE IT. ./scripts/move-issue.sh reads the board from the"
  echo "    trunk (via the .kanban-wt worktree), so a file that exists only in this"
  echo "    checkout is invisible to it — the move fails with 'no file matching'."
  echo ""
  echo "      git add \"${rel}\" && git commit -m \"[<Role>] <ID>: mint\" && git push"
  echo ""
  echo "    Then, and only then:  ./scripts/move-issue.sh <ID> in_progress --role <Role> --note \"…\""
}
