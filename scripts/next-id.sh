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
# shellcheck source=lib/refuse.sh
. "$ROOT/scripts/lib/refuse.sh"

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
  *) echo "Error: unknown option: $1 (next-id.sh takes none)" >&2; exit 2 ;;   # exit-class: usage
esac

CONFIG="$ROOT/scripts/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  kit_refuse 1 config-seam-missing \
    "Error: scripts/config.sh is missing." \
    "       Looked for: $CONFIG" \
    "       It is the ONE authority for ISSUE_PREFIX / PRD_PREFIX / PROJECT_NAME" \
    "       (process/contracts/config-seam.md). This script REFUSES to guess a" \
    "       prefix: a guessed prefix mints ids under a name nobody chose, and the" \
    "       board only finds out at the first move." \
    "Next: restore it (git checkout -- scripts/config.sh) — the way back on a tree that HAD it." \
    "       ON A FRESH REPO, initialize the kit instead (it refuses one that has already lived):" \
    "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>" \
    "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  kit_refuse 1 prefix-empty \
    "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." \
    "Next: set ISSUE_PREFIX in scripts/config.sh to your project's prefix, then re-run."
fi

# THE TRUNK (kit_trunk_ref, scripts/config.sh). No ref (day one, local-only): this checkout.
rc=0; TRUNK_REF="$(kit_trunk_ref "$ROOT")" || rc=$?
case "$rc" in
  0) echo "next-id: read this checkout and $TRUNK_REF @ $(git -C "$ROOT" rev-parse --short "refs/remotes/$TRUNK_REF") (not fetched)" >&2 ;;
  3) echo "next-id: read this checkout only — no $TRUNK_REF ref" >&2; TRUNK_REF="" ;;
  *) kit_refuse 1 trunk-unresolvable \
       "Error: next-id could not resolve the trunk of this repository." \
       "Next: run it from inside the project's git checkout; if the remote has no HEAD, settle the trunk once:  git remote set-head origin <your-trunk>." ;;
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
  kit_refuse 1 no-existing-id \
    "next-id: no existing ${ISSUE_PREFIX}-NNN found in progress/ or ARCHIVE.md." \
    "Next: pick a starting id with context (likely ${ISSUE_PREFIX}-001) and pass --id."
fi

printf "${ISSUE_PREFIX}-%03d\n" "$(( max + 1 ))"
