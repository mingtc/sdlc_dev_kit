#!/usr/bin/env bash
# KIT-CLASS: KIT — PRD creation from the kit templates. See process/EXTRACTION.md.
# Create a new PRD file in requirements/ from the PRD template, with
# pre-filled id, created_at, and updated_at frontmatter.
#
# Usage:   ./scripts/new-prd.sh <slug>
# Example: ./scripts/new-prd.sh feature-resource

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh — as new-issue.sh states; change one, change all.
# This script's seam is PRD_PREFIX. The refusal sits below the usage arm.
CONFIG="$ROOT/scripts/config.sh"

CARDLIB="$ROOT/scripts/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  echo "Error: scripts/lib/card-head.sh is missing — it strips the" >&2
  echo "       template's KIT-CLASS marker and writes the live-card head in its place." >&2
  echo "       Restore it (git checkout -- scripts/lib/card-head.sh)." >&2
  echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)" >&2
  exit 1
fi

TEMPLATE="$ROOT/.claude/templates/PRD.template.md"
DEST_DIR="$ROOT/requirements"

usage() {
  echo "Usage: $(basename "$0") <slug>"
  echo "Example: $(basename "$0") feature-resource"
  echo "  -h, --help    this text (exit 0)."
}

# A leading '-' is never a name, and usage comes before the seam: as new-issue.sh states
# (issue-creation.md § 3).
case "${1:-}" in
  -h|--help)
    [ -f "$CONFIG" ] && . "$CONFIG" || true
    usage; exit 0 ;;
  -*) echo "Error: '$1' is not a <slug> — a leading '-' is never a name." >&2
      usage >&2
      exit 2 ;;
esac

if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX / PRD_PREFIX / PROJECT_NAME"
    echo "       (process/contracts/config-seam.md). This script REFUSES to guess a"
    echo "       prefix: a guessed prefix mints ids under a name nobody chose."
    echo "       Restore it (git checkout -- scripts/config.sh) — the way back on a tree that HAD it."
      echo "       ON A FRESH REPO, initialize the kit instead (it refuses one that has already lived):"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
    echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
  } >&2
  exit 1
fi
if [ -z "${PRD_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but PRD_PREFIX is empty — set it there." >&2
  exit 1
fi

if [ -z "${1:-}" ]; then
  usage >&2; exit 1
fi

case "$1" in
  -*) echo "Error: '$1' is not a <slug> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
esac

if [ $# -gt 1 ]; then
  case "$2" in
    -*) echo "Error: unknown option: $2" >&2; usage >&2; exit 2 ;;
    *)  echo "Unknown arg: $2" >&2; usage >&2; exit 1 ;;
  esac
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: template not found at $TEMPLATE" >&2
  exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
  echo "Error: requirements/ not found at $DEST_DIR" >&2
  exit 1
fi

SLUG="$1"
# The slug's shape is issue-creation.md § 5, implemented once by validate_slug in scripts/config.sh.
validate_slug "$SLUG" || exit 2

# PRD ids are derived here rather than passed in: PRDs are few and authored by one role
# (process/contracts/id-minting.md § "Spaces and streams").
LAST_NUM=$(find "$DEST_DIR" -maxdepth 1 -name "${PRD_PREFIX}-*.md" -type f 2>/dev/null \
  | sed -E "s@.*/${PRD_PREFIX}-0*([0-9]+)-.*@\\1@" \
  | sort -n | tail -1)
NEXT_NUM=$(( ${LAST_NUM:-0} + 1 ))
ID=$(printf "${PRD_PREFIX}-%03d" "$NEXT_NUM")

DEST="$DEST_DIR/${ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)

if [ -e "$DEST" ]; then
  echo "Error: $DEST already exists." >&2
  exit 1
fi

# Built aside and moved in last, as new-issue.sh does: a failed step leaves no PRD to spend the id.
WORK="$(kit_card_work "$DEST_DIR")"
trap 'rm -f "$WORK" "$WORK.bak" "$WORK.rehead"' EXIT

cp "$TEMPLATE" "$WORK"

# Keyed on the frontmatter KEY, not the template's placeholder value, so a template edit cannot
# make the substitution a silent no-op.
sed -i.bak \
  -e "s|^id: .*|id: ${ID}|" \
  -e "s|^created_at: YYYY-MM-DD|created_at: ${TODAY}|" \
  -e "s|^updated_at: YYYY-MM-DD|updated_at: ${TODAY}|" \
  "$WORK"
rm -f "${WORK}.bak"

# Replace the template's KIT-CLASS block with the live-card head (lib/card-head.sh).
kit_rehead_card "$WORK" || exit 1

kit_publish_card "$WORK" "$DEST" || exit 1

echo "Created: $DEST"
echo ""
echo "Next steps:"
echo "  1. Fill in title, Context, Goals, Non-Goals."
echo "  2. Add features (F1, F2, ...) and stories (F1-S1, F1-S2, ...)."
echo "  3. See .claude/roles/pm.md for the full PM workflow."
