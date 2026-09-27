#!/usr/bin/env bash
# KIT-CLASS: KIT — qa_complete -> done sweep + ARCHIVE.md index. See process/EXTRACTION.md.
# Sweep progress/qa_complete/ off the active board: index each issue in
# ARCHIVE.md AND move the full issue file into progress/done/ (the permanent
# home for completed stories). Completed stories are PRESERVED — they are never
# removed, only moved out of the active board into done/.
# ARCHIVE.md stays the condensed, searchable index; done/ holds the full bodies.
# `declined/` is never swept: it is terminal, and its value is being browsable.
#
# ALL git ops (the ARCHIVE.md edit, the `git mv`, the commit, the push) happen
# inside the STANDING detached `.kanban-wt/` worktree pinned to the trunk —
# NEVER the operator's current checkout — so a sweep run from a feature branch
# lands on the trunk and leaves the branch's tree clean. The sweep commits as
# the ARCHIVE_ROLE seat.
#
# Defaults to dry-run (prints what would be swept). Pass --apply to prepend
# one-line entries to ARCHIVE.md, `git mv` the issue files into progress/done/,
# commit, and push HEAD → the trunk.
#
# Usage:
#   ./scripts/archive.sh           # dry run (previews against the trunk)
#   ./scripts/archive.sh --dry-run # the same preview, spelled out; refused with --apply
#   ./scripts/archive.sh --apply   # apply: commit + push the sweep
#
#   ARCHIVE_ROLE   the seat this sweep commits as (default: Orchestrator). The tag
#                  is CHECKED against your declared role set before anything moves.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── A USAGE REQUEST IS ANSWERED BEFORE THE SEAM IS SOURCED ─────────────────────
# (process/contracts/issue-creation.md § 3: a usage request always succeeds). Leading argument
# only; a later `--help` is answered below the seam. The seam still refuses every operation.
# This arm reads no seam: if this header ever renders a seam value, give it the creators'
# guarded read.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh — as new-issue.sh states; change one, change all.
# No fallback literal: under a guessed prefix the sweep finds no issue files and reports
# "nothing to sweep" on a full column.
CONFIG="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX (process/contracts/config-seam.md)."
    echo "       This sweep REFUSES to guess: under a guessed prefix it would find no"
    echo "       issue files at all and report 'nothing to sweep' on a full column."
    echo "       Restore it (git checkout -- scripts/config.sh) — the way back on a tree that HAD it."
      echo "       ON A FRESH REPO, initialize the kit instead (it refuses one that has already lived):"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
    echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
  } >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# shellcheck source=lib/role-set.sh
. "$SCRIPT_DIR/lib/role-set.sh"

DRY_RUN=true
# A loop, so no argument is silently discarded. The bare form stays legal and stays a preview
# (contracts/archive-sweep.md § 2).
SAW_APPLY=false; SAW_DRY=false
while [ $# -gt 0 ]; do
  case "$1" in
  --apply) DRY_RUN=false; SAW_APPLY=true; shift ;;
  --dry-run) DRY_RUN=true; SAW_DRY=true; shift ;;
  "") shift ;;
  -h|--help) usage; exit 0 ;;
  # An unrecognised option exits 2; a surplus positional exits 1 (issue-creation.md § 3).
  -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done
# A CONTRADICTION IS REFUSED, NOT RESOLVED. Last-flag-wins would still be a guess about
# which one the operator meant, and the two guesses differ by a push to the trunk.
if [ "$SAW_APPLY" = true ] && [ "$SAW_DRY" = true ]; then
  {
    echo "Error: --apply and --dry-run are contradictory — refusing rather than guessing which you meant."
    echo "       --apply sweeps, commits and PUSHES to the trunk; --dry-run previews and changes nothing."
    echo "       Run one of them. The bare form (no flag) is the preview."
    echo "       NOTHING WAS CHANGED."
  } >&2
  exit 2
fi

# THE SEAT THIS SCRIPT ACTS AS. [Orchestrator] means session-close housekeeping; it is
# a MEMBER of the role set, not the set itself, so it is a knob and never derived — a
# derived tag would write whichever role sorts first into history as the actor.
ROLE="${ARCHIVE_ROLE:-Orchestrator}"
# CHECKED BEFORE THE LOCK AND THE WORKTREE: past this point the git mv and the ARCHIVE.md edit
# have happened, and a hook that rejects the tag would leave them uncommitted.
kit_require_role "$SCRIPT_DIR/.." "$ROLE" ARCHIVE_ROLE || exit 1

# Resolve repo root + trunk, take the lock, and route through the standing
# detached worktree synced to the trunk. The lock is trap-released on EXIT
# (armed inside kwt_lock).
kwt_resolve
kwt_lock
kwt_bootstrap
kwt_sync

ARCHIVE="$KWT/ARCHIVE.md"
QA_DIR="$KWT/progress/qa_complete"
DONE_DIR="$KWT/progress/done"
SUBTASKS_DIR="$KWT/progress/subtasks"

[ -d "$QA_DIR" ] || { echo "Error: $QA_DIR does not exist." >&2; exit 1; }
[ -f "$ARCHIVE" ] || { echo "Error: $ARCHIVE does not exist at the repo root." >&2; exit 1; }
# THE RETIRED STORE IS REQUIRED, NEVER MANUFACTURED (archive-sweep.md § 3): the folder IS the
# status, so creating it would turn a mistyped column into a new column holding retired work.
# Checked before any write: a refusal after one leaves the board worktree dirty.
if [ ! -d "$DONE_DIR" ]; then
  {
    echo "Error: the retired store progress/done/ does not exist on the trunk."
    echo "       Looked for: ${DONE_DIR#"$KWT"/}   (inside the kanban worktree at $KWT)"
    echo ""
    echo "  REFUSING rather than creating it. This script would otherwise invent a"
    echo "  status folder, and the folder IS the status — so a renamed or mistyped"
    echo "  column would silently become a new column holding retired work."
    echo ""
    echo "  If the board genuinely has no done/ column yet, create it deliberately"
    echo "  and publish it, the way kit-init does — one .gitkeep per column, so it"
    echo "  survives a clone:"
    echo "    mkdir -p progress/done && : > progress/done/.gitkeep"
    echo "    git add progress/done/.gitkeep && git commit -m '[PM] board: add the done/ column' && git push"
  } >&2
  exit 1
fi

if ! grep -q '^## Archived$' "$ARCHIVE"; then
  # The refusal lists what the store holds: archive-sweep.md § 3 requires that listing as the
  # proof. $DONE_DIR, not a hand-built path: the store is inside the kanban worktree.
  _held="$(find "$DONE_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | sort || true)"
  _n_held="$(printf '%s' "$_held" | grep -c . || true)"
  echo "Error: '## Archived' heading not found in $ARCHIVE." >&2
  echo "ARCHIVE.md must have a line containing exactly '## Archived' so this script knows where to insert." >&2
  if [ "${_n_held:-0}" -gt 0 ]; then
    echo "" >&2
    echo "AND THE STORE IS NOT EMPTY — progress/done/ already holds ${_n_held} retired item(s):" >&2
    printf '%s\n' "$_held" | sed 's|^.*/|      |' >&2
    echo "" >&2
    echo "  So this is a MISSING INDEX over real history, not a fresh board. Creating the heading" >&2
    echo "  now would publish an index that silently claims those ${_n_held} were never retired." >&2
    echo "  Backfill instead:" >&2
    echo "    1. add the line '## Archived' to $ARCHIVE" >&2
    echo "    2. add one entry under it for each item listed above, reading its id, type and" >&2
    echo "       title out of the file itself" >&2
    echo "    3. re-run this script; it will index only what is still on the board" >&2
  else
    echo "" >&2
    echo "  progress/done/ is empty, so nothing is being hidden: add the line '## Archived' to" >&2
    echo "  $ARCHIVE and re-run. Note in it that the emptiness was true when written." >&2
  fi
  exit 1
fi

# Collect issue files. Sort descending so the highest IDs (newest) appear
# first in the prepended block.
FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(find "$QA_DIR" -maxdepth 1 -name "${ISSUE_PREFIX}-*.md" -type f | sort -r)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Nothing to sweep in progress/qa_complete/ (looking for ${ISSUE_PREFIX}-*.md)."
  exit 0
fi

# A NAME ALREADY RETIRED REFUSES HERE, before any write: its `git mv` would fail after the
# ARCHIVE.md rewrite and leave the board worktree dirty.
_taken=""
for f in "${FILES[@]}"; do
  if [ -e "$DONE_DIR/$(basename "$f")" ]; then _taken="$_taken $(basename "$f")"; fi
done
if [ -n "$_taken" ]; then
  echo "Error: progress/done/ already holds:$_taken — refusing before any write. Resolve the duplicate by hand, then re-run." >&2
  exit 1
fi

echo "Found ${#FILES[@]} file(s) to sweep into progress/done/."
echo ""

# --- Completed-subtask-tree sweep ---
# A decomposition tree progress/subtasks/<parent>/ has its terminal home at
# progress/done/subtasks/<parent>/ once its PARENT issue reaches progress/done/.
# The parent reaches done/ either by already living there OR via THIS sweep (FILES).
SWEEP_PARENT_IDS=()
for f in "${FILES[@]}"; do
  SWEEP_PARENT_IDS+=("$(awk '/^id:/{print $2; exit}' "$f")")
done
parent_reaches_done() {  # $1 = parent id
  local p="$1" s candidate
  # Test each filename form independently: `ls a b` fails when one is missing even if the
  # other matched. With nullglob off an unmatched glob stays literal, so `[ -e ]` is false.
  for candidate in "$DONE_DIR/${p}-"*.md "$DONE_DIR/${p}.md"; do
    [ -e "$candidate" ] && return 0
  done
  # Or reaching done/ via THIS sweep?
  for s in "${SWEEP_PARENT_IDS[@]:-}"; do [ "$s" = "$p" ] && return 0; done
  return 1
}
SUBTASK_TREES=()
if [ -d "$SUBTASKS_DIR" ]; then
  for ptree in "$SUBTASKS_DIR"/*/; do
    [ -d "$ptree" ] || continue
    parent="$(basename "$ptree")"
    parent_reaches_done "$parent" && SUBTASK_TREES+=("$parent")
  done
fi
# Likewise a tree: `git mv` onto an existing directory nests the tree inside it, silently.
for p in "${SUBTASK_TREES[@]:-}"; do
  if [ -n "$p" ] && [ -e "$DONE_DIR/subtasks/$p" ]; then
    echo "Error: progress/done/subtasks/$p/ already exists — refusing before any write rather than nest progress/subtasks/$p/ inside it. Merge the two trees by hand, then re-run." >&2
    exit 1
  fi
done

# Build entries.
ENTRIES=""
for f in "${FILES[@]}"; do
  ID=$(awk '/^id:/{print $2; exit}' "$f")
  TYPE=$(awk '/^type:/{print $2; exit}' "$f")
  # TITLE is free text (it may legitimately contain '#'), so take it verbatim after 'title: '.
  TITLE=$(awk '/^title:/{sub(/^title: */, ""); print; exit}' "$f")
  # pr / stories template lines may carry an inline "# comment" (`pr:` is rewritten only by
  # move-issue.sh --set-pr, which nothing shipped calls); strip it so the index isn't polluted.
  strip_comment() { sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]*$//'; }
  PR=$(awk '/^pr:/{sub(/^pr: */, ""); print; exit}' "$f" | strip_comment)
  PRD=$(awk '/^prd:/{print $2; exit}' "$f")
  STORIES=$(awk '/^stories:/{sub(/^stories: */, ""); print; exit}' "$f" | strip_comment)

  # THE RETIREMENT DATE IS REQUIRED (archive-sweep.md § 2). The id stays the FIRST token:
  # next-id.sh reads entries as `- <PREFIX>-NNN ...` to avoid re-minting an archived id.
  # Spelled `retired`, not archive-progress.sh's `Rotated`: different facts, and a grep for
  # either must not return both. Built once, so the preview and the applied entry agree.
  RETIRED_ON="$(date +%Y-%m-%d)"
  ENTRY="- ${ID} [${TYPE}] ${TITLE}"
  if [ -n "$PR" ] && [ "$PR" != "null" ]; then
    ENTRY="${ENTRY} (PR ${PR})"
  fi
  # Cite a PRD only when there is a real one (skip an unfilled template placeholder,
  # "n/a", empty). Cite stories only when real (skip a placeholder and the empty list).
  if [ -n "$PRD" ] && [ "$PRD" != "${PRD_PREFIX}-NNN" ] && [ "$PRD" != "n/a" ]; then
    if [ -n "$STORIES" ] && [ "$STORIES" != "[]" ] \
       && ! printf '%s' "$STORIES" | grep -q 'NNN'; then
      ENTRY="${ENTRY} — references ${PRD} ${STORIES}"
    else
      ENTRY="${ENTRY} — references ${PRD}"
    fi
  fi
  ENTRY="${ENTRY} — retired ${RETIRED_ON}"
  ENTRIES+="${ENTRY}"$'\n'
done

echo "Will prepend to ARCHIVE.md under '## Archived':"
echo ""
printf '%s' "$ENTRIES"
echo ""
echo "And move the ${#FILES[@]} full file(s) into progress/done/."
echo ""

if [ ${#SUBTASK_TREES[@]} -gt 0 ]; then
  echo "And sweep ${#SUBTASK_TREES[@]} completed subtask tree(s) (parent now in done/) → progress/done/subtasks/:"
  for p in "${SUBTASK_TREES[@]}"; do
    echo "  - progress/subtasks/$p/ → progress/done/subtasks/$p/"
  done
  echo ""
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "(dry run — no changes made. Re-run with --apply to commit + push the sweep.)"
  exit 0
fi

# ── Apply, entirely inside the kanban worktree ($KWT). ──────────────────────
# Insert entries immediately after the "## Archived" line.
# Entries are passed via a tempfile rather than `awk -v entries=...`
# because BSD awk (the macOS default) rejects literal newlines in -v
# assignments. Reading via getline is portable across BSD and GNU awk.
ENTRIES_FILE=$(mktemp)
printf '%s' "$ENTRIES" > "$ENTRIES_FILE"
TMPFILE=$(mktemp)
awk -v entries_file="$ENTRIES_FILE" '
  found == 0 && /^## Archived$/ {
    print
    print ""
    while ((getline line < entries_file) > 0) print line
    close(entries_file)
    found = 1
    next
  }
  { print }
' "$ARCHIVE" > "$TMPFILE"
mv "$TMPFILE" "$ARCHIVE"
rm -f "$ENTRIES_FILE"

# Move the full files into progress/done/ (preserve, don't remove). Prefer
# `git mv` (tracks the rename); fall back to plain mv if untracked.
for f in "${FILES[@]}"; do
  dest="$DONE_DIR/$(basename "$f")"
  if git -C "$KWT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git -C "$KWT" mv "$f" "$dest"
  else
    mv "$f" "$dest"
  fi
done

# Sweep completed subtask trees into progress/done/subtasks/<parent>/.
if [ ${#SUBTASK_TREES[@]} -gt 0 ]; then
  # This mkdir stays: done/subtasks/ is a sub-store inside the retired store, not a status
  # column, so creating it invents no status.
  mkdir -p "$DONE_DIR/subtasks"
  for p in "${SUBTASK_TREES[@]}"; do
    src="$SUBTASKS_DIR/$p"
    dest="$DONE_DIR/subtasks/$p"
    if git -C "$KWT" ls-files --error-unmatch "$src" >/dev/null 2>&1; then
      git -C "$KWT" mv "$src" "$dest"
    else
      mkdir -p "$(dirname "$dest")"
      mv "$src" "$dest"
    fi
  done
fi

git -C "$KWT" add "$ARCHIVE"

# Commit inside the worktree and push HEAD → the trunk. A push failure after the
# local commit is fatal — kwt_finalize prints the loud recovery text; abort nonzero.
SUBTASK_NOTE=""
[ ${#SUBTASK_TREES[@]} -gt 0 ] && SUBTASK_NOTE=" + ${#SUBTASK_TREES[@]} subtask tree(s)"
MSG="[$ROLE] archive: sweep ${#FILES[@]} issue(s) qa_complete/ → done/${SUBTASK_NOTE} + index in ARCHIVE.md"
git -C "$KWT" commit -m "$MSG" --quiet
# This sha is taken before the push; a contested push rebases, so the landed sha is printed
# separately below (board-mover.md § 4: a reader can check each line).
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree, NOT yet published."

if ! kwt_finalize; then
  echo "Error: push failed after the archive commit — the sweep is committed LOCALLY in" >&2
  echo "       the kanban worktree but NOT on ${KWT_REMOTE}. See the recovery text above." >&2
  exit 1
fi
# KWT_LANDED_SHA is read after the push and the ancestry check, so it names a trunk commit.
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${MSG}\""
# AN `if`, NOT AN `&&` CHAIN: the chain returns non-zero when the shas match (the normal case),
# and under `set -e` that aborts after a successful landing.
if [ -n "${KWT_LANDED_SHA:-}" ] && [ "${KWT_LANDED_SHA}" != "${SHA}" ]; then
  echo "  (the push rebased onto ${KWT_REMOTE}/${DEFAULT_BRANCH}; the landed commit is ${KWT_LANDED_SHA}, not ${SHA})"
fi

echo ""
echo "Done. Swept + pushed:"
echo "  - ${#FILES[@]} move(s): progress/qa_complete/ → progress/done/"
if [ ${#SUBTASK_TREES[@]} -gt 0 ]; then
  echo "  - ${#SUBTASK_TREES[@]} subtask-tree move(s): progress/subtasks/ → progress/done/subtasks/"
fi
echo "  - ARCHIVE.md index update"
