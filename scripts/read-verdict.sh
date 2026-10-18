#!/usr/bin/env bash
# KIT-CLASS: KIT — read a card's column and QA Verdict on the trunk. See process/EXTRACTION.md.
# Print where a card sits on <remote>/<trunk> and what its '## QA Verdict' table says — each row's
# AC id and verdict — and whether the landing gate would accept that table. READ-ONLY.
#
# The verdict is what the trunk's committed table says, not what a leg's reply says: run this before
# promoting any QA reply to a board move, direct-to-trunk cards included. A landed PASS sits in
# 'qa_complete/' with no FAIL row; a deferred landing sits in 'dev_complete/'.
#
# It reads the trunk ref as last fetched (never fetches; `git fetch <remote> <trunk>` first for
# the live tip). The rows come from lib/qa-gate.sh's own reader, and the last line is
# kit_qa_verdict_check's own verdict on that card at that tip — the check a move to qa_complete/
# runs. It writes nothing: no board change, no progress record.
#
# Exit 0 when it printed. It refuses (exit 1) when it cannot read: the card is on no trunk
# column, more than one file claims the id, or the card has no '## QA Verdict' table.
#
# Usage:   ./scripts/read-verdict.sh <id>
# Example: ./scripts/read-verdict.sh KIT-012

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# shellcheck source=lib/refuse.sh
. "$ROOT/scripts/lib/refuse.sh"
# shellcheck source=lib/usage.sh
. "$ROOT/scripts/lib/usage.sh"
# shellcheck source=lib/exit-trap.sh
. "$ROOT/scripts/lib/exit-trap.sh"

# Arguments are read first: a usage request always succeeds, in any position.
for _a in "$@"; do
  case "$_a" in -h|--help) kit_usage "${BASH_SOURCE[0]}"; exit 0 ;; esac
done
for _a in "$@"; do
  case "$_a" in -*) echo "Error: unknown option: $_a" >&2; kit_usage "${BASH_SOURCE[0]}" >&2; exit 2 ;; esac   # exit-class: usage
done
ID="${1:-}"
if [ "$#" -ne 1 ] || ! printf '%s' "$ID" | grep -qE '^[A-Za-z0-9]+-[0-9]+(-s[0-9]+)?$'; then
  kit_usage "${BASH_SOURCE[0]}" >&2
  exit 2   # exit-class: usage
fi

# shellcheck source=config.sh
. "$ROOT/scripts/config.sh" || { echo "read-verdict: scripts/config.sh would not source." >&2; exit 1; }   # exit-class: internal
# shellcheck source=lib/qa-gate.sh
. "$ROOT/scripts/lib/qa-gate.sh"

rc=0; TRUNK_REF="$(kit_trunk_ref "$ROOT")" || rc=$?
if [ "$rc" -ne 0 ]; then
  kit_refuse 1 trunk-unreadable \
    "Error: ${ID}'s card cannot be read: no remote-tracking trunk ref resolves in this repository." \
    "Next: run it from inside the project's git checkout; if the remote has no HEAD, settle the trunk once:  git remote set-head origin <your-trunk>; then  git fetch origin <your-trunk>."
fi
TIP="$(git -C "$ROOT" rev-parse --verify --quiet "refs/remotes/${TRUNK_REF}^{commit}")"  # card-read-exempt: the trunk, not a card branch

# The card: a column folder directly under progress/, or a slice's own column under
# progress/subtasks/<parent>/. A parent's id does not claim its slices' files.
PATHS="$(git -C "$ROOT" ls-tree -r --name-only "$TIP" -- progress 2>/dev/null \
  | { grep -E "^progress/(subtasks/[^/]+/)?[^/]+/${ID}-[^/]*\\.md\$" || true; })"
case "$ID" in *-s[0-9]*) : ;; *) PATHS="$(printf '%s\n' "$PATHS" | { grep -vE "/${ID}-s[0-9]+-[^/]*\\.md\$" || true; })" ;; esac
N="$(printf '%s\n' "$PATHS" | grep -c . || true)"
if [ "$N" -eq 0 ]; then
  kit_refuse 1 card-not-on-trunk \
    "Error: ${ID} is in no progress/ column on ${TRUNK_REF} @ $(git -C "$ROOT" rev-parse --short "$TIP") (as last fetched)." \
    "Next: git fetch the trunk and re-run; a card that is only on a branch or in a local commit has no verdict yet — commit it to the trunk with ./scripts/register-commit.sh or finish the landing, then re-run."
elif [ "$N" -gt 1 ]; then
  kit_refuse 1 card-ambiguous \
    "Error: more than one file on ${TRUNK_REF} claims ${ID}:" \
    "$(printf '%s\n' "$PATHS" | sed 's/^/    /')" \
    "Next: two cards sharing an id is a board defect — run ./scripts/check-board.sh, and re-run this with the right card's id."
fi
CARD_PATH="$PATHS"
COLUMN="$(basename "$(dirname "$CARD_PATH")")"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/read-verdict.XXXXXX")" || { echo "read-verdict: could not make a scratch directory." >&2; exit 1; }   # exit-class: internal
kit_on_exit 'rm -rf "$SCRATCH"'
CARD="$SCRATCH/card.md"
git -C "$ROOT" show "${TIP}:${CARD_PATH}" > "$CARD" \
  || { echo "read-verdict: git could not read ${CARD_PATH} at ${TIP}." >&2; exit 1; }   # exit-class: internal

echo "${ID} on ${TRUNK_REF} @ $(git -C "$ROOT" rev-parse --short "$TIP") (as last fetched, not fetched now)"
echo "column: ${COLUMN}"
echo "path:   ${CARD_PATH}"

if ! grep -qE '^## QA Verdict[[:space:]]*$' "$CARD"; then
  kit_refuse 1 card-has-no-verdict-table \
    "Error: ${ID} sits in ${COLUMN}/ on ${TRUNK_REF} and has no '## QA Verdict' table — there is no verdict to read." \
    "Next: the verdict is the committed table; until QA has written one to the trunk the reply decides nothing. Re-dispatch the review or wait for the QA leg to commit its table."
fi

echo "verdicts:"
ROWS="$(kit_qa_verdict_rows "$CARD")"
while IFS= read -r row; do
  [ -n "$row" ] || continue
  v="$(kit_md_row_cell "$row" 2 | tr -d '`*')"
  printf '  %-14s %s\n' "$(kit_md_row_cell "$row" 1)" "${v:-(blank)}"
done <<< "$ROWS"

# The landing gate's own verdict on this table at this tip. The gate records its refusal through
# kit_refuse; that record goes to the scratch directory, so the project's own is untouched.
GATE_OUT="$( KIT_PROGRESS_DIR="$SCRATCH/rec" kit_qa_verdict_check "$CARD" "$ID" "$ROOT" "$TIP" 2>&1 )"; GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
  echo "landing gate: would ACCEPT this table"
else
  rule="$(sed -n 's/.*refusal=\([a-z0-9-]*\).*/\1/p' "$SCRATCH"/rec/*.tsv 2>/dev/null | sed -n '1p')"
  echo "landing gate: would REFUSE this table (${rule:-exit $GATE_RC})"
  printf '%s\n' "$GATE_OUT" | sed -n '1,3p' | sed 's/^/  /'
fi
exit 0
