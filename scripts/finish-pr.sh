#!/usr/bin/env bash
# KIT-CLASS: KIT — forge-agnostic squash-merge landing; pure git. See process/EXTRACTION.md.
# QA's PASS ritual in one command — FORGE-AGNOSTIC, pure git (no forge CLI, no forge API).
#
# Squash-merges the issue's feature branch into the TRUNK locally, pushes the trunk, deletes the
# branch (local + remote), and advances the issue file from progress/dev_complete/ →
# progress/qa_complete/. QA's review evidence lives in the issue file's Activity log, not in a
# PR/MR, so this works against any remote, including a bare repo with no forge
# (see process/GIT-HOSTING.md).
#
# The default Activity note is composed AFTER the branch delete, from what it did, and the remote
# delete is confirmed by re-reading the remote. A branch that survives is reported loudly and
# NON-fatally: the merge has already landed.
#
# ── EXIT CODES: "IS IT SAFE TO RUN ME AGAIN?", NOT "DID IT LAND?" ──────────────
#   0  Everything the landing gate calls green: re-check passed, one squash commit,
#      published, board advanced, and the branch retired or its survivor named as residue.
#      See contracts/landing-gate.md § 4.
#   1  Refused or failed WITH NOTHING LANDED (a missing <ID> or a surplus argument
#      included). Safe to fix the cause and re-run.
#   2  Usage error: an unknown option or a missing option value. Nothing was read or touched.
#   3  LANDED BUT NOT FINISHED. The squash IS on the trunk; a follow-up step did
#      not complete. **Do NOT re-run this script** — run the recovery it printed.
#
#   FINISH_PR_ROLE   the seat this landing commits as (default: QA). The tag is
#                    CHECKED against your declared role set before anything moves.
#
# A RED POST-MERGE GATE IS NOT A NON-ZERO EXIT: it is a fact about the trunk, not about this
# landing. It is printed as `POST_MERGE_GATE: PASS|FAIL|UNRUNNABLE` for an automation to key on
# (UNRUNNABLE: nothing could be measured). It reads the LANDED COMMIT, and its human line names
# the sha it read.
#
# No COMMIT is made in your checkout: trunk git ops run in the standing detached `.kanban-wt/`
# worktree (scripts/lib/kanban-worktree.sh), and a checkout sitting clean on the trunk is
# fast-forwarded. TWO STEPS DO MOVE A CHECKOUT, and each says so when it does:
#   1. a main checkout sitting clean ON THE BRANCH BY NAME is switched to the trunk
#      before the branch is deleted ("Switched the main checkout to <trunk>");
#   2. after the landing, the post-merge reading DETACHES THE GATE CHECKOUT (the main
#      one, or --worktree's) to the landed commit — before the branch delete, if it holds
#      the branch — unless it is already on the trunk containing it (no move), or has
#      uncommitted tracked changes (not moved; a fresh worktree is read instead).
#
# Equivalent to running by hand:
#   git -C .kanban-wt merge --squash feature/<ID>-<slug>
#   git -C .kanban-wt commit -m "[QA] <ID>: <title> (squash-merge …)"
#   git -C .kanban-wt push <remote> HEAD:<trunk>
#   git branch -D feature/<ID>-<slug>   &&   git push <remote> --delete feature/<ID>-<slug>
#   ./scripts/move-issue.sh <ID> qa_complete --role QA --note "Review — PASS. Squash-merged."
#
#   The `--role` value above IS AN EXAMPLE VALUE: the roles move-issue.sh accepts are the ones its
#   own `--help` lists, from scripts/githooks/commit-msg. Substitute one of yours.
#
# FORGE-PR FLAVOR (an extension, not the default): a team that wants MR/PR ceremony can add a
# branch here that opens and merges via a forge CLI instead of the local squash, and pass the
# resulting number to move-issue.sh --set-pr. The [Role] prefix on the squash commit is the audit
# trail either way.
#
# Usage:
#   ./scripts/finish-pr.sh <ID> [--branch <name>] [--worktree <path>] [--note "..."] [--dry-run] [--discard-dirty]
#
# Without --branch, the branch is read from the issue file's `branch:`
# frontmatter in progress/dev_complete/.
# --worktree <path>: run the BLOCKING pre-merge gate against a genuine git worktree of THIS
#   repo (QA's own checkout of the branch) instead of the main checkout — needed when the main
#   checkout belongs to a parallel leg. The gate ALWAYS runs the trunk's committed
#   scripts/verify.sh --quick in that worktree: the caller names a LOCATION, never a command
#   (FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD are the self-test's seams, refused unless
#   FINISH_PR_TEST_ALLOW_STUB=1). After the landing that worktree is left DETACHED AT THE
#   LANDED COMMIT, where the post-merge check reads the trunk; if it has uncommitted tracked
#   changes it is not moved, and a fresh worktree is read instead.
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync — propagated to the move sub-step.
#
# The gate checkout (the main one, or --worktree's) must be at the branch's tip, and a
# decomposed issue's subtasks (progress/subtasks/<ID>/) must all be in qa_complete/; otherwise
# this refuses before anything moves.
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

# shellcheck source=lib/role-set.sh
. "$SCRIPT_DIR/lib/role-set.sh"

# --help renders the header block; lib/usage.sh derives where the window ends.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh

# Option hygiene (process/contracts/issue-creation.md § 3): --help exits 0 in any position, before
# any argument is interpreted; a leading '-' is never an issue id; an unknown option exits 2
# instead of being swallowed.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

ISSUE_ID="${1:-}"
[ -z "$ISSUE_ID" ] && { usage >&2; exit 1; }
case "$ISSUE_ID" in
  -*) echo "Error: '$ISSUE_ID' is not an issue id — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
esac
shift

BRANCH=""; NOTE=""; NOTE_GIVEN=false; DRY_RUN=false; DISCARD_DIRTY=false; WORKTREE=""
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}


while [ $# -gt 0 ]; do
  case "$1" in
    --branch) need_val "$@"; BRANCH="$2"; shift 2 ;;
    --worktree) need_val "$@"; WORKTREE="$2"; shift 2 ;;
    --note) need_val "$@"; NOTE="$2"; NOTE_GIVEN=true; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --discard-dirty) DISCARD_DIRTY=true; KWT_DISCARD_DIRTY=true; shift ;;
    --apply) { echo "Error: finish-pr.sh has no --apply — it MUTATES by default, which is the opposite"
               echo "       of the archive sweeps. Use --dry-run to preview. NOTHING WAS READ OR TOUCHED."; } >&2
             exit 2 ;;
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# THE SEAT THIS SCRIPT ACTS AS, read once: the squash subject, the --role passed to the mover and
# the recovery text must agree.
ROLE="${FINISH_PR_ROLE:-QA}"
# CHECKED BEFORE kwt_resolve: move-issue.sh would reject a withdrawn role only at the advance,
# after the merge had landed.
kit_require_role "$SCRIPT_DIR/.." "$ROLE" FINISH_PR_ROLE || exit 1

# Resolve repo root + trunk (works from any worktree, incl. a feature branch).
kwt_resolve

# ── THE GATE EXECUTABLE IS NEVER CALLER-CHOSEN. The pre-merge gate runs a TRACKED
#    scripts/verify.sh that finish-pr.sh chooses. FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD
#    are the self-test's seams, honoured only behind FINISH_PR_TEST_ALLOW_STUB=1; on the
#    production path they are refused before any destructive step. Use --worktree <path>.
ALLOW_STUB=false
[ "${FINISH_PR_TEST_ALLOW_STUB:-}" = "1" ] && ALLOW_STUB=true
if [ "$ALLOW_STUB" != "true" ] && { [ -n "${FINISH_PR_PREMERGE_CMD:-}" ] || [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; }; then
  {
    echo "Error: refusing a caller-supplied gate command on the production landing path."
    echo "       FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD are honored ONLY behind the"
    echo "       test-only marker FINISH_PR_TEST_ALLOW_STUB=1 (set by the self-test only)."
    echo "       The pre-merge gate runs a TRACKED scripts/verify.sh that finish-pr.sh chooses;"
    echo "       to gate against a parallel leg's checkout, pass --worktree <path> instead."
  } >&2
  exit 1
fi

# The checkout whose TRACKED scripts/verify.sh the pre-merge gate runs: the repo root, or
# --worktree, which must be a registered worktree of THIS repo with verify.sh committed and
# unmodified.
GATE_WORKTREE="$MAIN_ROOT"
if [ -n "$WORKTREE" ]; then
  _err=""
  if [ ! -d "$WORKTREE" ]; then
    _err="--worktree '$WORKTREE' is not a directory"
  else
    # Both sides PHYSICAL (`pwd -P`): they are compared as strings, and a symlinked spelling of
    # this repo's own path must not read as foreign.
    _wt_common="$( cd "$WORKTREE" 2>/dev/null && d="$(git rev-parse --git-common-dir 2>/dev/null)" && cd "$d" 2>/dev/null && pwd -P )"
    _this_common="$( cd "$MAIN_ROOT" && d="$(git rev-parse --git-common-dir 2>/dev/null)" && cd "$d" 2>/dev/null && pwd -P )"
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
  # ABSOLUTE: the post-merge reading runs the gate from inside this checkout, where a relative
  # spelling names a path that does not exist.
  GATE_WORKTREE="$(cd "$WORKTREE" && pwd)"
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
  # Name the column the card IS in (process/contracts/landing-gate.md § 3): each has its own next step.
  _fpr_at="$(find "$KWT/progress" -maxdepth 2 -name "${ISSUE_ID}-*.md" 2>/dev/null | head -1)"
  if [ -n "$_fpr_at" ]; then
    _fpr_col="$(basename "$(dirname "$_fpr_at")")"
    echo "Error: ${ISSUE_ID} is in progress/${_fpr_col}/, not progress/dev_complete/." >&2
    echo "       finish-pr lands from dev_complete only. Move it there first if QA has handed it back," >&2
    echo "       or land nothing if it is already in qa_complete/." >&2
  else
    echo "Error: ${ISSUE_ID} is in no progress/ folder at all — not dev_complete/, and not anywhere else." >&2
  fi
  echo "       finish-pr.sh only lands issues sitting in dev_complete/." >&2
  exit 1
fi

# A DECOMPOSED PARENT LANDS ONLY WHEN EVERY SUBTASK IS REVIEWED: the advance below would refuse
# after the merge had landed (the mover's rule), so it is refused here, before anything moves.
_open="$(kwt_open_subtasks "$ISSUE_ID")"
if [ -n "$_open" ]; then
  {
    echo "Error: ${ISSUE_ID} has subtask(s) not yet in qa_complete/:"
    printf '%s\n' "$_open" | sed 's/^/    /'
    echo "       A parent advances to qa_complete/ only when every subtask has, so it does not land"
    echo "       before then. Move them with ./scripts/subtask.sh first. NOTHING WAS CHANGED."
  } >&2
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
# The default Activity note is composed AFTER the delete arms, from what they did (the NOTE_GIVEN
# block below them). An operator-supplied --note is used verbatim.

# The branch must exist locally (its commits are what we squash).
if ! git -C "$MAIN_ROOT" rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null 2>&1; then
  echo "Error: local branch '$BRANCH' not found. Pass --branch or check it out first." >&2
  exit 1
fi

# ── THE GATE CHECKOUT MUST HOLD THE COMMITTED verify.sh, AT THE REVISION BEING LANDED
#    (contracts/landing-gate.md § 2), on both paths, and the refusal names which check failed
#    (§ 3). The test is the REVISION, not the ref name: a detached checkout exactly at the branch
#    tip is accepted. This binds the PRE-merge tree only; the post-merge block reads the landed
#    commit. It runs after kwt_sync because `branch:` is read from the kanban worktree; nothing
#    the contract protects has been touched yet.
if [ "$ALLOW_STUB" != "true" ]; then
  _gate_v="$GATE_WORKTREE/scripts/verify.sh"
  _branch_tip="$(git -C "$MAIN_ROOT" rev-parse "refs/heads/$BRANCH" 2>/dev/null || true)"
  _gate_head="$(git -C "$GATE_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  _gate_err=""
  # _gate_absent: no usable gate at all, as opposed to one at the wrong revision; the advice differs.
  _gate_absent=""
  if   [ ! -e "$_gate_v" ]; then _gate_err="MISSING — $_gate_v does not exist"; _gate_absent=true
  elif [ ! -x "$_gate_v" ]; then _gate_err="NOT EXECUTABLE — $_gate_v exists but cannot be run"; _gate_absent=true
  elif [ -z "$_gate_head" ] || [ -z "$_branch_tip" ] || [ "$_gate_head" != "$_branch_tip" ]; then
    _gate_err="NOT AT THE REVISION BEING LANDED — the gate checkout '$GATE_WORKTREE' is at ${_gate_head:0:9}, and '$BRANCH' is at ${_branch_tip:0:9}"
  elif ! git -C "$GATE_WORKTREE" cat-file -e "HEAD:scripts/verify.sh" 2>/dev/null; then
    _gate_err="NOT TRACKED at the revision being landed — scripts/verify.sh is untracked at ${_gate_head:0:9}"
  elif ! git -C "$GATE_WORKTREE" diff --quiet HEAD -- scripts/verify.sh 2>/dev/null; then
    _gate_err="LOCALLY MODIFIED — $_gate_v differs from the committed copy at ${_gate_head:0:9}"
  fi
  if [ -n "$_gate_err" ]; then
    {
      echo "Error: the landing gate is $_gate_err."
      echo "       Refusing BEFORE any destructive step: no squash, no push, no branch"
      echo "       deletion, no issue advance."
      echo "       The gate checkout must hold scripts/verify.sh COMMITTED and unmodified at"
      echo "       the revision being landed; where the branch changes it, the trunk's copy"
      echo "       judges it (process/contracts/landing-gate.md § 2-3). Otherwise the run"
      echo "       proves something about a tree that is not shipping."
      echo ""
      if [ -n "$_gate_absent" ]; then
        echo "  There is no usable gate here at all. The gate runner is a HARD landing"
        echo "  precondition, not a recommendation (process/contracts/verify-gate.md):"
        echo "    • write it — scripts/verify.sh ships as a frame with an EMPTY gate table;"
        echo "      declare your gates in it"
        echo "    • or, ON A FRESH REPO, generate one:  ./scripts/kit-init.sh --gate-command '<your test command>'"
        echo "      (kit-init REFUSES a repository that has already lived; if yours has, write it.)"
      else
        echo "  Two conforming ways to land ${ISSUE_ID}:"
        echo "    • check the branch out here:   git -C '$MAIN_ROOT' checkout '$BRANCH'"
        echo "    • or gate against a worktree that has it:"
        echo "        ./scripts/finish-pr.sh ${ISSUE_ID} --worktree <path-to-a-worktree-on-${BRANCH}>"
        echo "  Either way, the post-merge check then reads ${DEFAULT_BRANCH} at the landed commit: the gate"
        echo "  checkout is switched to ${DEFAULT_BRANCH} or DETACHED there, and one with uncommitted"
        echo "  changes is left alone while a fresh worktree is read instead."
      fi
    } >&2
    exit 1
  fi
fi

SQUASH_MSG="[$ROLE] ${ISSUE_ID}: ${TITLE} (squash-merge ${BRANCH})"

echo "Plan:"
echo "  1. Squash-merge '${BRANCH}' → '${DEFAULT_BRANCH}' (in .kanban-wt), commit: \"${SQUASH_MSG}\""
echo "  2. Push HEAD → ${KWT_REMOTE}/${DEFAULT_BRANCH}"
echo "  3. Delete branch '${BRANCH}' (local + remote if present)"
if [ "$NOTE_GIVEN" = "true" ]; then
  echo "  4. Move ${ISSUE_ID}: dev_complete/ → qa_complete/ (Activity: \"${NOTE}\")"
else
  echo "  4. Move ${ISSUE_ID}: dev_complete/ → qa_complete/ (Activity note composed AFTER the delete step, from what it actually did)"
fi

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "(dry run — no changes made. Re-run without --dry-run to apply.)"
  exit 0
fi

# ── BLOCKING pre-merge gate: a RED gate aborts before anything destructive (no squash, push,
#    branch deletion or issue advance). The lock is held; the EXIT trap releases it.
echo ""
# No executability check here, and do not add one: the gate-provenance block above already
# refuses a missing or non-executable gate, with the advice on what to do about it.
# THE JUDGE IS THE TRUNK'S RUNNER (contracts/landing-gate.md § 2): where the branch changes
# scripts/verify.sh, the trunk's copy runs in the branch's tree, from a sibling file because the
# runner roots itself at its own directory's parent. A killed run can leave that file behind.
_trunk_gate=""
if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_PREMERGE_CMD:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the test-only stub
  PREMERGE_CMD=(${FINISH_PR_PREMERGE_CMD})
elif git -C "$KWT" cat-file -e HEAD:scripts/verify.sh 2>/dev/null \
     && ! git -C "$KWT" diff --quiet HEAD "refs/heads/$BRANCH" -- scripts/verify.sh 2>/dev/null; then
  if ! { _trunk_gate="$(mktemp "$GATE_WORKTREE/scripts/.verify-trunk.XXXXXX")" \
         && git -C "$KWT" show HEAD:scripts/verify.sh > "$_trunk_gate" && chmod +x "$_trunk_gate"; }; then
    [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
    echo "Error: could not stage ${DEFAULT_BRANCH}'s scripts/verify.sh in '${GATE_WORKTREE}/scripts/' — refusing to merge '${BRANCH}'." >&2
    exit 1
  fi
  PREMERGE_CMD=("$_trunk_gate" --quick)
else
  PREMERGE_CMD=("$GATE_WORKTREE/scripts/verify.sh" --quick)
fi
# The banner names the runner that actually runs.
if [ -n "$_trunk_gate" ]; then
  echo "Pre-merge gate (blocking): ${DEFAULT_BRANCH}'s scripts/verify.sh --quick, run in ${GATE_WORKTREE}"
  echo "  '${BRANCH}' changes scripts/verify.sh, so ${DEFAULT_BRANCH}'s copy judges it; the branch's governs from the next landing."
else
  echo "Pre-merge gate (blocking): ${PREMERGE_CMD[*]}"
fi
if "${PREMERGE_CMD[@]}"; then
  [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
  echo "  pre-merge verify --quick: PASS"
else
  _pre_rc=$?
  [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
  # Both reds refuse, named apart: verify.sh exits 3 when a gate could not run (nothing was
  # measured; the fix is in the environment). Any other non-zero status is FAIL.
  {
    if [ "$_pre_rc" -eq 3 ]; then
      echo "Error: pre-merge gate COULD NOT RUN (verify.sh exit 3: a gate never executed, and none failed) — refusing to merge '${BRANCH}'."
      echo "       No squash, no push, no branch deletion, no issue advance."
      echo "       Nothing about the branch was measured: fix what the gate needs to start (its summary names it), then re-run finish-pr.sh."
    else
      echo "Error: pre-merge gate FAILED — refusing to merge '${BRANCH}'."
      echo "       No squash, no push, no branch deletion, no issue advance."
      echo "       Fix the branch so the quick gate is green, then re-run finish-pr.sh."
    fi
  } >&2
  exit 1
fi

# ── Squash-merge inside the detached kanban worktree (already synced to trunk).
#    --squash stages the branch's net changes onto the trunk tip WITHOUT moving
#    HEAD or recording a merge; we then make one [Role]-prefixed commit.
echo ""
echo "Squash-merging '${BRANCH}' → ${DEFAULT_BRANCH}..."
if ! git -C "$KWT" merge --squash "$BRANCH" >/dev/null 2>&1; then
  # Name the issue file only when it IS a conflicted path, matched by basename (the mover may
  # already have moved it on the trunk).
  _fpr_conflicted="$(git -C "$KWT" diff --name-only --diff-filter=U 2>/dev/null)"
  _fpr_card_conflict=""
  case "$(printf '%s\n' "$_fpr_conflicted" | sed 's|.*/||')" in
    *"${ISSUE_ID}-"*.md*) _fpr_card_conflict=yes ;;
  esac
  {
    echo "Error: squash-merge of '${BRANCH}' hit conflicts (has ${DEFAULT_BRANCH} advanced?)."
    if [ -n "$_fpr_card_conflict" ]; then
      echo "       The conflict includes the ISSUE FILE: review evidence was appended on the branch."
      echo "       The card is metadata and is written on the trunk — the board mover edits it there."
    fi
    echo "       Nothing was pushed. Resolve by hand, then push + move:"
    echo "         cd '$KWT' && git merge --squash '$BRANCH'   # resolve, then:"
    echo "         git -C '$KWT' commit -m '${SQUASH_MSG}' && git -C '$KWT' push ${KWT_REMOTE} HEAD:${DEFAULT_BRANCH}"
  } >&2
  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null || true
  exit 1
fi

# ── Empty merge: the branch has no net change vs the trunk. Abort non-zero WITHOUT deleting the
#    branch or advancing the issue.
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
# Two lines, the second after the push: a push race rebases and remakes the commit, so the
# local sha is not yet the published one.
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Squash commit: ${SHA} — made locally in the kanban worktree, NOT yet published."
# Push HEAD → trunk and keep the operator's checkout / local ref current.
# A push failure AFTER the local commit is fatal — kwt_finalize prints the loud
# recovery text; ABORT here rather than proceeding to branch deletion.
if ! kwt_finalize; then
  echo "Error: push failed after the squash commit — aborting BEFORE branch deletion (${ISSUE_ID} NOT advanced)." >&2
  exit 1
fi
# The PUBLISHED sha, from the library that read it back off the ref. If the rebase
# above remade the commit, this is the one on the trunk and ${SHA} is not.
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${SQUASH_MSG}\""
# ── THE RECOVERY IS PRINTED NOW, while the run is healthy (doctrine/fix-execution.md § A.7): a
#    killed run prints no failure branch, and from here the merge is on the trunk.
{
  echo ""
  echo "── LANDED. Steps 1-2 of 4 are DONE and are on ${KWT_REMOTE}/${DEFAULT_BRANCH}."
  echo "   If this run stops here — killed, timed out, disconnected — the landing is"
  echo "   COMPLETE but the cleanup is NOT. Finish it with exactly these two steps:"
  echo "     3. git -C '$MAIN_ROOT' branch -D '${BRANCH}'; git -C '$MAIN_ROOT' push ${KWT_REMOTE} --delete '${BRANCH}'"
  echo "     4. $SCRIPT_DIR/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --note '<what the review found>'"
  echo "   Both are safe to re-run: each half of step 3 may report the branch not found, and"
  echo "   step 4 refuses an issue that is no longer in dev_complete/."
  echo ""
} 
# An `if`, not an `&&` chain: the chain returns non-zero when the shas match, and `set -e` would
# then abort a green landing.
if [ -n "${KWT_LANDED_SHA:-}" ] && [ "${KWT_LANDED_SHA}" != "${SHA}" ]; then
  echo "  (the push rebased onto ${KWT_REMOTE}/${DEFAULT_BRANCH}; the landed commit is ${KWT_LANDED_SHA}, not ${SHA})"
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

# A clean gate checkout ON the branch by name is detached now, where the post-merge reading
# would leave it anyway, so the branch is free to delete.
if [ -n "${KWT_LANDED_SHA:-}" ] \
   && [ "$(git -C "$GATE_WORKTREE" symbolic-ref -q --short HEAD 2>/dev/null || true)" = "$BRANCH" ] \
   && git -C "$GATE_WORKTREE" diff --quiet 2>/dev/null && git -C "$GATE_WORKTREE" diff --cached --quiet 2>/dev/null \
   && git -C "$GATE_WORKTREE" checkout --detach --quiet "$KWT_LANDED_SHA" 2>/dev/null; then
  echo "Detached the gate checkout '${GATE_WORKTREE}' at the landed commit ${KWT_LANDED_SHA} (it was on '${BRANCH}'),"
  echo "  so the branch can be deleted. It is left there: the post-merge check reads it."
fi

# ── THE DELETE ARMS REPORT WHAT THEY DID. git's stderr is shown; the remote delete is CONFIRMED
#    by re-reading the remote (a ref can survive a delete that exited 0); the probe's three
#    outcomes (present / absent / probe failed) are kept apart; each arm records the outcome the
#    Activity note is built from. The exit status is unaffected: a surviving branch is residue.

# Delete the local branch unless it is still checked out somewhere.
LOCAL_DELETE_STATE="unknown"
if git -C "$MAIN_ROOT" worktree list --porcelain 2>/dev/null | grep -xF "branch refs/heads/$BRANCH" >/dev/null; then
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

# ── Compose the Activity note from the two outcome variables, so the board never records a
#    deletion the run did not perform. An operator-supplied --note wins, unchanged.
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
MOVE_ARGS=("$ISSUE_ID" qa_complete --role "$ROLE" --note "$NOTE")
[ "$DISCARD_DIRTY" = "true" ] && MOVE_ARGS+=(--discard-dirty)
# An `if`, not a bare call: under `set -e` a failed move would exit 1 ("nothing landed") after
# the squash landed. This is where exit 3 comes from.
if ! "$SCRIPT_DIR/move-issue.sh" "${MOVE_ARGS[@]}"; then
  LANDED_INCOMPLETE=1
  {
    echo ""
    echo "WARNING: the board advance FAILED — but ${ISSUE_ID} IS LANDED."
    echo "         The squash is on ${KWT_REMOTE}/${DEFAULT_BRANCH}; what did not happen is the"
    echo "         dev_complete/ → qa_complete/ move, so the board still shows it in review."
    echo "         DO NOT re-run this script: the branch is merged and the squash would have"
    echo "         nothing to do. Finish with just the move:"
    echo "           $SCRIPT_DIR/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --note '<what the review found>'"
  } >&2
fi

echo ""
_residue=""
case "$LOCAL_DELETE_STATE" in deleted|absent) ;; *) _residue="local" ;; esac
case "$REMOTE_DELETE_STATE" in deleted|absent) ;; *) _residue="${_residue:+$_residue and }${KWT_REMOTE}" ;; esac
if [ "${LANDED_INCOMPLETE:-0}" -eq 0 ]; then
  echo "Done. ${ISSUE_ID} landed on '${DEFAULT_BRANCH}' and is now in progress/qa_complete/ (pushed).${_residue:+ Residue: the ${_residue} branch '${BRANCH}' is not confirmed gone (see above).}"
else
  echo "LANDED, NOT FINISHED. ${ISSUE_ID} is on '${DEFAULT_BRANCH}'; one or more follow-up steps did not complete (see above)."
fi

# ── POST-MERGE CHECK: surfaced, never gating (the `if` wrappers keep `set -e` off a red).
#    It reads the LANDED COMMIT, never the gate checkout where it stands: the pre-merge gate
#    required that checkout at the branch tip. The tree, in order:
#      1. the gate checkout, if it is ON <trunk> by name, clean, and contains the landed commit;
#      2. else, if clean, the gate checkout DETACHED AT THE LANDED COMMIT, and left there (its
#         installed dependencies survive a detach);
#      3. else (uncommitted tracked changes, or the detach refused) a FRESH detached worktree at
#         the landed commit, removed afterwards — without those dependencies, and it says so;
#      4. no tree, or no executable gate: COULD NOT RUN (contracts/verify-gate.md § 3), as is a
#         gate that exits 3. Never PASS, never FAIL.
#    "The landed commit" means its tracked content; untracked files in the checkout are read too.
#    Every step below is `set -e`-safe: the landing has happened. The operand is KWT_LANDED_SHA
#    (read back after the push), never the kanban worktree's HEAD.
# RULE-COPIES:BEGIN — deliberate copies of where the post-merge reading leaves the gate checkout; the self-test holds them.
# key: detached at the landed commit
# copies: .claude/roles/qa.md
# RULE-COPIES:END
echo ""
echo "Post-merge mechanical check (surfaced, not blocking):"
PM_TREE=""; PM_HOW=""; PM_FRESH_DIR=""; PM_UNRUNNABLE=""; _pm_sum=""; _pm_failed=""
_pm_landed=""
[ -n "${KWT_LANDED_SHA:-}" ] \
  && _pm_landed="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "${KWT_LANDED_SHA}^{commit}" 2>/dev/null || true)"
_pm_clean() { git -C "$1" diff --quiet 2>/dev/null && git -C "$1" diff --cached --quiet 2>/dev/null; }
if [ -z "$_pm_landed" ]; then
  PM_UNRUNNABLE="the landed commit is not known (no published sha was read back), so there is no revision to read"
else
  _pm_head="$(git -C "$GATE_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  _pm_ref="$(git -C "$GATE_WORKTREE" symbolic-ref -q --short HEAD 2>/dev/null || true)"
  _pm_was="${_pm_ref:-a detached HEAD at ${_pm_head:0:9}}"
  _pm_why=""
  if [ "$_pm_ref" = "$DEFAULT_BRANCH" ] && _pm_clean "$GATE_WORKTREE" \
     && git -C "$GATE_WORKTREE" merge-base --is-ancestor "$_pm_landed" "$_pm_head" 2>/dev/null; then
    PM_TREE="$GATE_WORKTREE"
    PM_HOW="the gate checkout, already on ${DEFAULT_BRANCH} and containing the landed commit"
  elif ! _pm_clean "$GATE_WORKTREE"; then
    _pm_why="has uncommitted tracked changes"
  elif [ -z "$_pm_ref" ] && [ "$_pm_head" = "$_pm_landed" ]; then
    PM_TREE="$GATE_WORKTREE"
    PM_HOW="the gate checkout, detached at the landed commit"
  elif _pm_det_err="$(git -C "$GATE_WORKTREE" checkout --detach --quiet "$_pm_landed" 2>&1)"; then
    PM_TREE="$GATE_WORKTREE"
    PM_HOW="the gate checkout, detached to the landed commit"
    echo "  Detached the gate checkout '${GATE_WORKTREE}' at the landed commit ${KWT_LANDED_SHA} (it was on ${_pm_was}),"
    echo "  so this reading is of ${DEFAULT_BRANCH}, not of the branch. It is left there. Tracked content is the"
    echo "  landed commit's; untracked and ignored files in it (installed dependencies) are part of the reading."
  else
    _pm_nl=$'\n'
    _pm_why="refused the detach (git said: ${_pm_det_err%%"$_pm_nl"*})"
  fi
  if [ -n "$_pm_why" ]; then
    echo "  The gate checkout '${GATE_WORKTREE}' ${_pm_why}, so it is NOT moved;"
    echo "  reading ${DEFAULT_BRANCH} at ${KWT_LANDED_SHA} in a FRESH worktree instead."
    _pm_tmp="${TMPDIR:-/tmp}"; _pm_tmp="${_pm_tmp%/}"
    if PM_FRESH_DIR="$(mktemp -d "${_pm_tmp}/finish-pr-postmerge.XXXXXX" 2>/dev/null)" \
       && git -C "$MAIN_ROOT" worktree add --detach --quiet "$PM_FRESH_DIR/tree" "$_pm_landed" >/dev/null 2>&1; then
      PM_TREE="$PM_FRESH_DIR/tree"
      PM_HOW="a FRESH worktree at the landed commit — it has none of your checkout's installed dependencies"
    else
      PM_UNRUNNABLE="the gate checkout could not be moved and no fresh worktree could be made at ${KWT_LANDED_SHA}"
    fi
  fi
fi
PM_READ=""
[ -n "$PM_TREE" ] && PM_READ="$(git -C "$PM_TREE" rev-parse --short HEAD 2>/dev/null || true)"
if [ -z "$PM_UNRUNNABLE" ] && [ -n "$PM_TREE" ] && ! { [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; } \
   && [ ! -x "$PM_TREE/scripts/verify.sh" ]; then
  PM_UNRUNNABLE="${DEFAULT_BRANCH}'s scripts/verify.sh at ${PM_READ:-?} is missing or not executable"
fi
if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the test-only stub
  POSTMERGE_CMD=(${FINISH_PR_VERIFY_CMD})
else
  POSTMERGE_CMD=("$PM_TREE/scripts/verify.sh" --quick)
fi
_pm_rc=""
if [ -z "$PM_UNRUNNABLE" ]; then
  # CAPTURED, THEN PRINTED, so the gate's own summary can be read below. In a condition,
  # so a red cannot trip `set -e`.
  if _pm_out="$( ( cd "$PM_TREE" && "${POSTMERGE_CMD[@]}" ) 2>&1 )"; then _pm_rc=0; else _pm_rc=$?; fi
  printf '%s\n' "$_pm_out"
  # The exit status decides first: the kit's verify.sh exits 3 when a gate could not run. For a
  # status of 1 (another runner), the LAST `gates declared: … · failed: <n> · could not run: <m>`
  # line is read; with none, 1 is FAIL. Limit: such a runner echoing a sub-runner's
  # `failed: 0 · could not run: <m>` before its own red reads as UNRUNNABLE — never as PASS.
  _pm_sum="$(printf '%s\n' "$_pm_out" | grep '^gates declared:' | tail -n 1 || true)"
  _pm_failed="$(printf '%s' "$_pm_sum" | sed -n 's/.*failed: \([0-9][0-9]*\).*/\1/p')"
  _pm_cnr="$(printf '%s' "$_pm_sum" | sed -n 's/.*could not run: \([0-9][0-9]*\).*/\1/p')"
  if [ "$_pm_rc" -eq 3 ]; then
    PM_UNRUNNABLE="the gate ran at ${PM_READ:-?} in ${PM_TREE} and exited 3: nothing failed, and ${_pm_cnr:-at least one} gate(s) could not run"
  elif [ "$_pm_rc" -eq 1 ] && [ "${_pm_failed:-x}" = "0" ] && [ "${_pm_cnr:-0}" -gt 0 ] 2>/dev/null; then
    PM_UNRUNNABLE="the gate ran at ${PM_READ:-?} in ${PM_TREE} and its summary counts ${_pm_cnr} gate(s) that could not run and none that failed"
  fi
fi
if [ -n "$PM_UNRUNNABLE" ]; then
  # NEITHER WORD OF THE PAIR. A FAIL asserts the trunk is red, and nothing measured it;
  # a PASS is the lie this block was rewritten to stop telling.
  echo "  post-merge verify --quick: COULD NOT RUN — ${PM_UNRUNNABLE}." >&2
  echo "  NOTHING about ${DEFAULT_BRANCH} was measured. This is not a PASS and not a FAIL: run the gate on" >&2
  echo "  ${DEFAULT_BRANCH}${KWT_LANDED_SHA:+ at ${KWT_LANDED_SHA}} in a prepared checkout before calling the landing checked." >&2
  echo "POST_MERGE_GATE: UNRUNNABLE"
elif [ "$_pm_rc" -eq 0 ]; then
  # The clearing line names the ref and the sha read, as the FAIL line does
  # (contracts/landing-gate.md § 4). POST_MERGE_GATE: lines are a machine contract: one fixed
  # prefix, one bare word, nothing appended.
  echo "  post-merge verify --quick: PASS on ${DEFAULT_BRANCH} at ${PM_READ:-?} (post-merge, in ${PM_TREE} — ${PM_HOW})"
  # The machine-greppable line, always on stdout; this outcome never moves the exit code.
  echo "POST_MERGE_GATE: PASS"
else
  echo "  post-merge verify --quick: FAIL on ${DEFAULT_BRANCH} at ${PM_READ:-?} (in ${PM_TREE} — ${PM_HOW}) — ${DEFAULT_BRANCH} may be red; fix it ON ${DEFAULT_BRANCH}, do not park it." >&2
  if [ -n "$PM_FRESH_DIR" ] && [ -z "$_pm_sum" ]; then
    echo "  That reading was taken in a FRESH worktree without your installed dependencies, and the gate's" >&2
    echo "  output carried no summary that could separate a failure from a gate that could not run: re-run" >&2
    echo "  it on ${DEFAULT_BRANCH} at ${PM_READ:-?} in a prepared checkout before acting on it." >&2
  elif [ -n "$PM_FRESH_DIR" ]; then
    echo "  That reading was taken in a FRESH worktree without your installed dependencies. The gate counted" >&2
    echo "  ${_pm_failed:-?} failure(s), not gates that could not run — but a check that needs a dependency can FAIL" >&2
    echo "  rather than refuse, so confirm on ${DEFAULT_BRANCH} at ${PM_READ:-?} in a prepared checkout." >&2
  fi
  echo "POST_MERGE_GATE: FAIL"
fi
# The fresh tree is removed, and a failure to remove it is SAID. Every command is guarded: this
# runs after the landing, where `set -e` must not abort.
if [ -n "$PM_FRESH_DIR" ]; then
  chmod -R u+w "$PM_FRESH_DIR" 2>/dev/null || true
  if [ -n "$PM_TREE" ]; then git -C "$MAIN_ROOT" worktree remove --force "$PM_TREE" >/dev/null 2>&1 || true; fi
  rm -rf "$PM_FRESH_DIR" 2>/dev/null || true
  git -C "$MAIN_ROOT" worktree prune >/dev/null 2>&1 || true
  if [ -e "$PM_FRESH_DIR" ]; then
    {
      echo "WARNING: the fresh post-merge worktree could NOT be removed and is still on disk:"
      echo "           ${PM_FRESH_DIR}"
      echo "         It is a throwaway reading of ${DEFAULT_BRANCH}, not a working checkout. Remove it with:"
      echo "           chmod -R u+w '${PM_FRESH_DIR}' && rm -rf '${PM_FRESH_DIR}' && git -C '${MAIN_ROOT}' worktree prune"
    } >&2
  fi
fi

# ── THE EXIT. Last statement in the file; every post-landing step above is guarded, so this is
#    what an automation reads.
if [ "${LANDED_INCOMPLETE:-0}" -ne 0 ]; then
  echo "EXIT: 3 (landed, not finished — do NOT re-run this script; run the recovery above)" >&2
  exit 3
fi
exit 0
