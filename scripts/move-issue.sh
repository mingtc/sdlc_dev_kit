#!/usr/bin/env bash
# KIT-CLASS: KIT — the board move — the one way status changes. See process/EXTRACTION.md.
# Move an issue file between progress/* folders, append an Activity log
# entry, and commit on the trunk — the atomic status transition.
#
# All kanban git ops happen inside a STANDING worktree pinned to the trunk
# (`.kanban-wt/`, gitignored, bootstrapped on first use). The operator's
# current checkout is NEVER switched. The script:
#   1. Takes a lock, bootstraps + syncs the kanban worktree to <remote>/<trunk>.
#   2. Moves the file (git mv) inside the worktree.
#   3. Appends `- DATE [ROLE] NOTE` to the end of the file.
#   4. Commits with `[ROLE] <ID> → TARGET: NOTE`, pushes HEAD → <trunk>.
#   5. Fast-forwards the main checkout IF it's clean-on-<trunk> (board view).
#
# There is no dirty-tree refusal and no detached-HEAD refusal — the kanban
# worktree is a separate working surface, so the current checkout's state is
# irrelevant. Run this from anywhere (the trunk, a feature worktree, or .kanban-wt).
#
# Usage:
#   ./scripts/move-issue.sh <ID> <target> --role PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect [--note "..."] [--discard-dirty] [--set-pr <val>]
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked | done
#   (done/ is the permanent home for completed stories — normally populated by
#    archive.sh sweeping qa_complete/, but a valid manual target too.)
#
# Flags:
#   --note "..."     Activity-log body. Defaults to "git mv to <target>/."
#   --discard-dirty  If the kanban worktree holds uncommitted tracked changes (a
#                    half-applied move, a loose pr: edit), discard them instead of
#                    aborting. Without it, such state ABORTS the op rather than
#                    being silently reset --hard away.
#
#                    WAIT, NEVER DISCARD — process/contracts/board-mover.md § 2.
#                    The kanban worktree is SHARED between lanes, so uncommitted
#                    state in it may be ANOTHER lane's work-in-progress. The
#                    default on a collision is therefore to stop, print what was
#                    found and both ways out, and exit non-zero: wait and re-run,
#                    never clean up and proceed. Waiting costs a re-run;
#                    discarding costs someone else's session, and it succeeds
#                    silently.
#
#                    --discard-dirty is SINGLE-OPERATOR-ONLY. Use it when you know
#                    the dirty state is your own half-applied move. In any run with
#                    a second lane — a parallel worker, an orchestrated tranche, a
#                    background job that also moves cards — it can destroy work you
#                    never saw. (A real kanban-worktree collision is what wrote
#                    this paragraph.)
#   --set-pr <val>   Persist <val> into the moved file's `pr:` frontmatter, staged
#                    into the SAME commit as the rename + Activity append.
#                    Because the rewrite happens AFTER kwt_sync (in $KWT), it survives
#                    the sync's reset --hard. Idempotent: an already-correct `pr:` line
#                    is left byte-unchanged (no spurious diff). Any trailing comment on
#                    the line is dropped. finish-pr.sh passes the merged PR/MR
#                    reference through this flag when a forge is in play, so the
#                    number is written back to the card.
#
# (There is deliberately no --no-commit: batching was broken by construction —
#  the next op's reset --hard wiped the uncommitted batch. Each move commits + pushes.)
#
# Examples:
#   ./scripts/move-issue.sh <PREFIX>-001 in_progress --role Dev \
#     --note "Picked up. Branch: feature/<PREFIX>-001-<slug>."
#
#   ./scripts/move-issue.sh <PREFIX>-001 dev_complete --role Dev \
#     --note "Ready for review. Branch pushed; gates green."
#
#   ./scripts/move-issue.sh <PREFIX>-014 in_progress --role QA \
#     --note "Review — FAIL on AC. AC unmet: help text missing the example."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# --help renders this file's header block. The window END IS DERIVED, never a
# literal: a hard-coded `sed -n '3,50p'` silently truncated the tail off --help the
# first time somebody added a paragraph to a header, and a bigger literal is the
# same defect with a bigger number. So: everything from line 3 to the last line
# before the first non-comment line.
usage() {
  local src="${BASH_SOURCE[0]}" first end
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

if [ $# -lt 2 ]; then usage >&2; exit 1; fi

ISSUE_ID="$1"; shift
TARGET="$1"; shift
ROLE=""; NOTE=""; SET_PR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    --set-pr) SET_PR="${2:-}"; shift 2 ;;
    --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# The status folder set. It is a SEAM WITHOUT A VARIABLE across four scripts
# (this one, check-board.sh, archive.sh, finish-pr.sh) — process/EXTRACTION.md
# § "the status folder set" states the cost: adding or renaming a column means
# editing all four by hand.
case "$TARGET" in
  todo|in_progress|dev_complete|qa_complete|blocked|done) ;;
  *) echo "Error: target must be one of todo|in_progress|dev_complete|qa_complete|blocked|done (got '$TARGET')" >&2; exit 1 ;;
esac

# THE ROLE SET LIVES IN FOUR PLACES — change one, change all four (the adapter's
# role + prefix tables, scripts/githooks/commit-msg's ROLE_PREFIXES, this
# whitelist, and check-board.sh's derivation fallback). The reason is a measured
# incident: the commit-msg hook accepted a role this whitelist did not, so the
# standing seat COULD NOT MOVE A CARD and had to borrow another hat to do it.
# process/EXTRACTION.md § "The role set and the commit prefixes" names every file.
case "$ROLE" in
  PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect) ;;
  "") echo "Error: --role is required (PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect)." >&2; usage >&2; exit 1 ;;
  *) echo "Error: --role must be PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect (got '$ROLE')" >&2; exit 1 ;;
esac

# Resolve repo root + trunk (works from any worktree).
kwt_resolve

# Acquire the lock BEFORE touching the worktree (never a half-applied move).
# trap-release is armed inside kwt_lock.
kwt_lock

# Bootstrap (idempotent) + sync the worktree to <remote>/<trunk>.
kwt_bootstrap
kwt_sync

# Find file by ID inside the kanban worktree.
MATCHES=()
while IFS= read -r f; do
  MATCHES+=("$f")
done < <(find "$KWT/progress" -name "${ISSUE_ID}-*.md" -type f 2>/dev/null | sort)

if [ ${#MATCHES[@]} -eq 0 ]; then
  # THE PUSH-BEFORE-YOU-MOVE TRAP, replicated three times independently: the
  # message was TRUE and its cause was unfindable. The board this searches is the
  # trunk's copy inside .kanban-wt/, which is reset --hard to <remote>/<trunk> on
  # every op — so a freshly minted card that has not been committed AND PUSHED
  # does not exist here, however plainly it sits in the operator's own checkout.
  echo "Error: no file matching ${ISSUE_ID}-*.md found under progress/." >&2
  echo "       (searched the TRUNK's board inside the kanban worktree, not your checkout.)" >&2
  echo "       Minted but not yet pushed? A new card is invisible here until it reaches the trunk:" >&2
  echo "         git add progress/todo/${ISSUE_ID}-*.md && git commit -m \"[<Role>] ${ISSUE_ID}: mint\" && git push" >&2
  echo "       Otherwise check the id — ls progress/*/ | grep ${ISSUE_ID}" >&2
  exit 1
fi
if [ ${#MATCHES[@]} -gt 1 ]; then
  echo "Error: multiple files match ${ISSUE_ID}-*.md:" >&2
  printf '  %s\n' "${MATCHES[@]}" >&2
  exit 1
fi

SRC="${MATCHES[0]}"
SRC_FOLDER=$(basename "$(dirname "$SRC")")
DEST_DIR="$KWT/progress/$TARGET"
DEST="$DEST_DIR/$(basename "$SRC")"

if [ "$SRC_FOLDER" = "$TARGET" ]; then
  echo "Error: ${ISSUE_ID} is already in progress/${TARGET}/. Nothing to move." >&2
  exit 1
fi

# A missing target folder ABORTS rather than being created: git does not track an
# empty directory, so a board whose columns exist only as .gitkeep-less dirs does
# not survive a clone. kit-init.sh writes one .gitkeep per column for exactly this.
[ -d "$DEST_DIR" ] || { echo "Error: progress/$TARGET/ does not exist in the worktree." >&2; exit 1; }

# Move: prefer `git mv` (tracks rename); fall back to `mv` if untracked.
if git -C "$KWT" ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then
  git -C "$KWT" mv "$SRC" "$DEST"
else
  mv "$SRC" "$DEST"
fi

# Append Activity entry at EOF (Activity must be the last section in the file).
TODAY=$(date +%Y-%m-%d)
[ -z "$NOTE" ] && NOTE="git mv to ${TARGET}/."
ENTRY="- ${TODAY} [${ROLE}] ${NOTE}"

if [ -n "$(tail -c1 "$DEST" 2>/dev/null)" ]; then
  printf '\n' >> "$DEST"
fi
printf '%s\n' "$ENTRY" >> "$DEST"

echo "Moved: progress/${SRC_FOLDER}/ → progress/${TARGET}/"
echo "File:  ${DEST#"$KWT"/}"
echo "Entry: ${ENTRY}"

# --set-pr: persist the resolved PR/MR reference into the moved file's
# `pr:` frontmatter. This runs AFTER kwt_sync's reset --hard (which happened at
# the top of the script) and inside $KWT, so the write is NOT wiped and it gets
# staged into the SAME commit as the rename + Activity append below.
# Idempotent: if the `pr:` line is already exactly the desired value, leave it
# byte-unchanged (no spurious diff). Only the FIRST `^pr:` line (frontmatter) is
# rewritten; any trailing comment on it is dropped.
if [ -n "$SET_PR" ]; then
  if ! grep -qE '^pr:' "$DEST"; then
    echo "Warning: --set-pr '${SET_PR}' given but no 'pr:' frontmatter line in $(basename "$DEST"); skipping write-back." >&2
  else
    DESIRED_LINE="pr: ${SET_PR}"
    CUR_PR_LINE=$(awk '/^pr:/{print; exit}' "$DEST")
    if [ "$CUR_PR_LINE" = "$DESIRED_LINE" ]; then
      echo "pr:    already '${SET_PR}' — left unchanged (idempotent)."
    else
      PR_TMP="$(mktemp)"
      awk -v repl="$DESIRED_LINE" 'BEGIN{done=0} done==0 && /^pr:/{print repl; done=1; next} {print}' "$DEST" > "$PR_TMP"
      mv "$PR_TMP" "$DEST"
      echo "pr:    set to '${SET_PR}' (was: '${CUR_PR_LINE}')"
    fi
  fi
fi

# Stage the destination (git mv already staged the rename; this picks up the
# Activity-entry append + any --set-pr rewrite) and commit in the worktree.
git -C "$KWT" add "$DEST"
MSG="[${ROLE}] ${ISSUE_ID} → ${TARGET}: ${NOTE}"
git -C "$KWT" commit -m "$MSG" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} on ${DEFAULT_BRANCH} — \"${MSG}\""

# Push HEAD → <trunk> and keep the operator's view / local ref current.
# A push failure AFTER the local commit is FATAL — kwt_finalize prints the loud
# recovery text and returns nonzero; propagate it as a nonzero exit rather than
# reporting success on a commit that never reached the remote.
kwt_finalize || exit 1
