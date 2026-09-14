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

# ── A USAGE REQUEST IS ANSWERED BEFORE THE SEAM IS SOURCED. ──────────────────
# process/contracts/issue-creation.md § 3: a request for the usage text is ALWAYS legal and
# ALWAYS succeeds. This arm used to sit BELOW the seam block, so on a tree with
# scripts/config.sh missing `new-bug.sh --help` exited 1 carrying the seam refusal — the
# contract's one prohibition, fired in the state where an operator most needs the help text.
# next-id.sh has had this order since it gained an argument parser at all, and its comment
# carries the reason; this is that order.
#
# NOTHING ELSE MOVES, and that is the point: the seam still refuses every OPERATION below,
# because a guessed prefix is the expensive failure this block exists to prevent. Only the
# usage request is decided ahead of it.
#
# LEADING ARGUMENT ONLY, and that is a stated NARROWING rather than the whole clause.
# `--help` in a LATER position —
#     ./scripts/new-bug.sh my-slug --help
# — is still answered further down, so with the seam missing that spelling still exits 1.
# Answering help before ANY argument is interpreted would also change what a bad flag
# FOLLOWED by `--help` returns on a correct tree (`new-bug.sh --not-a-flag --help`), and that is a
# separate decision from this one.
#
# THE SEAM IS READ HERE TOO, GUARDED, AND FOR THE USAGE TEXT ALONE. issue-creation.md § 3 says
# usage text carrying a derived value reads that value FROM ITS SEAM AT PRINT TIME rather than
# holding a copy — so an arm placed ahead of the operational load needs its own read, or it
# degrades on a tree that had nothing wrong with it. That is not hypothetical: it is what the
# first draft of this reorder did, measured, before this line existed.
# GUARDED AND `|| true`, because this is the usage path and a seam it cannot read must cost the
# operator nothing here. The OPERATIONAL refusal below is untouched: it still exits 1, still
# names the seam, and still cites the contract.
# ITS LIMIT IS THE REFUSAL'S OWN, stated in the same words: this sees ABSENCE. A seam that
# EXISTS and cannot be sourced aborts from inside the `.` before either branch is reached.
# CONFIG IS ASSIGNED ABOVE THIS ARM for that read, and the seam block below no longer assigns
# it — one path expression, one site, which is the rule the seam itself exists to keep.
CONFIG="$ROOT/scripts/config.sh"

usage() {
  # THE PREFIXES ARE READ FROM THE SEAM AND THIS FUNCTION NOW RUNS BEFORE IT IS SOURCED, so
  # the render has to DEGRADE rather than die. issue-creation.md § 3's three ranked rules for
  # usage text that carries a derived value: (1) the request still exits 0 with its full text,
  # (2) an unreadable seam prints the seam's own location — the file AND the variable — in place
  # of the value, and (3) it NEVER prints the kit's shipped default as a stand-in.
  # Each rule is here for a measured reason: without (1) `set -u` turns an unset prefix into an
  # unbound-variable abort, which is a usage request failing on a shell diagnostic; without (2)
  # the operator learns nothing about where to look, which is the whole job of usage text; and
  # without (3) the text advertises a prefix that is right about the kit and wrong about this
  # project — authoritative-looking and unfalsifiable from the operator's seat.
  # ON A CORRECT TREE NOTHING CHANGES, and that takes the guarded read in the usage arm below
  # rather than being free: with the arm ahead of the operational load, NOTHING had set these
  # two by the time this rendered. MEASURED on the first draft of this very change — `--help` on
  # a tree whose seam was perfectly readable printed the degradation, which is the fallback
  # firing where there was nothing to fall back from. The arm reads the seam first; this
  # degrades only where that read found nothing.
  local ip="${ISSUE_PREFIX:-}" pp="${PRD_PREFIX:-}"
  [ -n "$ip" ] || ip='<ISSUE_PREFIX from scripts/config.sh>'
  [ -n "$pp" ] || pp='<PRD_PREFIX from scripts/config.sh>'
  echo "Usage: $(basename "$0") <slug> --id ${ip}-NNN \\"
  echo "         [--prd ${pp}-NNN] [--stories ID1,ID2,...] \\"
  echo "         [--discovered-in ${ip}-NNN] [--severity Blocker|Critical|Major|Minor]"
  echo "  --id is required; get it from ./scripts/next-id.sh and sanity-check it."
  echo "  -h, --help    this text (exit 0)."
}

# A leading '-' is never a name — see new-issue.sh for the incident and the rule
# (process/contracts/issue-creation.md § 3): --help exits 0, an unknown option
# refuses with rc=2 rather than being consumed as a value.
#
# AND THE DASH-LEADING ARM IS DECIDED HERE TOO, ahead of the seam, for the same reason the
# usage request is: § 3 gives it a status — "an unrecognised option ⇒ refuse, non-zero,
# naming it ... and in this kit that status is 2" — and below the seam it never gets one.
# MEASURED on a seamless tree before this arm existed: `$(basename)` with a dash-leading
# token exited 1 carrying the seam refusal, not 2. The three behaviours this comment already
# promises were true only where scripts/config.sh could be read.
# IT NEEDS NO OPTION VOCABULARY, which is what lets it sit this high: the leading token here
# is a <slug>, so a dash-leading token in THAT position is illegal whatever the option list
# below says — this arm re-states no part of it. Naming the options here instead would put a
# second copy of them above the first, which is the defect § 3's own scar records: "the
# remedy was one fewer copy, not a better matcher". That is also why archive.sh and
# subtask.sh, whose leading token may LEGALLY be an option or a subcommand, do not get it:
# there the arm could not tell a bad flag from a good one without holding that second copy.
case "${1:-}" in
  -h|--help)
    [ -f "$CONFIG" ] && . "$CONFIG" || true
    usage; exit 0 ;;
  -*) echo "Error: '$1' is not a <slug> — a leading '-' is never a name." >&2
      usage >&2
      exit 2 ;;
esac

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
# CONFIG IS ASSIGNED ABOVE, beside the usage arm that also reads it. The block is
# otherwise unchanged, and the census that finds every carrier keys on the line below.
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

# The mint-time re-head lives in one place now — scripts/lib/card-head.sh. The block that
# used to sit here carried its own comment saying it would move "when that lib exists".
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
BRANCH="fix/${ID}-${SLUG}"

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
echo "  1. Fill in title and Bug description."
echo "  2. Complete the reproduction fields (Reproduction, Expected vs Actual, Impact, Environment, References)."
echo "  3. Date the seed Activity entry (the shapes block above it is examples, not entries)."
echo "  4. See .claude/roles/qa.md for the full QA workflow."
print_push_before_move "$DEST"
