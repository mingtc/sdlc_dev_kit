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

# ── A USAGE REQUEST IS ANSWERED BEFORE THE SEAM IS SOURCED (issue-creation.md § 3: it always
# succeeds), in any position, before any argument is interpreted; the seam still refuses every
# operation. The arm reads the seam itself, guarded, for the usage text alone.
# This is the creators' canonical statement; the others point here.
CONFIG="$ROOT/scripts/config.sh"

usage() {
  # Runs before the seam may be sourced, so it DEGRADES (issue-creation.md § 3): an unread
  # prefix prints the seam's location, never the kit's default, and never aborts under `set -u`.
  local ip="${ISSUE_PREFIX:-}" pp="${PRD_PREFIX:-}"
  [ -n "$ip" ] || ip='<ISSUE_PREFIX from scripts/config.sh>'
  [ -n "$pp" ] || pp='<PRD_PREFIX from scripts/config.sh>'
  echo "Usage: $(basename "$0") <slug> --id ${ip}-NNN [--prd ${pp}-NNN] [--stories ID1,ID2,...]"
  echo "  --id is required; get it from ./scripts/next-id.sh and sanity-check it."
  echo "  -h, --help    this text (exit 0)."
}

# A LEADING '-' IS NEVER A NAME (issue-creation.md § 3): --help anywhere exits 0; a dash-leading
# <slug> or an unknown option refuses with 2. Decided ahead of the seam so the status is 2 on a
# tree without one. It needs no option list: the leading token here is always a <slug>.
for _a in "$@"; do
  case "$_a" in
    -h|--help) [ -f "$CONFIG" ] && . "$CONFIG" || true; usage; exit 0 ;;
  esac
done
case "${1:-}" in
  -*) echo "Error: '$1' is not a <slug> — a leading '-' is never a name." >&2
      usage >&2
      exit 2 ;;
esac

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh. No fallback literal anywhere: a guessed
# prefix mints ids under a name nobody chose, so the seam's absence is a refusal that names it.
# Every carrier of this block is found by its `if` line; change one, change all.
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

CARDLIB="$ROOT/scripts/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  echo "Error: scripts/lib/card-head.sh is missing — it strips the" >&2
  echo "       template's KIT-CLASS marker and writes the live-card head in its place." >&2
  echo "       Restore it (git checkout -- scripts/lib/card-head.sh)." >&2
  echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)" >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

TEMPLATE="$ROOT/.claude/templates/ISSUE.template.md"
DEST_DIR="$ROOT/progress/todo"

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

# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --id) need_val "$@"; ID="$2"; shift 2 ;;
    --prd) need_val "$@"; PRD="$2"; shift 2 ;;
    --stories) need_val "$@"; STORIES="$2"; shift 2 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Stateless: the caller passes --id (see ./scripts/next-id.sh). The slug's shape is
# issue-creation.md § 5, implemented once by validate_slug in scripts/config.sh.
validate_slug "$SLUG" || exit 2
validate_issue_id "$ID" "$ROOT" || exit 1

DEST="$DEST_DIR/${ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)
BRANCH="feature/${ID}-${SLUG}"

# BUILD IT ASIDE, PUBLISH IT WHOLE: a refusal must change nothing, so the card reaches the
# board only after every substitution has succeeded.
WORK="$(kit_card_work "$DEST_DIR")"
trap 'rm -f "$WORK" "$WORK.bak" "$WORK.rehead" "$WORK.stamp" "$WORK.fill"' EXIT

# Every value goes through sed_repl (scripts/config.sh): `|`, `\` and `&` are not literal in
# `s|…|REPL|`.

cp "$TEMPLATE" "$WORK"

# KEY ON THE FRONTMATTER KEY and replace only its value token: a prefix-bearing pattern
# silently no-ops under any prefix but the template's own.
sed -i.bak \
  -e "s|^id: [^ ]*|id: $(sed_repl "$ID")|" \
  -e "s|^created_at: YYYY-MM-DD|created_at: $(sed_repl "$TODAY")|" \
  -e "s|^branch: [^ ]*|branch: $(sed_repl "$BRANCH")|" \
  "$WORK"

if [ -n "$PRD" ]; then
  sed -i.bak -e "s|^prd: .*|prd: $(sed_repl "$PRD")|" "$WORK"
fi

if [ -n "$STORIES" ]; then
  STORIES_YAML="[$(echo "$STORIES" | sed 's/,/, /g')]"
  sed -i.bak -e "s|^stories: .*|stories: $(sed_repl "$STORIES_YAML")|" "$WORK"
fi

rm -f "${WORK}.bak"
# Replace the template's KIT-CLASS block with the live-card head (lib/card-head.sh).
kit_rehead_card "$WORK" || exit 1
# What the mint knows goes into the body too: the H1's id, the seed entry's date, the PRD, the
# stories and the plan's id (lib/card-head.sh). An absent flag leaves its blank for the author.
kit_stamp_card "$WORK" "$ID" "$TODAY" || exit 1
PRD_FILE=""
if [ -n "$PRD" ]; then
  for f in "$ROOT/requirements/$PRD"-*.md; do
    [ -f "$f" ] && [ -z "$PRD_FILE" ] && PRD_FILE="$(basename "$f")"
  done
fi
STORY_IDS=""
[ -z "$STORIES" ] || STORY_IDS="$(printf '%s' "$STORIES" | sed 's/,/, /g')"
kit_fill_card "$WORK" "PRD-NNN-<slug>.md" "$PRD_FILE" "PRD-NNN" "$PRD" "<story ids>" "$STORY_IDS" \
  "dev/plans/YYYY-MM-DD-<PREFIX>-NNN-" "dev/plans/YYYY-MM-DD-$ID-" \
  "dev/plans/YYYY-MM-DD-${ISSUE_PREFIX}-NNN-" "dev/plans/YYYY-MM-DD-$ID-" || exit 1


kit_publish_card "$WORK" "$DEST" || exit 1

echo "Created: $DEST"
echo "Branch:  ${BRANCH}"
echo ""
echo "Next steps:"
echo "  1. Fill in title, Problem, AC (copy from the PRD stories), Out of scope, Dependencies."
echo "  2. Confirm Definition of Ready (.claude/roles/pm.md)."
print_push_before_move "$DEST"
