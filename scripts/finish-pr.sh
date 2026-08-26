#!/usr/bin/env bash
# KIT-CLASS: KIT — forge-agnostic squash-merge landing; pure git. See process/EXTRACTION.md.
# QA's PASS ritual in one command — FORGE-AGNOSTIC, pure git (no forge CLI, no forge API).
#
# Squash-merges the issue's feature branch into the TRUNK locally, pushes the
# trunk, deletes the branch (local + remote), and advances the issue file from
# progress/dev_complete/ → progress/qa_complete/. There is no forge dependency
# and none is needed: QA's review evidence lives in the issue file's Activity log,
# not in a PR/MR. That choice has been PAID FOR ONCE ALREADY — the donor project
# migrated forge hosts mid-life and this script needed zero changes — so the
# portable path is measured, not speculative. It also means the kit works against
# a bare repo on a USB disk with no forge at all (see process/GIT-HOSTING.md).
#
# THE BOARD NOTE NEVER CLAIMS MORE THAN THE RUN DID. The branch-delete step
# surfaces git's own errors, CONFIRMS the remote delete by re-measuring the
# remote rather than trusting the push's exit code, and the default Activity note
# is composed from those two outcomes AFTER the attempt — never before it. A
# branch that survives is reported loudly and NON-fatally: the merge has already
# landed, so a surviving branch is residue, not a failed landing.
#
# All trunk git ops happen inside the standing detached `.kanban-wt/` worktree
# (see scripts/lib/kanban-worktree.sh), which is pinned to the trunk, so the
# operator's main checkout is never hijacked; if it is sitting clean on the trunk
# it gets fast-forwarded so the board view stays live.
#
# Equivalent to running by hand:
#   git -C .kanban-wt merge --squash feature/<ID>-<slug>
#   git -C .kanban-wt commit -m "[QA] <ID>: <title> (squash-merge …)"
#   git -C .kanban-wt push <remote> HEAD:<trunk>
#   git branch -D feature/<ID>-<slug>   &&   git push <remote> --delete feature/<ID>-<slug>
#   ./scripts/move-issue.sh <ID> qa_complete --role QA --note "Review — PASS. Squash-merged."
#
# FORGE-PR FLAVOR (an available extension, not the default): a team that wants
# MR/PR ceremony can add a branch here that opens + merges via a forge CLI instead
# of the local squash, and pass the resulting number to move-issue.sh --set-pr.
# It is deliberately NOT the default. The [Role] prefix on the squash commit is
# the audit trail either way.
#
# Usage:
#   ./scripts/finish-pr.sh <ID> [--branch <name>] [--worktree <path>] [--note "..."] [--dry-run] [--discard-dirty]
#
# Without --branch, the branch is read from the issue file's `branch:`
# frontmatter in progress/dev_complete/.
# --worktree <path>: run the BLOCKING pre-merge gate against a genuine git
#   worktree of THIS repo (the QA's own checkout of the branch) instead of the
#   main checkout — needed when the main checkout belongs to a parallel leg. The
#   gate ALWAYS runs that worktree's TRACKED scripts/verify.sh --quick; the path
#   must be a real registered worktree of this repo whose scripts/verify.sh is
#   committed and unmodified. THE CALLER NAMES A LOCATION, NEVER A COMMAND, so a
#   fabricated `echo PASS; exit 0` stub has nowhere to enter — that hole was used
#   once, in earnest, to force a landing. The command seam
#   (FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD) now exists ONLY for the
#   sandbox self-test and is refused on the production path unless
#   FINISH_PR_TEST_ALLOW_STUB=1 (set only by scripts/test/run.sh).
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync — propagated to the move sub-step.
#
# Examples:
#   ./scripts/finish-pr.sh <PREFIX>-001
#   ./scripts/finish-pr.sh <PREFIX>-001 --branch feature/<PREFIX>-001-my-slug
#   ./scripts/finish-pr.sh <PREFIX>-001 --worktree /tmp/wt-qa-001   # gate the QA's checkout
#   ./scripts/finish-pr.sh <PREFIX>-001 --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# --help renders the header block, with the window END DERIVED rather than
# hard-coded: a literal `sed -n '3,50p'` silently truncated the Usage/Examples
# tail off --help the first time the header gained a paragraph.
usage() {
  local src="${BASH_SOURCE[0]}" first end
  first="$(awk 'NR>2 && !/^#/{print NR; exit}' "$src")"
  end=$(( ${first:-0} - 1 )); [ "$end" -lt 3 ] && end=3
  sed -n "3,${end}p" "$src" | sed 's|^# \{0,1\}||'
}

# The creation scripts' option hygiene applies to the LANDING script too
# (process/contracts/issue-creation.md § 3 states the rule): --help exits 0
# rather than 1, a leading '-' is never an issue id, and an unknown option
# refuses with rc=2 instead of being swallowed. The dangerous shape is a wrong
# arg accepted WITH a success message.
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

ISSUE_ID="${1:-}"
[ -z "$ISSUE_ID" ] && { usage >&2; exit 1; }
case "$ISSUE_ID" in
  -*) echo "Error: '$ISSUE_ID' is not an issue id — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
esac
shift

BRANCH=""; NOTE=""; NOTE_GIVEN=false; DRY_RUN=false; DISCARD_DIRTY=false; WORKTREE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="${2:-}"; shift 2 ;;
    --worktree) WORKTREE="${2:-}"; shift 2 ;;
    --note) NOTE="${2:-}"; NOTE_GIVEN=true; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --discard-dirty) DISCARD_DIRTY=true; KWT_DISCARD_DIRTY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Resolve repo root + trunk (works from any worktree, incl. a feature branch).
kwt_resolve

# ── THE GATE EXECUTABLE IS NEVER CALLER-CHOSEN. The blocking pre-merge gate runs
#    a TRACKED scripts/verify.sh that finish-pr.sh CHOOSES. The env-command seams
#    (FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD) exist ONLY for the sandbox
#    self-test harness and are honored ONLY behind an explicit test-only marker
#    (FINISH_PR_TEST_ALLOW_STUB=1) that the harness sets and no worktree-QA
#    wrapper or default landing path ever sets. On the production path an attempt
#    to inject a gate command is REFUSED loudly before any destructive step —
#    this is what closes the fabricated-stub hole (a scratch `echo PASS; exit 0`
#    pointed at via FINISH_PR_PREMERGE_CMD once forced a landing through a red
#    suite). The legitimate worktree-QA capability is preserved as
#    --worktree <path>: a LOCATION, not a command, whose tracked scripts/verify.sh
#    finish-pr.sh runs itself.
ALLOW_STUB=false
[ "${FINISH_PR_TEST_ALLOW_STUB:-}" = "1" ] && ALLOW_STUB=true
if [ "$ALLOW_STUB" != "true" ] && { [ -n "${FINISH_PR_PREMERGE_CMD:-}" ] || [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; }; then
  {
    echo "Error: refusing a caller-supplied gate command on the production landing path."
    echo "       FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD are honored ONLY behind the"
    echo "       test-only marker FINISH_PR_TEST_ALLOW_STUB=1 (set by scripts/test/run.sh)."
    echo "       The pre-merge gate runs a TRACKED scripts/verify.sh that finish-pr.sh chooses;"
    echo "       to gate against a parallel leg's checkout, pass --worktree <path> instead."
  } >&2
  exit 1
fi

# Resolve the checkout whose TRACKED scripts/verify.sh the pre-merge gate runs.
# Default = the repo root finish-pr resolved. --worktree overrides it, but ONLY
# to a genuine git worktree of THIS repo whose scripts/verify.sh is committed and
# unmodified — so a scratch dir carrying a fabricated verify.sh has nowhere to
# enter (a scratch dir is not a registered worktree; an edited-but-uncommitted
# verify.sh trips the clean-vs-HEAD check).
GATE_WORKTREE="$MAIN_ROOT"
if [ -n "$WORKTREE" ]; then
  _err=""
  if [ ! -d "$WORKTREE" ]; then
    _err="--worktree '$WORKTREE' is not a directory"
  else
    _wt_common="$( cd "$WORKTREE" 2>/dev/null && d="$(git rev-parse --git-common-dir 2>/dev/null)" && cd "$d" 2>/dev/null && pwd )"
    _this_common="$( cd "$MAIN_ROOT" && d="$(git rev-parse --git-common-dir 2>/dev/null)" && cd "$d" 2>/dev/null && pwd )"
    if [ -z "$_wt_common" ] || [ "$_wt_common" != "$_this_common" ]; then
      _err="--worktree '$WORKTREE' is not a git worktree of THIS repo"
    elif [ ! -x "$WORKTREE/scripts/verify.sh" ]; then
      _err="'$WORKTREE/scripts/verify.sh' is missing or not executable"
    elif ! git -C "$WORKTREE" cat-file -e HEAD:scripts/verify.sh 2>/dev/null; then
      _err="'$WORKTREE/scripts/verify.sh' is not tracked at HEAD (the gate runs the COMMITTED verify.sh)"
    elif ! git -C "$WORKTREE" diff --quiet HEAD -- scripts/verify.sh 2>/dev/null; then
      _err="'$WORKTREE/scripts/verify.sh' has uncommitted modifications (refusing a possibly-tampered gate)"
    fi
  fi
  if [ -n "$_err" ]; then
    {
      echo "Error: $_err — refusing before any destructive step."
      echo "       --worktree must name a genuine worktree of this repo whose tracked"
      echo "       scripts/verify.sh is what runs (the executable is never caller-chosen)."
    } >&2
    exit 1
  fi
  GATE_WORKTREE="$WORKTREE"
fi

# Take the lock + bootstrap + sync the worktree to <remote>/<trunk> BEFORE reading
# the issue file, so the branch read sees the current trunk state.
kwt_lock
kwt_bootstrap
kwt_sync

# Find the issue file in dev_complete/ inside the kanban worktree.
SRC=""
while IFS= read -r f; do
  SRC="$f"
done < <(find "$KWT/progress/dev_complete" -maxdepth 1 -name "${ISSUE_ID}-*.md" -type f 2>/dev/null)

if [ -z "$SRC" ]; then
  echo "Error: ${ISSUE_ID} not found in progress/dev_complete/." >&2
  echo "       finish-pr.sh only lands issues sitting in dev_complete/." >&2
  exit 1
fi

# Resolve the branch to merge (frontmatter unless --branch given).
if [ -z "$BRANCH" ]; then
  BRANCH=$(awk '/^branch:/{sub(/^branch: */, ""); print; exit}' "$SRC")
  if [ -z "$BRANCH" ]; then
    echo "Error: no 'branch:' frontmatter in ${SRC#"$KWT"/}; pass --branch <name>." >&2
    exit 1
  fi
fi

# A title for the squash commit subject.
TITLE=$(awk '/^title:/{sub(/^title: */, ""); print; exit}' "$SRC")
[ -z "$TITLE" ] && TITLE="$ISSUE_ID"
# THE DEFAULT ACTIVITY NOTE IS NOT COMPOSED HERE. It used to be — `…; branch
# deleted.` hard-coded a hundred lines BEFORE the delete arms — so the board
# recorded an unconditional claim written in advance, true or false, and eight
# consecutive landings logged a deletion that had not happened. The note is now
# composed AFTER the delete arms from what they actually did (see the NOTE_GIVEN
# block below them). An operator-supplied --note is still honored verbatim and is
# never overwritten.

# The branch must exist locally (its commits are what we squash).
if ! git -C "$MAIN_ROOT" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "Error: local branch '$BRANCH' not found. Pass --branch or check it out first." >&2
  exit 1
fi

SQUASH_MSG="[QA] ${ISSUE_ID}: ${TITLE} (squash-merge ${BRANCH})"

echo "Plan:"
echo "  - Squash-merge '${BRANCH}' → '${DEFAULT_BRANCH}' (in .kanban-wt), commit: \"${SQUASH_MSG}\""
echo "  - Push HEAD → ${KWT_REMOTE}/${DEFAULT_BRANCH}"
echo "  - Delete branch '${BRANCH}' (local + remote if present)"
if [ "$NOTE_GIVEN" = "true" ]; then
  echo "  - Move ${ISSUE_ID}: dev_complete/ → qa_complete/ (Activity: \"${NOTE}\")"
else
  echo "  - Move ${ISSUE_ID}: dev_complete/ → qa_complete/ (Activity note composed AFTER the delete step, from what it actually did)"
fi

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "(dry run — no changes made. Re-run without --dry-run to apply.)"
  exit 0
fi

# ── BLOCKING pre-merge gate. Run a quick gate on the code BEFORE the
#    squash-merge; a RED gate ABORTS here — nothing destructive has happened
#    yet (no squash, no push, no branch deletion, no issue advance). The gate is
#    the TRACKED $GATE_WORKTREE/scripts/verify.sh --quick, an executable
#    finish-pr.sh chooses — never a caller-supplied command. The
#    FINISH_PR_PREMERGE_CMD stub is honored only behind FINISH_PR_TEST_ALLOW_STUB
#    (already validated above). The lock is held here, so the EXIT-trap
#    kwt_unlock releases it on abort.
echo ""
echo "Pre-merge gate (blocking): ${GATE_WORKTREE}/scripts/verify.sh --quick"
if [ ! -x "$GATE_WORKTREE/scripts/verify.sh" ] && [ "$ALLOW_STUB" != "true" ]; then
  {
    echo "Error: no executable ${GATE_WORKTREE}/scripts/verify.sh — refusing to land."
    echo "       The gate runner is a HARD landing precondition, not a recommendation"
    echo "       (process/contracts/verify-gate.md). Write it — scripts/verify.sh ships"
    echo "       as a frame with an empty gate table; declare your gates in it — or"
    echo "       generate one: ./scripts/kit-init.sh --gate-command '<your test command>'"
  } >&2
  exit 1
fi
if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_PREMERGE_CMD:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the test-only stub
  PREMERGE_CMD=(${FINISH_PR_PREMERGE_CMD})
else
  PREMERGE_CMD=("$GATE_WORKTREE/scripts/verify.sh" --quick)
fi
if "${PREMERGE_CMD[@]}"; then
  echo "  pre-merge verify --quick: PASS"
else
  {
    echo "Error: pre-merge gate FAILED — refusing to merge '${BRANCH}'."
    echo "       No squash, no push, no branch deletion, no issue advance."
    echo "       Fix the branch so the quick gate is green, then re-run finish-pr.sh."
  } >&2
  exit 1
fi

# ── Squash-merge inside the detached kanban worktree (already synced to trunk).
#    --squash stages the branch's net changes onto the trunk tip WITHOUT moving
#    HEAD or recording a merge; we then make one [Role]-prefixed commit.
echo ""
echo "Squash-merging '${BRANCH}' → ${DEFAULT_BRANCH}..."
if ! git -C "$KWT" merge --squash "$BRANCH" >/dev/null 2>&1; then
  {
    echo "Error: squash-merge of '${BRANCH}' hit conflicts (has ${DEFAULT_BRANCH} advanced?)."
    echo "       Nothing was pushed. Resolve by hand, then push + move:"
    echo "         cd '$KWT' && git merge --squash '$BRANCH'   # resolve, then:"
    echo "         git -C '$KWT' commit -m '${SQUASH_MSG}' && git -C '$KWT' push ${KWT_REMOTE} HEAD:${DEFAULT_BRANCH}"
  } >&2
  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null || true
  exit 1
fi

# ── Empty-merge ABORT. Nothing staged → the branch has no net change vs the
#    trunk (already merged, or a mistyped/stale branch). ABORT nonzero WITHOUT
#    destroying state: do NOT delete the branch, do NOT advance the issue. (An
#    earlier version fell through here to branch deletion + advance, destroying a
#    mistyped branch with no landed code.)
if git -C "$KWT" diff --cached --quiet 2>/dev/null; then
  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null || true
  {
    echo "Error: '${BRANCH}' has no net changes vs ${DEFAULT_BRANCH} — nothing to merge."
    echo "       Aborting: the branch is NOT deleted and ${ISSUE_ID} stays in dev_complete/."
    echo "       (If '${BRANCH}' was already merged, delete the stale branch by hand.)"
  } >&2
  exit 1
fi

git -C "$KWT" commit -m "$SQUASH_MSG" --quiet
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Squash commit: ${SHA} on ${DEFAULT_BRANCH} — \"${SQUASH_MSG}\""
# Push HEAD → trunk and keep the operator's checkout / local ref current.
# A push failure AFTER the local commit is fatal — kwt_finalize prints the loud
# recovery text; ABORT here rather than proceeding to branch deletion.
if ! kwt_finalize; then
  echo "Error: push failed after the squash commit — aborting BEFORE branch deletion (${ISSUE_ID} NOT advanced)." >&2
  exit 1
fi

# Release our lock so the move-issue.sh sub-invocation can acquire it (not reentrant).
kwt_unlock

# ── Delete the branch (local + remote). If the operator's main checkout is sitting
#    ON the branch (the common "board moves from a feature branch" case), switch it
#    to the trunk first — the work has landed, so returning to the trunk is correct.
MAIN_HEAD="$(git -C "$MAIN_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "")"
if [ "$MAIN_HEAD" = "$BRANCH" ]; then
  if git -C "$MAIN_ROOT" diff --quiet 2>/dev/null && git -C "$MAIN_ROOT" diff --cached --quiet 2>/dev/null; then
    if git -C "$MAIN_ROOT" checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null; then
      echo "Switched the main checkout to ${DEFAULT_BRANCH} (the branch is about to be deleted)."
    else
      echo "Note: could not switch the main checkout to ${DEFAULT_BRANCH}; delete '${BRANCH}' by hand." >&2
    fi
  else
    echo "Note: main checkout is on '${BRANCH}' with local changes — not switching; '${BRANCH}' left undeleted." >&2
  fi
fi

# ── THE DELETE ARMS REPORT WHAT THEY ACTUALLY DID.
#    Both git calls used to be silenced with `>/dev/null 2>&1` and a failure was a
#    bare `Note:` on stderr changing no exit code — so a refused delete was
#    indistinguishable from a successful one in any filtered log, while the board
#    note (composed a hundred lines earlier) claimed "branch deleted" either way.
#    Four things are true here, and the exit code is deliberately NOT one of them:
#      1. git's own stderr is SURFACED, never sent to /dev/null;
#      2. the remote outcome is CONFIRMED BY RE-MEASURING the remote after the
#         push — an exit-0 push whose ref is still advertised afterwards is caught
#         and named. That is not hypothetical: a landing printed the success line
#         (so the push exited 0) and the ref was still on the remote, and a
#         controlled re-run reproduced it — deleted, absent for 150s, then back at
#         the identical SHA. The push is not the liar; something re-creates the
#         ref. Only a measurement catches that, never an exit code;
#      3. the ls-remote GATE distinguishes its three outcomes (present / absent /
#         the probe itself failed). It used to collapse the last two into a silent
#         no-attempt path that printed nothing at all;
#      4. each arm records an outcome in a variable the Activity note is built from.
#    WHY EXIT 0 STAYS 0: the merge has already landed and been pushed. A surviving
#    branch is residue, not a failed landing. So the report is LOUD, unmissable and
#    NON-FATAL, and it names the one command that finishes the job.
#    The local-skip-in-a-worktree rule and $KWT_REMOTE are preserved; the script
#    stays forge-agnostic — pure git, no forge CLI, no forge API.

# Delete the local branch unless it is still checked out somewhere.
LOCAL_DELETE_STATE="unknown"
if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null | grep -qxF "branch refs/heads/$BRANCH"; then
  LOCAL_DELETE_STATE="worktree-held"
  _wt_holder="$(git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null \
    | awk -v b="branch refs/heads/$BRANCH" '/^worktree /{w=substr($0,10)} $0==b{print w; exit}')"
  {
    echo "Note: local branch '${BRANCH}' was NOT deleted — it is checked out in a worktree:"
    echo "        ${_wt_holder:-(unknown worktree)}"
    echo "      Force-deleting a branch another worktree holds is not a fix. When that"
    echo "      worktree is done: git -C '${MAIN_ROOT}' branch -D '${BRANCH}'"
  } >&2
elif ! git -C "$MAIN_ROOT" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null 2>&1; then
  LOCAL_DELETE_STATE="absent"
  echo "Local branch '${BRANCH}' is already gone — nothing to delete."
else
  if _local_out="$(git -C "$MAIN_ROOT" branch -D "$BRANCH" 2>&1)"; then
    LOCAL_DELETE_STATE="deleted"
    echo "Deleted local branch '${BRANCH}'."
  else
    LOCAL_DELETE_STATE="failed"
    {
      echo "Note: local branch '${BRANCH}' could NOT be deleted — git said:"
      printf '%s\n' "$_local_out" | sed 's/^/        /'
      echo "      Delete it by hand: git -C '${MAIN_ROOT}' branch -D '${BRANCH}'"
    } >&2
  fi
fi

# Delete the remote branch only if it exists on the remote (honor $KWT_REMOTE).
REMOTE_DELETE_STATE="unknown"
_probe_out="$(git -C "$MAIN_ROOT" ls-remote --exit-code --heads "$KWT_REMOTE" "$BRANCH" 2>&1)" \
  && _probe_rc=0 || _probe_rc=$?
case "$_probe_rc" in
  0)
    _push_out="$(git -C "$MAIN_ROOT" push "$KWT_REMOTE" --delete "$BRANCH" 2>&1)" \
      && _push_rc=0 || _push_rc=$?
    _confirm_out="$(git -C "$MAIN_ROOT" ls-remote --heads "$KWT_REMOTE" "$BRANCH" 2>&1)" \
      && _confirm_rc=0 || _confirm_rc=$?
    if [ "$_push_rc" -ne 0 ]; then
      REMOTE_DELETE_STATE="failed"
      {
        echo "WARNING: could NOT delete remote branch '${KWT_REMOTE}/${BRANCH}' — the push exited ${_push_rc} and git said:"
        printf '%s\n' "$_push_out" | sed 's/^/           /'
        echo "         The LANDING IS FINE: '${BRANCH}' is merged and ${DEFAULT_BRANCH} is pushed."
        echo "         What survived is the remote branch. Finish the job with:"
        echo "           git -C '${MAIN_ROOT}' push ${KWT_REMOTE} --delete '${BRANCH}'"
      } >&2
    elif [ "$_confirm_rc" -ne 0 ]; then
      REMOTE_DELETE_STATE="unconfirmed"
      {
        echo "WARNING: the delete of '${KWT_REMOTE}/${BRANCH}' reported success but could NOT be confirmed —"
        echo "         the follow-up ls-remote exited ${_confirm_rc} and said:"
        printf '%s\n' "$_confirm_out" | sed 's/^/           /'
        echo "         Treat the branch as POSSIBLY STILL PRESENT. Check with:"
        echo "           git -C '${MAIN_ROOT}' ls-remote --heads ${KWT_REMOTE} '${BRANCH}'"
      } >&2
    elif [ -n "$_confirm_out" ]; then
      REMOTE_DELETE_STATE="survived"
      {
        echo "WARNING: '${KWT_REMOTE}/${BRANCH}' SURVIVED a delete that reported SUCCESS."
        echo "         git push --delete exited 0 and said:"
        printf '%s\n' "$_push_out" | sed 's/^/           /'
        echo "         ...yet ${KWT_REMOTE} still advertises the ref:"
        printf '%s\n' "$_confirm_out" | sed 's/^/           /'
        echo "         The LANDING IS FINE: '${BRANCH}' is merged and ${DEFAULT_BRANCH} is pushed."
        echo "         This is residue, and an exit code cannot see it — only this measurement can."
        echo "         Something is RE-CREATING the ref (a mirror or a sync pushing back into"
        echo "         ${KWT_REMOTE}?), or the remote accepted the delete without applying it."
        echo "         Re-run:  git -C '${MAIN_ROOT}' push ${KWT_REMOTE} --delete '${BRANCH}'"
        echo "         If it returns again, that is a REMOTE-SIDE question, not a git one."
      } >&2
    else
      REMOTE_DELETE_STATE="deleted"
      echo "Deleted remote branch '${KWT_REMOTE}/${BRANCH}' (confirmed gone by ls-remote)."
    fi
    ;;
  2)
    REMOTE_DELETE_STATE="absent"
    echo "Remote branch '${KWT_REMOTE}/${BRANCH}' is not on '${KWT_REMOTE}' — nothing to delete."
    ;;
  *)
    REMOTE_DELETE_STATE="probe-failed"
    {
      echo "Note: could not tell whether '${BRANCH}' exists on '${KWT_REMOTE}' — the ls-remote probe"
      echo "      exited ${_probe_rc} and said:"
      printf '%s\n' "$_probe_out" | sed 's/^/        /'
      echo "      NO delete was attempted, so the remote branch may still be there. Check with:"
      echo "        git -C '${MAIN_ROOT}' ls-remote --heads ${KWT_REMOTE} '${BRANCH}'"
    } >&2
    ;;
esac

# ── Compose the Activity note HERE, from the two outcome variables, so the board
#    can never record a deletion the run did not perform. An operator-supplied
#    --note wins and is left exactly as given.
if [ "$NOTE_GIVEN" != "true" ]; then
  case "$LOCAL_DELETE_STATE" in
    deleted)       _local_clause="local branch deleted" ;;
    absent)        _local_clause="local branch already gone" ;;
    worktree-held) _local_clause="LOCAL BRANCH KEPT (still checked out in a worktree)" ;;
    *)             _local_clause="LOCAL BRANCH NOT DELETED (see the run output)" ;;
  esac
  case "$REMOTE_DELETE_STATE" in
    deleted)     _remote_clause="${KWT_REMOTE} branch deleted (confirmed gone)" ;;
    absent)      _remote_clause="nothing on ${KWT_REMOTE} to delete" ;;
    survived)    _remote_clause="${KWT_REMOTE} BRANCH STILL PRESENT after a delete that reported success — needs a manual sweep" ;;
    unconfirmed) _remote_clause="${KWT_REMOTE} delete UNCONFIRMED (the follow-up ls-remote failed)" ;;
    failed)      _remote_clause="${KWT_REMOTE} BRANCH NOT DELETED (the push was refused)" ;;
    probe-failed) _remote_clause="${KWT_REMOTE} NOT PROBED, no delete attempted" ;;
    *)           _remote_clause="${KWT_REMOTE} branch state UNKNOWN" ;;
  esac
  NOTE="Review — PASS. Squash-merged '${BRANCH}' into ${DEFAULT_BRANCH}; ${_local_clause}; ${_remote_clause}."
fi

# ── Advance the issue dev_complete/ → qa_complete/. move-issue.sh inherits the
#    full worktree machinery: lock + bootstrap + sync + commit + push + board-view ff.
echo ""
echo "Advancing ${ISSUE_ID} → qa_complete/..."
MOVE_ARGS=("$ISSUE_ID" qa_complete --role QA --note "$NOTE")
[ "$DISCARD_DIRTY" = "true" ] && MOVE_ARGS+=(--discard-dirty)
"$SCRIPT_DIR/move-issue.sh" "${MOVE_ARGS[@]}"

echo ""
echo "Done. ${ISSUE_ID} landed on '${DEFAULT_BRANCH}' and is now in progress/qa_complete/ (pushed)."

# Post-merge mechanical check. Runs the TRACKED verify.sh --quick and SURFACES
# the result, but must NOT gate: the `if` wrapper is load-bearing so `set -e` can't
# abort on a red gate. The executable is finish-pr's chosen tracked verify.sh,
# never a caller command; the FINISH_PR_VERIFY_CMD stub is honored only behind
# FINISH_PR_TEST_ALLOW_STUB (validated at the top, so a production caller that set
# it has already been refused before any merge happened).
echo ""
echo "Post-merge mechanical check (surfaced, not blocking):"
if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the test-only stub
  POSTMERGE_CMD=(${FINISH_PR_VERIFY_CMD})
else
  POSTMERGE_CMD=("$GATE_WORKTREE/scripts/verify.sh" --quick)
fi
if "${POSTMERGE_CMD[@]}"; then
  echo "  post-merge verify --quick: PASS"
else
  echo "  post-merge verify --quick: FAIL — ${DEFAULT_BRANCH} may be red; fix it ON ${DEFAULT_BRANCH}, do not park it." >&2
fi
