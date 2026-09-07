#!/usr/bin/env bash
# KIT-CLASS: KIT — PRD creation from the kit templates. See process/EXTRACTION.md.
# Create a new PRD file in requirements/ from the PRD template, with
# pre-filled id, created_at, and updated_at frontmatter.
#
# Usage:   ./scripts/new-prd.sh <slug>
# Example: ./scripts/new-prd.sh feature-resource

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh. ─────────────────────────
# Same rule and same reason as every other script carrying this block: no fallback
# literal, and a missing or unsourceable seam is a refusal that names it. This script's
# seam is PRD_PREFIX; the others' is ISSUE_PREFIX, and the rule is one rule.
#
# THE PHRASE ABOVE IS LOAD-BEARING AND IS DELIBERATELY IDENTICAL TO THE OTHER COPIES.
# It carried the PLURAL form of this phrase (PREFIXES / HAVE) for as long as this
# script has existed, and the census that finds every carrier matches the singular.
# So this script, a carrier, was invisible to the instrument meant to find it, by one
# character: the harness's config-seam case tested five consumers and claimed all of
# them, and this one was the sixth.
# The same block is in every script that grep returns — change one, change all.
CONFIG="$ROOT/scripts/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing or could not be sourced."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX / PRD_PREFIX / PROJECT_NAME"
    echo "       (process/contracts/config-seam.md). This script REFUSES to guess a"
    echo "       prefix: a guessed prefix mints ids under a name nobody chose."
    echo "       Restore it (git checkout -- scripts/config.sh) — the way back on a tree that HAD it."
      echo "       ON A FRESH REPO, initialize the kit instead (it refuses one that has already lived):"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
  } >&2
  exit 1
fi

# The mint-time re-head lives in one place now — scripts/lib/card-head.sh. The block that
# used to sit here carried its own comment saying it would move "when that lib exists".
CARDLIB="$ROOT/scripts/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  echo "Error: scripts/lib/card-head.sh is missing or could not be sourced — it strips the" >&2
  echo "       template's KIT-CLASS marker and writes the live-card head in its place." >&2
  echo "       Restore it (git checkout -- scripts/lib/card-head.sh)." >&2
  exit 1
fi
if [ -z "${PRD_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but PRD_PREFIX is empty — set it there." >&2
  exit 1
fi

TEMPLATE="$ROOT/.claude/templates/PRD.template.md"
DEST_DIR="$ROOT/requirements"

usage() {
  echo "Usage: $(basename "$0") <slug>"
  echo "Example: $(basename "$0") feature-resource"
  echo "  -h, --help    this text (exit 0)."
}

# A LEADING '-' IS NEVER A NAME (process/contracts/issue-creation.md § 3). This
# script is where the incident happened: `new-prd.sh --help` created
# requirements/PRD-001---help.md, burning PRD-001's id, and printed "Created:".
# --help exits 0; a dash-leading positional refuses with rc=2; an unknown option
# refuses with rc=2 rather than being swallowed.
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

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
# The short name's shape is declared in process/contracts/issue-creation.md § 5;
# validate_slug (scripts/config.sh) implements it. No pattern here — one shape, one site.
validate_slug "$SLUG" || exit 2

# Find the highest existing PRD-NNN, increment by 1. (PRDs are few and authored by
# one role, so unlike issue ids this one number IS derived here rather than passed
# in — process/contracts/id-minting.md § "Spaces and streams".)
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

cp "$TEMPLATE" "$DEST"

# Portable sed -i (BSD on macOS, GNU on Linux) via .bak then delete. Keyed on the
# frontmatter KEY, not on the template's placeholder value, so a template edit
# cannot make the substitution a silent no-op.
sed -i.bak \
  -e "s|^id: .*|id: ${ID}|" \
  -e "s|^created_at: YYYY-MM-DD|created_at: ${TODAY}|" \
  -e "s|^updated_at: YYYY-MM-DD|updated_at: ${TODAY}|" \
  "$DEST"
rm -f "${DEST}.bak"

# RE-HEAD THE CARD: the template's travel classification goes, its still-in-force instruction stays.
# process/EXTRACTION.md § The marker and graduation: a minted card's class has become PROJECT at the
# moment of minting, so the KIT-CLASS: marker is stripped. But that marker also carried a FILL
# instruction still in force while the author fills the card, and the same manifest forbids an
# instruction living inside a marker that will be removed — so this REPLACES the block rather than
# deleting it. A blind delete would have taken the guidance with the classification, and nowhere
# else in the kit states it.
#
# THE HEAD IS PREPENDED BY THE SHELL, NOT PASSED INTO awk. `awk -v x="$MULTILINE"` fails with
# "newline in string" and awk then writes NOTHING — measured: the first version of this block
# produced an EMPTY card. awk deletes the old block, printf writes the new head, cat appends the
# rest; every step is POSIX and none of them carries a newline through an assignment.
#
# DUPLICATED ACROSS THE MINTING SCRIPTS ON PURPOSE, FOR NOW: they source no common file, and giving
# them one is a structural change owned elsewhere. When that lib exists, this moves into it.
# THE HEAD MUST NOT CONTAIN THE MARKER KEY, not even to deny it. The convention's own way to derive
# what is classified is `grep -rl` for that key, so a card saying "no <key> marker" would be a false
# POSITIVE in the one derivation the manifest recommends — and would redden the harness case that
# asserts a minted card is unmarked. Measured: the first wording did exactly that.
kit_rehead_card "$DEST" || exit 1

echo "Created: $DEST"
echo ""
echo "Next steps:"
echo "  1. Fill in title, Context, Goals, Non-Goals."
echo "  2. Add features (F1, F2, ...) and stories (F1-S1, F1-S2, ...)."
echo "  3. See .claude/roles/pm.md for the full PM workflow."
