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

# ── Usage before the seam: as new-issue.sh states (issue-creation.md § 3).
CONFIG="$ROOT/scripts/config.sh"

usage() {
  # Degrades when the seam is unread, as new-issue.sh's usage() states.
  local ip="${ISSUE_PREFIX:-}" pp="${PRD_PREFIX:-}"
  [ -n "$ip" ] || ip='<ISSUE_PREFIX from scripts/config.sh>'
  [ -n "$pp" ] || pp='<PRD_PREFIX from scripts/config.sh>'
  echo "Usage: $(basename "$0") <slug> --id ${ip}-NNN \\"
  echo "         [--prd ${pp}-NNN] [--stories ID1,ID2,...] \\"
  echo "         [--discovered-in ${ip}-NNN] [--severity Blocker|Critical|Major|Minor]"
  echo "  --id is required; get it from ./scripts/next-id.sh and sanity-check it."
  echo "  -h, --help    this text (exit 0)."
}

# A leading '-' is never a name: as new-issue.sh states (issue-creation.md § 3).
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

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh — as new-issue.sh states; change one, change all.
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

TEMPLATE="$ROOT/.claude/templates/BUG.template.md"
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
ID=""; PRD=""; STORIES=""; DISCOVERED=""; SEVERITY=""

# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --id) need_val "$@"; ID="$2"; shift 2 ;;
    --prd) need_val "$@"; PRD="$2"; shift 2 ;;
    --stories) need_val "$@"; STORIES="$2"; shift 2 ;;
    --discovered-in) need_val "$@"; DISCOVERED="$2"; shift 2 ;;
    --severity)
      need_val "$@"
      case "$2" in
        Blocker|Critical|Major|Minor) SEVERITY="$2" ;;
        *) echo "Error: --severity must be Blocker|Critical|Major|Minor" >&2; exit 1 ;;
      esac
      shift 2 ;;
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
BRANCH="fix/${ID}-${SLUG}"

# BUILD IT ASIDE, PUBLISH IT WHOLE, and escape every value: as new-issue.sh states.
WORK="$(kit_card_work "$DEST_DIR")"
trap 'rm -f "$WORK" "$WORK.bak" "$WORK.rehead" "$WORK.stamp" "$WORK.fill"' EXIT

cp "$TEMPLATE" "$WORK"

# Key on the frontmatter KEY, replace only its value token (see new-issue.sh).
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
if [ -n "$DISCOVERED" ]; then
  sed -i.bak -e "s|^discovered_in: [^ ]*|discovered_in: $(sed_repl "$DISCOVERED")|" "$WORK"
fi
if [ -n "$SEVERITY" ]; then
  sed -i.bak -e "s|^severity: .*|severity: $(sed_repl "$SEVERITY")|" "$WORK"
fi

rm -f "${WORK}.bak"
# Replace the template's KIT-CLASS block with the live-card head (lib/card-head.sh).
kit_rehead_card "$WORK" || exit 1
# The body's known values: the H1's id, the seed entry's date, the PRD, the stories and the issue
# that surfaced it.
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
  "Related issue: <PREFIX>-NNN" "${DISCOVERED:+Related issue: $DISCOVERED}" \
  "Related issue: ${ISSUE_PREFIX}-NNN" "${DISCOVERED:+Related issue: $DISCOVERED}" \
  "during review of <PREFIX>-NNN" "${DISCOVERED:+during review of $DISCOVERED}" \
  "during review of ${ISSUE_PREFIX}-NNN" "${DISCOVERED:+during review of $DISCOVERED}" || exit 1


kit_publish_card "$WORK" "$DEST" || exit 1

echo "Created: $DEST"
echo "Branch:  ${BRANCH}"
echo ""
echo "Next steps:"
echo "  1. Fill in title and Bug description."
echo "  2. Complete the reproduction fields (Reproduction, Expected vs Actual, Impact, Environment, References)."
echo "  3. See .claude/roles/qa.md for the full QA workflow."
print_push_before_move "$DEST"
