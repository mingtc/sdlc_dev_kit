#!/usr/bin/env bash
# KIT-CLASS: KIT — bug creation from the kit templates. See process/EXTRACTION.md.
# Create a new bug issue file in progress/todo/ from the BUG template, with
# pre-filled id, created_at, branch (fix/), and optionally prd, stories,
# discovered_in, and severity frontmatter.
#
# Usage:
#   ./scripts/new-bug.sh <slug> --id <PREFIX>-NNN \
#     [--prd PRD-NNN] [--stories ID1,ID2,...] \
#     [--discovered-in <PREFIX>-NNN] [--severity Blocker|Critical|Major|Minor]
#
# The id is REQUIRED and passed in — this script is stateless (it does not guess
# the next number). Get it from ./scripts/next-id.sh, sanity-check it, pass --id.
#
# Example:
#   ID=$(./scripts/next-id.sh) && ./scripts/new-bug.sh url-parse-crash --id "$ID" \
#     --prd PRD-001 --stories PRD-001-F2-S1 \
#     --discovered-in <PREFIX>-008 --severity Critical

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

TEMPLATE="$ROOT/.claude/templates/BUG.template.md"
DEST_DIR="$ROOT/progress/todo"

usage() {
  echo "Usage: $(basename "$0") <slug> --id ${ISSUE_PREFIX}-NNN \\"
  echo "         [--prd ${PRD_PREFIX:-PRD}-NNN] [--stories ID1,ID2,...] \\"
  echo "         [--discovered-in ${ISSUE_PREFIX}-NNN] [--severity Blocker|Critical|Major|Minor]"
  echo "  --id is required; get it from ./scripts/next-id.sh and sanity-check it."
  echo "  -h, --help    this text (exit 0)."
}

# A leading '-' is never a name — see new-issue.sh for the incident and the rule
# (process/contracts/issue-creation.md § 3): --help exits 0, an unknown option
# refuses with rc=2 rather than being consumed as a value.
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
ID=""; PRD=""; STORIES=""; DISCOVERED=""; SEVERITY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --prd) PRD="$2"; shift 2 ;;
    --stories) STORIES="$2"; shift 2 ;;
    --discovered-in) DISCOVERED="$2"; shift 2 ;;
    --severity)
      case "$2" in
        Blocker|Critical|Major|Minor) SEVERITY="$2" ;;
        *) echo "Error: --severity must be Blocker|Critical|Major|Minor" >&2; exit 1 ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Stateless: the caller passes --id (see ./scripts/next-id.sh). Validate + guard.
validate_issue_id "$ID" "$ROOT" || exit 1

DEST="$DEST_DIR/${ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)
BRANCH="fix/${ID}-${SLUG}"

cp "$TEMPLATE" "$DEST"

# Key on the frontmatter KEY, replace only its value token — the prefix-bearing
# patterns silently no-opped under any prefix but the template's own (see
# new-issue.sh for the full statement of that defect).
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
if [ -n "$DISCOVERED" ]; then
  sed -i.bak -e "s|^discovered_in: [^ ]*|discovered_in: ${DISCOVERED}|" "$DEST"
fi
if [ -n "$SEVERITY" ]; then
  sed -i.bak -e "s|^severity: .*|severity: ${SEVERITY}|" "$DEST"
fi

rm -f "${DEST}.bak"

echo "Created: $DEST"
echo "Branch:  ${BRANCH}"
echo ""
echo "Next steps:"
echo "  1. Fill in title and Bug description."
echo "  2. Complete the reproduction fields (Reproduction, Expected vs Actual, Impact, Environment, References)."
echo "  3. Date the seed Activity entry (the shapes block above it is examples, not entries)."
echo "  4. See .claude/roles/qa.md for the full QA workflow."
print_push_before_move "$DEST"
