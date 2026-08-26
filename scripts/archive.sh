#!/usr/bin/env bash
# KIT-CLASS: KIT — qa_complete -> done sweep + ARCHIVE.md index. See process/EXTRACTION.md.
# Sweep progress/qa_complete/ off the active board: index each issue in
# ARCHIVE.md AND move the full issue file into progress/done/ (the permanent
# home for completed stories). Completed stories are PRESERVED — they are never
# removed, only moved out of the active five-column board into done/.
# ARCHIVE.md stays the condensed, searchable index; done/ holds the full bodies.
#
# ALL git ops (the ARCHIVE.md edit, the `git mv`, the commit, the push) happen
# inside the STANDING detached `.kanban-wt/` worktree pinned to the trunk —
# NEVER the operator's current checkout. So a sweep run while the checkout sits
# on a feature branch lands the board change on the TRUNK (and the remote),
# leaving the feature branch's tree clean. The sweep is self-committing; the
# commit is attributed `[Orchestrator]` (a session-close housekeeping action).
#
# Defaults to dry-run (prints what would be swept). Pass --apply to prepend
# one-line entries to ARCHIVE.md, `git mv` the issue files into progress/done/,
# commit, and push HEAD → the trunk.
#
# Usage:
#   ./scripts/archive.sh           # dry run (previews against the trunk)
#   ./scripts/archive.sh --apply   # apply: commit + push the sweep

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── THE PREFIX HAS ONE AUTHORITY: scripts/config.sh. ─────────────────────────
# This script used to carry `: "${ISSUE_PREFIX:=<a literal>}"` here — a SECOND
# default below config.sh's own, so the sweep still ran with the seam missing.
# It was well meant, and it replaced something worse (this was once the ONE
# script that defaulted to a FOREIGN project's prefix, masked only because
# config.sh is sourced first), so THE REASON SURVIVES: a silently wrong prefix is
# the expensive failure, not a missing one. The CONCLUSION is superseded, because
# the literal reproduced that very failure one level down — five scripts each
# holding their own copy of one project's prefix, so changing the prefix meant
# changing it in five places, and here the cost is worse than a bad mint: a sweep
# under the wrong prefix silently finds NOTHING and reports "nothing to sweep" on
# a full column. So: NO fallback literal anywhere.
# The same block is in new-issue.sh, new-bug.sh, new-refactor.sh, next-id.sh and
# archive.sh — change one, change all five (grep 'THE PREFIX HAS ONE AUTHORITY').
CONFIG="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing or could not be sourced."
    echo "       Looked for: $CONFIG"
    echo "       It is the ONE authority for ISSUE_PREFIX (process/contracts/config-seam.md)."
    echo "       This sweep REFUSES to guess: under a guessed prefix it would find no"
    echo "       issue files at all and report 'nothing to sweep' on a full column."
    echo "       Restore it (git checkout -- scripts/config.sh), or initialize the kit:"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
  } >&2
  exit 1
fi
if [ -z "${ISSUE_PREFIX:-}" ]; then
  echo "Error: scripts/config.sh was sourced but ISSUE_PREFIX is empty — set it there." >&2
  exit 1
fi

# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

usage() {
  local src="${BASH_SOURCE[0]}" first end
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

DRY_RUN=true
case "${1:-}" in
  --apply) DRY_RUN=false ;;
  ""|--dry-run) DRY_RUN=true ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
esac

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

if ! grep -q '^## Archived$' "$ARCHIVE"; then
  echo "Error: '## Archived' heading not found in $ARCHIVE." >&2
  echo "ARCHIVE.md must have a line containing exactly '## Archived' so this script knows where to insert." >&2
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
  # Already in done/? Test each filename form INDEPENDENTLY — a single `ls a b`
  # with one missing arg returns non-zero even when the other matched (the bug
  # that once hid a whole tree). With nullglob off, an unmatched glob stays
  # literal and `[ -e <literal> ]` is correctly false.
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

# Build entries.
ENTRIES=""
for f in "${FILES[@]}"; do
  ID=$(awk '/^id:/{print $2; exit}' "$f")
  TYPE=$(awk '/^type:/{print $2; exit}' "$f")
  # TITLE is free text (it may legitimately contain '#'), so take it verbatim after 'title: '.
  TITLE=$(awk '/^title:/{sub(/^title: */, ""); print; exit}' "$f")
  # pr / stories are structured fields whose template lines may carry an inline
  # "# comment"; strip a trailing whitespace-preceded comment + surrounding space so
  # the archive index isn't polluted. (The forge-agnostic finish-pr.sh does not
  # rewrite `pr:` unless --set-pr is used, so a template `pr: null   # …` line
  # survives to archive time — hence this guard.)
  strip_comment() { sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]*$//'; }
  PR=$(awk '/^pr:/{sub(/^pr: */, ""); print; exit}' "$f" | strip_comment)
  PRD=$(awk '/^prd:/{print $2; exit}' "$f")
  STORIES=$(awk '/^stories:/{sub(/^stories: */, ""); print; exit}' "$f" | strip_comment)

  ENTRY="- ${ID} [${TYPE}] ${TITLE}"
  if [ -n "$PR" ] && [ "$PR" != "null" ]; then
    ENTRY="${ENTRY} (PR ${PR})"
  fi
  # Cite a PRD only when there is a real one (skip an unfilled template placeholder,
  # "n/a", empty). Cite stories only when real (skip a placeholder and the empty list).
  if [ -n "$PRD" ] && [ "$PRD" != "${PRD_PREFIX:-PRD}-NNN" ] && [ "$PRD" != "n/a" ]; then
    if [ -n "$STORIES" ] && [ "$STORIES" != "[]" ] \
       && ! printf '%s' "$STORIES" | grep -q 'NNN'; then
      ENTRY="${ENTRY} — references ${PRD} ${STORIES}"
    else
      ENTRY="${ENTRY} — references ${PRD}"
    fi
  fi
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
mkdir -p "$DONE_DIR"
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
MSG="[Orchestrator] archive: sweep ${#FILES[@]} issue(s) qa_complete/ → done/${SUBTASK_NOTE} + index in ARCHIVE.md"
git -C "$KWT" commit -m "$MSG" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} on ${DEFAULT_BRANCH} — \"${MSG}\""

if ! kwt_finalize; then
  echo "Error: push failed after the archive commit — the sweep is committed LOCALLY in" >&2
  echo "       the kanban worktree but NOT on ${KWT_REMOTE}. See the recovery text above." >&2
  exit 1
fi

echo ""
echo "Done. Swept + pushed:"
echo "  - ${#FILES[@]} move(s): progress/qa_complete/ → progress/done/"
if [ ${#SUBTASK_TREES[@]} -gt 0 ]; then
  echo "  - ${#SUBTASK_TREES[@]} subtask-tree move(s): progress/subtasks/ → progress/done/subtasks/"
fi
echo "  - ARCHIVE.md index update"
