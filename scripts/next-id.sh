#!/usr/bin/env bash
# KIT-CLASS: KIT — next free issue id; prefix from config.sh. See process/EXTRACTION.md.
# Suggest the next issue id (e.g. <PREFIX>-034) — READ-ONLY, no side effects.
#
# Computes max(existing) + 1 across the live board (progress/** filenames) AND ARCHIVE.md, so
# numbering does not reset after a milestone close — in this checkout AND on <remote>/<trunk>, so
# a branch cut before a trunk mint does not repeat it. The ref is read as last fetched, never
# fetched, and named on stderr.
#
# A SUGGESTION, not authority: the creation scripts are stateless and take --id; the agent
# sanity-checks this and passes its choice. If no number can be determined it says so on
# stderr and exits non-zero.
#
# THE EMPTY-BOARD REFUSAL IS THE CONTRACT (process/contracts/id-minting.md): where no id has
# ever been issued, where numbering starts is a decision, not an inference.
#
# Usage:   ./scripts/next-id.sh
# Example: ID=$(./scripts/next-id.sh) && ./scripts/new-issue.sh my-slug --id "$ID"

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh — as new-issue.sh states; change one, change all.
# Arguments are read first (issue-creation.md § 3): a usage request always succeeds, in any
# position, and must never print a mintable id; anything else exits 2.
for _a in "$@"; do
  case "$_a" in
    -h|--help)
      echo "usage: next-id.sh"
      echo ""
      echo "  Prints the next free issue id — max(board, ARCHIVE.md) + 1, over this checkout"
      echo "  and <remote>/<trunk> as last fetched. READ-ONLY, and"
      echo "  a SUGGESTION rather than an allocation: the creation scripts take --id."
      echo "  Takes no options."
      exit 0 ;;
  esac
done
case "${1:-}" in
  "") ;;
  *) echo "Error: unknown option: $1 (next-id.sh takes none)" >&2; exit 2 ;;
esac

CONFIG="$ROOT/scripts/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX / PRD_PREFIX / PROJECT_NAME"
    echo "       (process/contracts/config-seam.md). This script REFUSES to guess a"
    echo "       prefix: a guessed prefix mints ids under a name nobody chose, and the"
    echo "       board only finds out at the first move."
    echo "       Restore it (git checkout -- scripts/config.sh) — the way back on a tree that HAD it."
      echo "       ON A FRESH REPO, initialize the kit instead (it refuses one that has already lived):"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
    echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
  } >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

# THE TRUNK (kit_trunk_ref, scripts/config.sh). No ref (day one, local-only): this checkout.
rc=0; TRUNK_REF="$(kit_trunk_ref "$ROOT")" || rc=$?
case "$rc" in
  0) echo "next-id: read this checkout and $TRUNK_REF @ $(git -C "$ROOT" rev-parse --short "refs/remotes/$TRUNK_REF") (not fetched)" >&2 ;;
  3) echo "next-id: read this checkout only — no $TRUNK_REF ref" >&2; TRUNK_REF="" ;;
  *) exit 1 ;;
esac

# Highest number seen across live filenames + archived entries.
# - progress/** : the FILENAME only — a checkout under a directory named like an id is not an id.
# - ARCHIVE.md  : entries are "- <PREFIX>-NNN ..."; any in-text reference is to an
#   existing (<= max) issue, so scanning the whole file never over-counts.
max="$(
  {
    find "$ROOT/progress" -type f -name "${ISSUE_PREFIX}-*.md" 2>/dev/null | sed 's|.*/||'
    [ -f "$ROOT/ARCHIVE.md" ] && cat "$ROOT/ARCHIVE.md"
    if [ -n "$TRUNK_REF" ]; then
      git -C "$ROOT" ls-tree -r --name-only "refs/remotes/$TRUNK_REF" -- progress
      git -C "$ROOT" show "refs/remotes/$TRUNK_REF:ARCHIVE.md"
    fi
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
