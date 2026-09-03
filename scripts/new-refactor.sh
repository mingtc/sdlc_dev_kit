#!/usr/bin/env bash
# KIT-CLASS: KIT — refactor-issue creation from the kit templates. See process/EXTRACTION.md.
# Create a new refactor issue file in progress/todo/ from the REFACTOR
# template, with pre-filled id, created_at, branch (refactor/), and
# optionally refactor_pass, target_module, prd, and stories frontmatter.
#
# Usage:
#   ./scripts/new-refactor.sh <slug> --id <PREFIX>-NNN \
#     [--pass dev/refactor/<file>.md] [--target "<short target name>"] \
#     [--prd PRD-NNN] [--stories ID1,ID2,...]
#
# The id is REQUIRED and passed in — this script is stateless (it does not guess
# the next number). Get it from ./scripts/next-id.sh, sanity-check it, pass --id.
#
# Example:
#   ID=$(./scripts/next-id.sh) && ./scripts/new-refactor.sh split-parser --id "$ID" \
#     --pass dev/refactor/<YYYY-MM-DD>-<scope>-pass.md \
#     --target "parser split"

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

# The mint-time re-head lives in one place now — scripts/lib/card-head.sh. The block that
# used to sit here carried its own comment saying it would move "when that lib exists".
CARDLIB="$ROOT/scripts/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  echo "Error: scripts/lib/card-head.sh is missing or could not be sourced — it strips the" >&2
  echo "       template's KIT-CLASS marker and writes the live-card head in its place." >&2
  echo "       Restore it (git checkout -- scripts/lib/card-head.sh)." >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

TEMPLATE="$ROOT/.claude/templates/REFACTOR.template.md"
DEST_DIR="$ROOT/progress/todo"

usage() {
  echo "Usage: $(basename "$0") <slug> --id ${ISSUE_PREFIX}-NNN \\"
  echo "         [--pass dev/refactor/<file>.md] [--target \"<short target name>\"] \\"
  echo "         [--prd ${PRD_PREFIX}-NNN] [--stories ID1,ID2,...]"
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
ID=""; PASS=""; TARGET=""; PRD=""; STORIES=""

# AN OPTION THAT TAKES A VALUE MUST REFUSE WHEN THE VALUE IS ABSENT, NAMING IT.
# `--severity` as the last argument used to reach a bare `$2` under `set -u`, so the
# script died with "$2: unbound variable": non-zero only by accident of the shell, and
# naming a positional rather than the flag the operator got wrong. The contract asks
# for a refusal that names the option.
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --id) need_val "$@"; ID="$2"; shift 2 ;;
    --pass) need_val "$@"; PASS="$2"; shift 2 ;;
    --target) need_val "$@"; TARGET="$2"; shift 2 ;;
    --prd) need_val "$@"; PRD="$2"; shift 2 ;;
    --stories) need_val "$@"; STORIES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Stateless: the caller passes --id (see ./scripts/next-id.sh). Validate + guard.
# The short name's shape is declared in process/contracts/issue-creation.md § 5;
# validate_slug (scripts/config.sh) implements it. No pattern here — one shape, one site.
validate_slug "$SLUG" || exit 2
validate_issue_id "$ID" "$ROOT" || exit 1

DEST="$DEST_DIR/${ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)
BRANCH="refactor/${ID}-${SLUG}"

# BUILD IT ASIDE, PUBLISH IT WHOLE, and ESCAPE THE REPLACEMENT HALF — both for the
# reasons new-issue.sh states in full. In short: a value containing `|`, `\` or `&` is
# not literal inside `s|…|REPL|`, and the card used to be copied onto the board before
# the substitutions ran, so a failure left a half-filled card and its .bak behind with
# the id already burned.
WORK="$(mktemp)"
trap 'rm -f "$WORK" "$WORK.bak"' EXIT
# sed_repl lives in scripts/config.sh, already sourced above — one definition, and the
# reason it exists is stated there. It was copied here, byte for byte, in three scripts.

cp "$TEMPLATE" "$WORK"

# Key on the frontmatter KEY, replace only its value token — the prefix-bearing
# patterns silently no-opped under any prefix but the template's own (see
# new-issue.sh for the full statement of that defect).
sed -i.bak \
  -e "s|^id: [^ ]*|id: $(sed_repl "$ID")|" \
  -e "s|^created_at: YYYY-MM-DD|created_at: $(sed_repl "$TODAY")|" \
  -e "s|^branch: [^ ]*|branch: $(sed_repl "$BRANCH")|" \
  "$WORK"

if [ -n "$PASS" ]; then
  sed -i.bak -e "s|^refactor_pass: .*|refactor_pass: $(sed_repl "$PASS")|" "$WORK"
fi
if [ -n "$TARGET" ]; then
  sed -i.bak -e "s|^target_module: .*|target_module: $(sed_repl "$TARGET")|" "$WORK"
fi
if [ -n "$PRD" ]; then
  sed -i.bak -e "s|^prd: .*|prd: $(sed_repl "$PRD")|" "$WORK"
fi
if [ -n "$STORIES" ]; then
  STORIES_YAML="[$(echo "$STORIES" | sed 's/,/, /g')]"
  sed -i.bak -e "s|^stories: .*|stories: $(sed_repl "$STORIES_YAML")|" "$WORK"
fi

rm -f "${WORK}.bak"
# The card head that replaces the template's KIT-CLASS block at mint. See the re-head block below.
# THE HEAD MUST NOT CONTAIN THE MARKER KEY, not even to deny it. The convention's own way to derive
# what is classified is `grep -rl` for that key, so a card saying "no <key> marker" would be a false
# POSITIVE in the one derivation the manifest recommends — and would redden the harness case that
# asserts a minted card is unmarked. Measured: the first wording did exactly that.
kit_rehead_card "$WORK" || exit 1


mv "$WORK" "$DEST"

echo "Created: $DEST"
echo "Branch:  ${BRANCH}"
echo ""
echo "Next steps:"
echo "  1. Fill in title, Target & Goal, Behaviors Preserved, Move Sequence."
echo "  2. Fill in the Safety-Net Assessment (link to the pass doc § target)."
echo "  3. Fill in the Migration Plan (if any public-surface changes)."
echo "  4. Date the seed Activity entry (the shapes block above it is examples, not entries)."
echo "  5. Confirm Definition of Ready (.claude/roles/refactorer.md)."
print_push_before_move "$DEST"
