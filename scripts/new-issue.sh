#!/usr/bin/env bash
# KIT-CLASS: KIT — issue creation from the kit templates. See process/EXTRACTION.md.
# Create a new feature/spike/chore issue file in progress/todo/ from the
# ISSUE template, with pre-filled id, created_at, branch, and optionally
# prd and stories frontmatter.
#
# Usage:   ./scripts/new-issue.sh <slug> --id <PREFIX>-NNN [--prd PRD-NNN] [--stories ID1,ID2,...]
# Example: ID=$(./scripts/next-id.sh) && ./scripts/new-issue.sh reader-config-flag \
#            --id "$ID" --prd PRD-001 --stories PRD-001-F1-S1,PRD-001-F1-S2
#
# The id is REQUIRED and passed in — this script is stateless (it does not guess
# the next number). Get it from ./scripts/next-id.sh, sanity-check it, pass --id.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

TEMPLATE="$ROOT/.claude/templates/ISSUE.template.md"
DEST_DIR="$ROOT/progress/todo"

usage() {
  echo "Usage: $(basename "$0") <slug> --id ${ISSUE_PREFIX}-NNN [--prd ${PRD_PREFIX:-PRD}-NNN] [--stories ID1,ID2,...]"
  echo "  --id is required; get it from ./scripts/next-id.sh and sanity-check it."
  echo "  -h, --help    this text (exit 0)."
}

# A LEADING '-' IS NEVER A NAME (process/contracts/issue-creation.md § 3). The
# incident: a creation script took `--help` as the slug, minted an item under a
# nonsense name, burned a real id — and printed "Created:". An acceptance WITH a
# success message is the worst shape available, which is why "it looked right" is
# exactly the evidence that failed. Three behaviours, uniform across every
# creation script: --help exits 0, a dash-leading positional refuses with rc=2,
# an unknown option refuses with rc=2.
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [ -z "${1:-}" ]; then
  usage >&2; exit 1
fi

case "$1" in
  -*) echo "Error: '$1' is not a <slug> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
esac

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: template not found at $TEMPLATE" >&2; exit 1
fi
if [ ! -d "$DEST_DIR" ]; then
  echo "Error: progress/todo/ not found at $DEST_DIR" >&2; exit 1
fi

SLUG="$1"; shift
ID=""; PRD=""; STORIES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --prd) PRD="$2"; shift 2 ;;
    --stories) STORIES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Stateless: the caller passes --id (see ./scripts/next-id.sh). Validate + guard.
validate_issue_id "$ID" "$ROOT" || exit 1

DEST="$DEST_DIR/${ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)
BRANCH="feature/${ID}-${SLUG}"

cp "$TEMPLATE" "$DEST"

# KEY ON THE FRONTMATTER KEY, replace only its VALUE TOKEN. The earlier patterns
# were `^id: ${ISSUE_PREFIX}-NNN` / `^branch: feature/${ISSUE_PREFIX}-NNN-<slug>`,
# which silently NO-OP under any prefix but the template's own — the file got
# created, nothing errored, and every issue carried the template's placeholder id
# under a real-prefix filename (check-board.sh's check [d] then flags the whole
# board). Keying on `^<key>: ` makes the substitution prefix-agnostic; each key
# occurs exactly once, in the frontmatter. Same pattern subtask.sh uses.
sed -i.bak \
  -e "s|^id: [^ ]*|id: ${ID}|" \
  -e "s|^created_at: YYYY-MM-DD|created_at: ${TODAY}|" \
  -e "s|^branch: [^ ]*|branch: ${BRANCH}|" \
  "$DEST"

if [ -n "$PRD" ]; then
  sed -i.bak -e "s|^prd: .*|prd: ${PRD}|" "$DEST"
fi

if [ -n "$STORIES" ]; then
  STORIES_YAML="[$(echo "$STORIES" | sed 's/,/, /g')]"
  sed -i.bak -e "s|^stories: .*|stories: ${STORIES_YAML}|" "$DEST"
fi

rm -f "${DEST}.bak"

echo "Created: $DEST"
echo "Branch:  ${BRANCH}"
echo ""
echo "Next steps:"
echo "  1. Fill in title, Problem, AC (copy from the PRD stories), Out of scope, Dependencies."
echo "  2. Date the seed Activity entry (the shapes block above it is examples, not entries)."
echo "  3. Confirm Definition of Ready (.claude/roles/pm.md)."
print_push_before_move "$DEST"
