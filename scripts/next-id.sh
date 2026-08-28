#!/usr/bin/env bash
# KIT-CLASS: KIT — next free issue id; prefix from config.sh. See process/EXTRACTION.md.
# Suggest the next issue id (e.g. <PREFIX>-034) — READ-ONLY, no side effects.
#
# It computes max(existing) + 1 across BOTH the live board (progress/** filenames)
# AND archived issues (ARCHIVE.md) — so the number does NOT reset to -001 after a
# milestone close moves issues out of progress/ into ARCHIVE.md.
#
# This is a SUGGESTION the agent consults, not authority. The creation scripts
# (new-issue.sh / new-bug.sh / new-refactor.sh) are stateless and take the number
# via --id; the agent runs this, sanity-checks it against its own context, and
# passes the chosen value. If this can't determine a number, it says so on stderr
# and exits non-zero — the agent then decides with context (and flags if unsure).
#
# THE EMPTY-BOARD REFUSAL IS THE CONTRACT, not a gap
# (process/contracts/id-minting.md): where no identifier has ever been issued,
# choosing where numbering starts is a DECISION, not an inference. So on a freshly
# initialized board this exits non-zero on purpose, and kit-init.sh prints the
# literal first id rather than composing this script into a recipe that must fail.
#
# Usage:   ./scripts/next-id.sh
# Example: ID=$(./scripts/next-id.sh) && ./scripts/new-issue.sh my-slug --id "$ID"

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh. ─────────────────────────
# This kit used to carry `: "${ISSUE_PREFIX:=<a literal>}"` here — a SECOND
# default below config.sh's own, so the script still ran with the seam missing.
# It was well meant, and it replaced something worse (a default carrying a
# FOREIGN project's prefix), so THE REASON SURVIVES: a silently wrong prefix is
# the expensive failure, not a missing one. The CONCLUSION is superseded, because
# the literal reproduced that very failure one level down — five scripts each
# holding their own copy of one project's prefix, so changing the prefix meant
# changing it in five places, and an unsourceable config.sh silently minted ids
# under a name nobody chose. So: NO fallback literal anywhere. config.sh is the
# only authority, and its absence is a refusal that NAMES it.
# The same block is in every script that grep returns — change one, change all.
CONFIG="$ROOT/scripts/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing or could not be sourced."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX / PRD_PREFIX / PROJECT_NAME"
    echo "       (process/contracts/config-seam.md). This script REFUSES to guess a"
    echo "       prefix: a guessed prefix mints ids under a name nobody chose, and the"
    echo "       board only finds out at the first move."
    echo "       Restore it (git checkout -- scripts/config.sh), or initialize the kit:"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
  } >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

# Highest number seen across live filenames + archived entries.
# - progress/** : full paths are fine to grep (the prefix-NNN only appears in the
#   filename, never the directory part), so spaces in the path don't matter.
# - ARCHIVE.md  : entries are "- <PREFIX>-NNN ..."; any in-text reference is to an
#   existing (<= max) issue, so scanning the whole file never over-counts.
max="$(
  {
    find "$ROOT/progress" -type f -name "${ISSUE_PREFIX}-*.md" 2>/dev/null
    [ -f "$ROOT/ARCHIVE.md" ] && cat "$ROOT/ARCHIVE.md"
  } 2>/dev/null \
    | grep -oE "${ISSUE_PREFIX}-[0-9]+" \
    | sed -E "s/^${ISSUE_PREFIX}-0*//" \
    | sort -n | tail -1
)"

if [ -z "$max" ]; then
  echo "next-id: no existing ${ISSUE_PREFIX}-NNN found in progress/ or ARCHIVE.md." >&2
  echo "         Pick a starting id with context (likely ${ISSUE_PREFIX}-001) and pass --id." >&2
  exit 1
fi

printf "${ISSUE_PREFIX}-%03d\n" "$(( max + 1 ))"
