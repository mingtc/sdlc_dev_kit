#!/usr/bin/env bash
# KIT-CLASS: KIT — forge-agnostic squash-merge landing; pure git. See process/EXTRACTION.md.
# QA's PASS ritual in one command — FORGE-AGNOSTIC, pure git (no forge CLI, no forge API).
#
# Squash-merges the issue's feature branch into the TRUNK locally, pushes the trunk, deletes the
# branch (local unless a worktree holds it, and remote), and advances the issue file from progress/dev_complete/ →
# progress/qa_complete/. QA's verdict and per-AC evidence live in the issue file's `## QA Verdict` table, not in a
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
#   2  Usage error: an unknown option, a missing option value, or a required option left out.
#      Nothing was read or touched.
#   3  LANDED BUT NOT FINISHED. The squash IS on the trunk; a follow-up step did
#      not complete. **Do NOT re-run this script** — run the recovery it printed.
#
#   FINISH_PR_ROLE   the seat this landing commits as (default: QA). The tag is
#                    CHECKED against your declared role set before anything moves.
#
# A RED POST-MERGE GATE IS NOT A NON-ZERO EXIT: it is a fact about the trunk, not about this
# landing. It is printed as `POST_MERGE_GATE: PASS|FAIL|UNRUNNABLE|STUB` for an automation to key on
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
#      uncommitted tracked changes (not moved; a fresh worktree is read instead, prepared by POST_MERGE_PREP when config.sh declares one).
#
# Equivalent to running by hand:
#   git -C .kanban-wt merge --squash feature/<ID>-<slug>
#   git -C .kanban-wt commit -m "[QA] <ID>: <title> (squash-merge …)"
#   git -C .kanban-wt push <remote> HEAD:<trunk>
#   git branch -D feature/<ID>-<slug>   &&   git push <remote> --delete feature/<ID>-<slug>
#   ./scripts/move-issue.sh <ID> qa_complete --role QA --note "Review — PASS. Squash-merged."
#
#   The `--role` value above IS AN EXAMPLE VALUE: the roles move-issue.sh accepts are the ones its
#   own `--help` lists (process/EXTRACTION.md § 2.4 locates the set). Substitute one of yours.
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
# --note "...": the Activity entry's body; omitted, it is composed from what the run did. A note you
#   pass keeps its words and gets ` (verdict read at <sha>)` appended, the revision the QA Verdict
#   was read at, unless it already says "verdict read at".
# --worktree <path>: run the BLOCKING pre-merge gate against a genuine git worktree of THIS
#   repo (QA's own checkout of the branch) instead of the main checkout — needed when the main
#   checkout belongs to a parallel leg. The gate ALWAYS runs the trunk's committed
#   scripts/verify.sh --quick, in a fresh detached worktree at the branch tip (prepared by
#   POST_MERGE_PREP when config.sh declares one), so nothing uncommitted or untracked in the gate
#   checkout can green it: the caller names a LOCATION, never a command.
#   After the landing that worktree is left DETACHED AT THE
#   LANDED COMMIT, where the post-merge check reads the trunk; if it has uncommitted tracked
#   changes it is not moved, and a fresh worktree is read instead (prepared by POST_MERGE_PREP when config.sh declares one).
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync — propagated to the move sub-step.
# --dry-run: print the plan (what would be squashed, pushed, deleted and moved) and exit 0
#   before the blocking pre-merge gate runs, so a clean dry run does not predict that the gate,
#   or the landing, will pass.
#
# The gate checkout (the main one, or --worktree's) must be at the branch's tip; a decomposed
# issue's subtasks (progress/subtasks/<ID>/) must all be in qa_complete/ or declined/; and this
# script, the mover it runs and every library either sources must be byte-identical to <trunk>'s
# committed copy (the list is `_held_files` in this script), with no override (a branch that changes one, or
# was forked before <trunk>'s copy last changed, lands from the main checkout on <trunk>, with
# --worktree). Otherwise this refuses before anything moves.
#
# Examples:
#   ./scripts/finish-pr.sh <PREFIX>-001
#   ./scripts/finish-pr.sh <PREFIX>-001 --branch feature/<PREFIX>-001-my-slug
#   ./scripts/finish-pr.sh <PREFIX>-001 --worktree /tmp/wt-qa-001   # gate the QA's checkout
#   ./scripts/finish-pr.sh <PREFIX>-001 --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# THE LANDING TOOL IS THE TRUNK'S COMMITTED COPY. A branch, or a local edit, may not change the
# script that lands it, nor a library or script it runs: one that could would judge its own landing.
# No override: a change to the tool lands when the trunk's copy lands it, and anything else is the
# human's call. The comparison is plain shell and runs BEFORE any file below is sourced, so it
# leans on none of them; the trunk is resolved as lib/kanban-worktree.sh's kwt_resolve does.
# THE LIST IS DERIVED, never counted: every file this script, or the mover it runs, sources, directly
# or through a library, plus the scripts it runs or reads a declaration from. The self-test fails
# when a sourced file is missing from it.
_held_files="
check-board.sh
finish-pr.sh
lib/addon-check.sh
lib/agent-record.sh
lib/attrib-trailer.sh
lib/board-properties.sh
lib/branch-rev.sh
lib/card-field.sh
lib/decision-register.sh
lib/exit-trap.sh
lib/glob-array.sh
lib/hold-output.sh
lib/kanban-worktree.sh
lib/progress-record.sh
lib/push-retry.sh
lib/qa-gate.sh
lib/refuse.sh
lib/role-set.sh
lib/status-folders.sh
lib/usage.sh
move-issue.sh
"
_held_help=false
for _a in "$@"; do case "$_a" in -h|--help) _held_help=true ;; esac; done   # a usage request always succeeds
_held_rem="${KWT_REMOTE:-origin}"
_held_trunk="$(git symbolic-ref --short "refs/remotes/$_held_rem/HEAD" 2>/dev/null || true)"
_held_trunk="${_held_trunk#"$_held_rem"/}"
[ -n "$_held_trunk" ] || _held_trunk="$(git config --get init.defaultBranch 2>/dev/null || true)"
[ -n "$_held_trunk" ] || _held_trunk="${KWT_TRUNK_LAST_RESORT:-main}"
# git runs from the working directory, the repository this tool goes on to change, not the one this
# copy of scripts/ sits in. Its own fetch: the comparison cannot wait for kwt_sync. A failed fetch
# (offline) compares against the last one's ref.
[ "$_held_help" = true ] || git fetch "$_held_rem" "$_held_trunk" --quiet >/dev/null 2>&1 || true
_held_off=""; _held_noref=false
# With no trunk ref to read there is nothing to compare with, and that is not a pass: it is decided
# here, before anything is sourced, so nothing sourced can change it. It is a refusal whenever the
# repository holds a commit; with no commit at all, an empty repository, the bootstrap refuses it by name.
if [ "$_held_help" = true ]; then
  :
elif git rev-parse --verify --quiet "$_held_rem/$_held_trunk^{commit}" >/dev/null 2>&1; then
  for _f in $_held_files; do
    if git cat-file -e "$_held_rem/$_held_trunk:scripts/$_f" 2>/dev/null; then
      [ -e "$SCRIPT_DIR/$_f" ] && git show "$_held_rem/$_held_trunk:scripts/$_f" 2>/dev/null | cmp -s - "$SCRIPT_DIR/$_f" 2>/dev/null \
        || _held_off="$_held_off scripts/$_f"
    elif [ -e "$SCRIPT_DIR/$_f" ]; then   # here, and not on the trunk
      _held_off="$_held_off scripts/$_f"
    fi
  done
elif ! _held_rl="$(git rev-list -n 1 --all 2>/dev/null)" || [ -n "$_held_rl" ]; then   # a failing rev-list is not an empty one
  _held_noref=true
fi
if [ -n "$_held_off" ] || [ "$_held_noref" = true ]; then
  if [ "$_held_noref" = true ]; then
    _held_err="Error: cannot tell whether the landing tool here is ${_held_trunk}'s committed copy: no ${_held_rem}/${_held_trunk} ref could be read
       (the fetch failed, or this directory is not a clone of the project). NOTHING WAS CHANGED. (lander-not-trunk-copy)"
    _held_next="Next: fetch the trunk (git fetch ${_held_rem} ${_held_trunk}); if ${_held_trunk} is not your trunk, set it with
       git remote set-head ${_held_rem} <your-trunk>; then re-run."
  else
    _held_err="Error: the landing tool here is not ${_held_trunk}'s committed copy — these differ from
       ${_held_rem}/${_held_trunk} (changed on this branch or locally, or older than the trunk's):
      ${_held_off}
       A branch or a local edit may not change the tool that lands it. NOTHING WAS CHANGED. (lander-not-trunk-copy)"
    _held_local="$( { git -C "$SCRIPT_DIR/.." diff --name-only --no-renames --diff-filter=MTD HEAD -- $_held_off 2>/dev/null || true; } | tr '\n' ' ')"
    _held_edit=""
    if [ -n "$_held_local" ]; then
      _held_edit="
       Uncommitted edits here (${_held_local%% }): to drop them, git checkout HEAD -- ${_held_local%% }
       to keep them, commit and land them through the trunk's copy, then re-run."
    fi
    _held_untr="$( { git -C "$SCRIPT_DIR/.." ls-files --others --exclude-standard -- $_held_off 2>/dev/null || true; } | tr '\n' ' ')"
    if [ -n "$_held_untr" ]; then
      _held_edit="${_held_edit}
       Untracked here (${_held_untr%% }): not part of the trunk's copy; delete it, or commit and land it through the trunk's copy, then re-run."
    fi
    _held_next="Next: run the trunk's copy, from the main checkout on ${_held_trunk}, freshly pulled; gate the
       branch's checkout with --worktree (a branch cut before the trunk's last change to one of these needs
       no rebase for that; it is rebased only to run this tool from its own checkout):
         git switch ${_held_trunk} && git pull --ff-only && ./scripts/finish-pr.sh <ID> --worktree <branch checkout>${_held_edit}
       If the trunk's copy cannot land this change, ask the human: there is no override."
  fi
  # NOTHING IS SOURCED HERE, not even the refusal helper: a library that has just failed the comparison
  # could redefine `exit`. So the refusal is printed in plain shell, and its progress record is not written.
  printf '%s\n%s\n' "$_held_err" "$_held_next" >&2
  exit 1   # exit-class: internal
fi
unset _held_files _held_help _held_rem _held_trunk _held_off _held_noref _held_rl _a _f

# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"
# A reader that closes our output (`| head -1`) must not stop us between the commit and the push.
kwt_hold_output

# shellcheck source=lib/role-set.sh
. "$SCRIPT_DIR/lib/role-set.sh"

# --help renders the header block; lib/usage.sh derives where the window ends.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

# shellcheck source=lib/refuse.sh
. "$SCRIPT_DIR/lib/refuse.sh"
# The `forks:` precondition's register resolution — the SAME parser check-board.sh arm [l] uses:
# one implementation of "what does the register say", not two that can drift apart.
# shellcheck source=lib/decision-register.sh
. "$SCRIPT_DIR/lib/decision-register.sh"
# The QA Verdict / forks: / Ablation card checks — ONE parser, also called by subtask.sh for a
# slice's own card. See lib/qa-gate.sh's header for each function's contract.
# shellcheck source=lib/qa-gate.sh
. "$SCRIPT_DIR/lib/qa-gate.sh"
# Which agent made each commit — the records the Bash hooks write; read by the same-agent check.
# shellcheck source=lib/agent-record.sh
. "$SCRIPT_DIR/lib/agent-record.sh"
# shellcheck source=lib/card-field.sh
. "$SCRIPT_DIR/lib/card-field.sh"
# shellcheck source=lib/branch-rev.sh
. "$SCRIPT_DIR/lib/branch-rev.sh"

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
kit_require_issue_id "$ISSUE_ID" "<issue-id>"
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
             exit 2 ;;   # exit-class: usage
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# THE SEAT THIS SCRIPT ACTS AS, read once: the squash subject, the --role passed to the mover and
# the recovery text must agree.
ROLE="${FINISH_PR_ROLE:-QA}"
# CHECKED BEFORE kwt_resolve: move-issue.sh would reject a withdrawn role only at the advance,
# after the merge had landed.
kit_require_role "$SCRIPT_DIR/.." "$ROLE" FINISH_PR_ROLE

# Resolve repo root + trunk (works from any worktree, incl. a feature branch).
kwt_resolve

# ── THE GATE EXECUTABLE IS NEVER CALLER-CHOSEN. The pre-merge gate runs a TRACKED
#    scripts/verify.sh that finish-pr.sh chooses. FINISH_PR_PREMERGE_CMD / FINISH_PR_VERIFY_CMD
#    are the self-test's seams, honoured only behind FINISH_PR_TEST_ALLOW_STUB=1; on the
#    production path they are refused before any destructive step. Use --worktree <path>.
ALLOW_STUB=false
[ "${FINISH_PR_TEST_ALLOW_STUB:-}" = "1" ] && ALLOW_STUB=true
# A landing through a stubbed gate is marked wherever it is recorded: the gate lines say STUB, the
# squash subject and the Activity note carry the clause, so nothing reads it as a measured green.
_stub_subject=""; _stub_clause=""
if [ "$ALLOW_STUB" = "true" ] && { [ -n "${FINISH_PR_PREMERGE_CMD:-}" ] || [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; }; then
  _stub_subject=" [STUB gate]"
  _stub_clause=" [STUB gate: a test-only command ran in its place; nothing was measured]"
fi
if [ "$ALLOW_STUB" != "true" ] && { [ -n "${FINISH_PR_PREMERGE_CMD:-}" ] || [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; }; then
  kit_refuse 1 gate-command-caller-supplied \
    "Error: refusing a caller-supplied gate command on the production landing path." \
    "       The gate command is not a setting: it is not read from the environment on this path." \
    "       The pre-merge gate runs a TRACKED scripts/verify.sh that finish-pr.sh chooses." \
    "Next: unset FINISH_PR_PREMERGE_CMD and FINISH_PR_VERIFY_CMD and re-run; to gate against a parallel leg's checkout, pass --worktree <path>."
fi

# The checkout that must hold the branch tip's TRACKED scripts/verify.sh for the pre-merge gate: the repo root, or
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
    kit_refuse 1 worktree-not-a-gate-checkout \
      "Error: $_err — refusing before any destructive step." \
      "       --worktree must name a genuine worktree of this repo whose tracked" \
      "       scripts/verify.sh is what runs (the executable is never caller-chosen)." \
      "Next: pass --worktree <path> naming a worktree of THIS repo (git worktree list) whose scripts/verify.sh is committed and unmodified, or omit --worktree to gate the main checkout."
  fi
  # ABSOLUTE: the post-merge reading runs the gate from inside this checkout, where a relative
  # spelling names a path that does not exist.
  GATE_WORKTREE="$(cd "$WORKTREE" && pwd)"
fi

# A trunk holding commits its remote lacks is refused BEFORE the lock, the bootstrap and the sync: a landing goes on
# the remote's tip beside them (lib/push-retry.sh's git_refuse_unpublished_trunk, the one check all five landers share).
git_refuse_unpublished_trunk "$MAIN_ROOT" "$KWT_REMOTE" "$DEFAULT_BRANCH"

# Take the lock + bootstrap + sync the worktree to <remote>/<trunk> BEFORE reading
# the issue file, so the branch read sees the current trunk state.
kwt_lock
kwt_bootstrap
kwt_sync
# THE SQUASH COMMIT IS JUDGED BY THE HOOK IN $KWT, a copy of the trunk; the check above read this checkout's.
kit_require_role_on_trunk "$KWT" "$ROLE" "${KWT_SYNCED:-false}" "$KWT_REMOTE/$DEFAULT_BRANCH" "the role tag '$ROLE'"

# Find the issue file in dev_complete/ inside the kanban worktree.
SRC=""; _fpr_matches=()
while IFS= read -r f; do
  _fpr_matches+=("$f")
done < <(find "$KWT/progress/dev_complete" -maxdepth 1 -name "${ISSUE_ID}-*.md" -type f 2>/dev/null | sort)
# One id names one card: two files for it is a board fault to clear, not a choice for this script to make.
if [ ${#_fpr_matches[@]} -gt 1 ]; then
  kit_refuse 1 card-id-ambiguous \
    "Error: multiple files match ${ISSUE_ID}-*.md in progress/dev_complete/:" \
    "$(printf '  %s\n' "${_fpr_matches[@]#"$KWT"/}")" \
    "Next: one id must name one card — keep the real card and renumber or remove the other on the trunk (./scripts/check-board.sh names duplicate ids), then re-run."
fi
[ ${#_fpr_matches[@]} -eq 0 ] || SRC="${_fpr_matches[0]}"

if [ -z "$SRC" ]; then
  # Name the column the card IS in (process/contracts/landing-gate.md § 3): each has its own next step.
  _fpr_at="$(find "$KWT/progress" -maxdepth 2 -name "${ISSUE_ID}-*.md" 2>/dev/null | head -1)"
  if [ -n "$_fpr_at" ]; then
    _fpr_col="$(basename "$(dirname "$_fpr_at")")"
    kit_refuse 1 card-not-in-dev-complete \
      "Error: ${ISSUE_ID} is in progress/${_fpr_col}/, not progress/dev_complete/." \
      "       finish-pr lands from dev_complete only. Move it there first if QA has handed it back," \
      "       or land nothing if it is already in qa_complete/." \
      "       finish-pr.sh only lands issues sitting in dev_complete/." \
      "Next: if ${ISSUE_ID} is ready for review, move it there (./scripts/move-issue.sh ${ISSUE_ID} dev_complete --role <role> --note \"<what is ready>\") and re-run; if it is already in qa_complete/ or done/, there is nothing to land."
  fi
  kit_refuse 1 card-not-found \
    "Error: ${ISSUE_ID} is in no progress/ folder at all — not dev_complete/, and not anywhere else." \
    "       finish-pr.sh only lands issues sitting in dev_complete/." \
    "Next: check the id (ls progress/*/ | grep ${ISSUE_ID}); a card minted but not yet pushed is invisible here until it reaches the trunk."
fi

# A DECOMPOSED PARENT LANDS ONLY WHEN EVERY SUBTASK IS REVIEWED OR DECLINED: the advance below would refuse
# after the merge had landed (the mover's rule), so it is refused here, before anything moves.
_open="$(kwt_open_subtasks "$ISSUE_ID")"
if [ -n "$_open" ]; then
  kit_refuse 1 subtasks-open \
    "Error: ${ISSUE_ID} has subtask(s) neither in qa_complete/ nor declined:" \
    "$(printf '%s\n' "$_open" | sed 's/^/    /')" \
    "       A parent advances to qa_complete/ only when every subtask has (or is declined), so it does not land" \
    "       before then." \
    "Next: finish each subtask, or close one that will not be done with" \
    "         ./scripts/subtask.sh move <id> declined --note \"why\"" \
    "       NOTHING WAS CHANGED."
fi

# Resolve the branch to merge (frontmatter unless --branch given).
if [ -z "$BRANCH" ]; then
  BRANCH="$(kit_card_field "$SRC" branch)"
  if [ -z "$BRANCH" ]; then
    kit_refuse 1 branch-unnamed \
      "Error: no 'branch:' frontmatter in ${SRC#"$KWT"/}; pass --branch <name>." \
      "Next: re-run naming the branch: ./scripts/finish-pr.sh ${ISSUE_ID} --branch <name>."
  fi
fi

# A title for the squash commit subject.
TITLE="$(kit_card_field "$SRC" title --raw)"   # a title is free text: a '#' in it is not a comment
[ -z "$TITLE" ] && TITLE="$ISSUE_ID"
# The default Activity note is composed AFTER the delete arms, from what they did (the NOTE_GIVEN
# block below them). An operator-supplied --note keeps its words; the revision clause is appended.

# The Next: of a refusal for a branch this repository does not hold: the fetch is offered only
# when the remote has the branch (ls-remote exits 2 when it has not, anything else when it could not be asked).
# It sets BM_NEXT, each value a literal `Next:` assignment, so the refusal census reads it.
_branch_missing_next() {
  local _bm_rc=0
  GIT_TERMINAL_PROMPT=0 git -C "$MAIN_ROOT" ls-remote --exit-code --heads "$KWT_REMOTE" "$BRANCH" >/dev/null 2>&1 || _bm_rc=$?
  BM_NEXT="Next: pass --branch <name> naming the local branch, or, if ${KWT_REMOTE} has it (it could not be asked), create it with  git fetch ${KWT_REMOTE} ${BRANCH}:${BRANCH}  and re-run."
  if [ "$_bm_rc" -eq 0 ]; then
    BM_NEXT="Next: pass --branch <name> naming the local branch, or create it from the remote with  git fetch ${KWT_REMOTE} ${BRANCH}:${BRANCH}  and re-run."
  elif [ "$_bm_rc" -eq 2 ]; then
    BM_NEXT="Next: ${KWT_REMOTE} has no '${BRANCH}' either, so this card has no code to land. If Dev never pushed it, send the card back:  ./scripts/move-issue.sh ${ISSUE_ID} in_progress --role $ROLE --note \"no branch: <what happened>\"  or pass --branch <name> for the branch that holds the work."
  fi
}

# The branch must exist locally (its commits are what we squash).
if ! BRANCH_REF="$(kit_card_branch_rev "$MAIN_ROOT" "$BRANCH" -)"; then
  _branch_missing_next
  kit_refuse 1 branch-not-found \
    "Error: local branch '$BRANCH' not found. Pass --branch or check it out first." \
    "$BM_NEXT"
fi

# THE REVISION EVERYTHING BELOW READS, resolved once and through refs/heads/…, never the short name
# (a tag of the same name would win that lookup). Every check reads this sha; the squash merges it,
# after the branch is shown not to have moved.
QA_READ_FULL="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "${BRANCH_REF}^{commit}" 2>/dev/null || true)"
if [ -z "$QA_READ_FULL" ]; then
  _branch_missing_next
  kit_refuse 1 branch-not-found \
    "Error: local branch '$BRANCH' does not resolve to a commit." \
    "$BM_NEXT"
fi

# ── A STACKED BRANCH LOSES ITS BASE WHEN THE BASE SQUASH-LANDS. `$BRANCH` was branched from
#    another feature branch, not from the trunk directly. Two shapes, detected from git alone,
#    before anything destructive:
#      (a) the old base is STILL UNLANDED — some other local/remote branch's tip is one of
#          `$BRANCH`'s own commits ahead of the trunk (`$KWT_REMOTE/$DEFAULT_BRANCH..$BRANCH`)
#          and that tip has no patch-id match on the trunk (the landing leaves the base's local
#          branch behind when a worktree holds it, so a surviving ref alone proves nothing);
#      (b) the old base has SQUASH-LANDED — a prefix of those same commits, diffed from the
#          merge-base, has the same patch-id as a commit the trunk gained that `$BRANCH` never
#          saw (`$BRANCH..$KWT_REMOTE/$DEFAULT_BRANCH`).
#    Either way this refuses with the exact `git rebase --onto` step, before the branch-existence
#    gate above runs anything expensive. PRECISION: (a) names a real ref, not a guess; landedness, in
#    both shapes, is the one patch-id match below, "reasonably unique" per git-patch-id(1) — a
#    coincidental match on an unrelated commit is possible but not observed. NEITHER CATCHES stacking
#    done by cherry-pick rather than by branching: a cherry-picked commit is a NEW commit,
#    reachable from no ref and with no patch-id relationship this check derives.
_stk_trunk="$KWT_REMOTE/$DEFAULT_BRANCH"
_stk_ahead="$(git -C "$MAIN_ROOT" log --reverse --format=%H "${_stk_trunk}..${QA_READ_FULL}" 2>/dev/null || true)"
_stk_branch_tip="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "$QA_READ_FULL" 2>/dev/null || true)"
_stk_mb="$(git -C "$MAIN_ROOT" merge-base "$QA_READ_FULL" "$_stk_trunk" 2>/dev/null || true)"
_stk_trunk_only="$(git -C "$MAIN_ROOT" log --format=%H "${QA_READ_FULL}..${_stk_trunk}" 2>/dev/null || true)"
# _stk_refuse_if_squashed <candidate commits, one per line> [<base ref left behind>]
#   Refuses `stacked-branch-squashed-base` when a candidate prefix of $BRANCH's own commits, diffed
#   from the merge-base, has the same patch-id as a commit the trunk gained that $BRANCH never saw.
_stk_refuse_if_squashed() {
  local cands="$1" left="${2:-}" cand cand_pid t t_pid note=""
  [ -n "$_stk_mb" ] && [ -n "$_stk_trunk_only" ] || return 0
  [ -z "$left" ] || note="       The base's branch '${left}' was left behind (for example held by a worktree)."
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    cand_pid="$(git -C "$MAIN_ROOT" diff "$_stk_mb" "$cand" 2>/dev/null | git patch-id --stable 2>/dev/null | awk '{print $1}')"
    [ -n "$cand_pid" ] || continue
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      t_pid="$(git -C "$MAIN_ROOT" show "$t" 2>/dev/null | git patch-id --stable 2>/dev/null | awk '{print $1}')"
      if [ -n "$t_pid" ] && [ "$cand_pid" = "$t_pid" ]; then
        # The tip itself is the squash: the branch has landed, and a landing cut short after its push leaves exactly this.
        if [ "$cand" = "$QA_READ_FULL" ]; then
          kit_refuse 1 branch-already-landed \
            "Error: '${BRANCH}' has already landed on ${DEFAULT_BRANCH} (as ${t:0:9}): its whole diff is that commit." \
            "       A landing cut short after its push leaves this state: the commit is on ${DEFAULT_BRANCH} and the card is still in dev_complete/." \
            "Next: record the landing, then delete '${BRANCH}' if it is still there:" \
            "         ${SCRIPT_DIR}/move-issue.sh ${ISSUE_ID} qa_complete --role ${ROLE} --landed-at ${t} --note '<what the review found>'" \
            "       NOTHING WAS CHANGED."
        fi
        kit_refuse 1 stacked-branch-squashed-base \
          "Error: '${BRANCH}' is stacked on a base that has already squash-landed on ${DEFAULT_BRANCH} (as ${t:0:9})." \
          "       ${BRANCH} still carries that base's own, un-squashed commits up to ${cand:0:9};" \
          "       landing '${BRANCH}' as-is would re-apply them and conflict." \
          ${note:+"$note"} \
          "Next: hand the branch to its Dev to rebase past the squash, then re-run:" \
          "         git rebase --onto ${DEFAULT_BRANCH} ${cand} ${BRANCH}" \
          "       NOTHING WAS CHANGED."
      fi
    done <<< "$_stk_trunk_only"
  done <<< "$cands"
}
if [ -n "$_stk_ahead" ]; then
  # (a) A BASE REF IS STILL HERE: another branch's tip sits inside $BRANCH's own history, ahead of
  #     the trunk, and STRICTLY BEHIND $BRANCH's own tip — a ref that merely NAMES the same tip
  #     (e.g. a second local name for the branch being landed) is not a base, it is a synonym.
  #     The ref says the base once existed, not that it has not landed: ask the patch-id first.
  _stk_old_base=""; _stk_old_base_tip=""
  while IFS= read -r _stk_ref; do
    [ -n "$_stk_ref" ] || continue
    case "$_stk_ref" in
      "refs/heads/$BRANCH"|"refs/remotes/$KWT_REMOTE/$BRANCH"|"$_stk_trunk"|"refs/remotes/$KWT_REMOTE/HEAD") continue ;;
    esac
    _stk_tip="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "$_stk_ref" 2>/dev/null || true)"
    [ -n "$_stk_tip" ] || continue
    [ "$_stk_tip" != "$_stk_branch_tip" ] || continue
    if grep -qxF -- "$_stk_tip" <<< "$_stk_ahead"; then
      _stk_old_base="${_stk_ref#refs/heads/}"; _stk_old_base="${_stk_old_base#refs/remotes/}"
      _stk_old_base_tip="$_stk_tip"
      break
    fi
  done <<< "$(git -C "$MAIN_ROOT" for-each-ref --format='%(refname)' refs/heads/ "refs/remotes/$KWT_REMOTE/")"  # card-read-exempt: lists every branch to find a stacked base; resolves none
  if [ -n "$_stk_old_base" ]; then
    _stk_refuse_if_squashed "$_stk_old_base_tip" "$_stk_old_base"
    kit_refuse 1 stacked-branch-unlanded-base \
      "Error: '${BRANCH}' is stacked on '${_stk_old_base}', which has not landed on ${DEFAULT_BRANCH}." \
      "       ${BRANCH} carries ${_stk_old_base}'s commits; landing it now would try to land ${_stk_old_base}'s" \
      "       work too, unreviewed under this issue." \
      "Next: land or drop '${_stk_old_base}', hand the branch to its Dev to rebase, then re-run:" \
      "         git rebase --onto ${DEFAULT_BRANCH} ${_stk_old_base} ${BRANCH}" \
      "       NOTHING WAS CHANGED."
  fi
  # (b) SQUASH-LANDED, no base ref left: every prefix of $BRANCH's commits is a candidate.
  _stk_refuse_if_squashed "$_stk_ahead"
fi

# ── THE forks: / QA VERDICT TABLE / ABLATION / BOARD-PROPERTY CHECKS — lib/qa-gate.sh, the ONE parser subtask.sh
#    also calls for a slice's own card before it moves to qa_complete/. Each refuses, before
#    anything destructive, through kit_refuse (process/contracts/progress-record.md § 5b); the
#    rule ids and message text are the lib's, documented in its header.
#    forks: process/MANUAL.md § Execution discipline item 6; `forks: none` on a branch that shows
#    no fork is the only shape that lands clean; register set derived from check-board.sh's own
#    REGISTERS= (arm [l]'s operand), never hard-coded.
kit_forks_check "$SRC" "$ISSUE_ID" "$MAIN_ROOT" "${KWT_REMOTE}/${DEFAULT_BRANCH}" "$QA_READ_FULL" "$SCRIPT_DIR/check-board.sh"

#    QA Verdict: .claude/roles/qa.md step 4 — a claim-by-claim walk that FOUND a mismatch and
#    filed PASS anyway is the motivating case, so this also refuses on a row's OWN verdict, not
#    just on evidence being present. The card's own AC ids are derived, never re-typed: every
#    '- [ ] <id> —'/'- [ ] <id> -'/'- [ ] <id>:' checklist bullet before the '## QA Verdict'
#    heading is one, across all templates (ISSUE/BUG/REFACTOR's 'AC1'/'B1', SUBTASK's 'AC<n>').
#    Every evidence pointer is read against $BRANCH — the revision being landed, same as
#    kit_forks_check's new_rev above — never the caller's own working tree.
#    The branch tip is resolved once: the gate reads that commit and the Activity note names it.
#    An `artifact` row is QA's own file, committed on the trunk, so it is read at the trunk, never at
#    the branch the work's author controls.
#    $QA_READ_FULL is that sha, resolved once above.
QA_READ_SHORT=""
[ -z "$QA_READ_FULL" ] || QA_READ_SHORT="$(git -C "$MAIN_ROOT" rev-parse --short "$QA_READ_FULL" 2>/dev/null || true)"
kit_qa_verdict_check "$SRC" "$ISSUE_ID" "$MAIN_ROOT" "${QA_READ_FULL:-$BRANCH}" "${KWT_REMOTE}/${DEFAULT_BRANCH}"

#    Ablation: process/doctrine/instruments.md § A.2; .claude/roles/dev.md Definition of Done.
#    TEST_GLOBS (scripts/config.sh) read as the UNION of the trunk's copy and the branch's.
#    Undeclared TEST_GLOBS makes the check UNRUNNABLE, reported on stdout, never a silent pass.
kit_ablation_check "$SRC" "$ISSUE_ID" "$MAIN_ROOT" "${KWT_REMOTE}/${DEFAULT_BRANCH}" "$QA_READ_FULL"

#    Board properties: check-board.sh's arms [d] [i] [l] [p] [r] [q] — the same functions, run on the
#    tree this landing would produce (the trunk with the branch squash-merged and the card moved to
#    qa_complete/). A finding the branch INTRODUCES refuses; one already on the trunk does not. An
#    arm whose property the branch does not touch does not run. The operands come from the trunk's
#    own check-board.sh and config.sh.
kit_board_property_check "$MAIN_ROOT" "${KWT_REMOTE}/${DEFAULT_BRANCH}" "$QA_READ_FULL" \
  "${SRC#"$KWT"/}" "progress/qa_complete/$(basename "$SRC")"

#    The checker is not the author (process/contracts/agent-record.md): the (session, agent)
#    recorded for the commit that wrote the card's ## QA Verdict on the trunk must not be one
#    recorded for the branch's code commits. Read before the squash, which replaces those commits. No record on
#    either side prints AGENT_CHECK: UNRUNNABLE and lands.
kit_agent_records_fetch "$MAIN_ROOT" "$KWT_REMOTE"
kit_agent_landing_check "$MAIN_ROOT" "${KWT_REMOTE}/${DEFAULT_BRANCH}" "$ISSUE_ID" "$QA_READ_FULL"

#    An add-on's move checks (scripts/move-check.d/qa_complete/, lib/addon-check.sh) for the move this
#    landing ends with, run NOW, before the squash: a refusal after it would leave the code merged and the
#    card in dev_complete/. move-issue.sh skips them for the --landed-at move below because they have
#    run here (process/contracts/board-mover.md § 3). They are the trunk's, as the checks above are.
kit_move_checks "$MAIN_ROOT" "refs/remotes/${KWT_REMOTE}/${DEFAULT_BRANCH}" "$ISSUE_ID" \
  "$(basename "$(dirname "$SRC")")" qa_complete "$ROLE" "$SRC"

# ── THE GATE CHECKOUT MUST HOLD THE COMMITTED verify.sh, AT THE REVISION BEING LANDED
#    (contracts/landing-gate.md § 2), on both paths, and the refusal names which check failed
#    (§ 3). The test is the REVISION, not the ref name: a detached checkout exactly at the branch
#    tip is accepted. This binds the PRE-merge tree only; the post-merge block reads the landed
#    commit. It runs after kwt_sync because `branch:` is read from the kanban worktree; nothing
#    the contract protects has been touched yet.
if [ "$ALLOW_STUB" != "true" ]; then
  _gate_v="$GATE_WORKTREE/scripts/verify.sh"
  _branch_tip="$(git -C "$MAIN_ROOT" rev-parse "$QA_READ_FULL" 2>/dev/null || true)"
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
    if [ -n "$_gate_absent" ]; then
      _gate_next="Next: there is no usable gate here at all. The gate runner is a HARD landing
  precondition, not a recommendation (process/contracts/verify-gate.md):
    • write it — scripts/verify.sh ships as a frame with an EMPTY gate table;
      declare your gates in it
    • or, ON A FRESH REPO, generate one:
        ./scripts/kit-init.sh --prefix <P> --trunk <B> --gate-command '<your test command>'
      (kit-init REFUSES a repository that has already lived; if yours has, write it.)"
    else
      _gate_next="Next: land ${ISSUE_ID} one of two conforming ways:
    • gate against a worktree that has it:
        ./scripts/finish-pr.sh ${ISSUE_ID} --worktree <path-to-a-worktree-on-${BRANCH}>
    • or check the branch out here, if every file in this script's _held_files list is still ${DEFAULT_BRANCH}'s
      (else rebase the branch on ${DEFAULT_BRANCH} first):
        git -C '$MAIN_ROOT' checkout '$BRANCH'
  Either way, the post-merge check then reads ${DEFAULT_BRANCH} at the landed commit: the gate
  checkout is switched to ${DEFAULT_BRANCH} or DETACHED there, and one with uncommitted
  changes is left alone while a fresh worktree is read instead, prepared by POST_MERGE_PREP when
  config.sh declares one."
    fi
    kit_refuse 1 landing-gate-unusable \
      "Error: the landing gate is $_gate_err." \
      "       Refusing BEFORE any destructive step: no squash, no push, no branch" \
      "       deletion, no issue advance." \
      "       The gate checkout must hold scripts/verify.sh COMMITTED and unmodified at" \
      "       the revision being landed; where the branch changes it, the trunk's copy" \
      "       judges it (process/contracts/landing-gate.md § 2-3). Otherwise the run" \
      "       proves something about a tree that is not shipping." \
      "" \
      "$_gate_next"
  fi
fi

SQUASH_MSG="[$ROLE] ${ISSUE_ID}: ${TITLE}${_stub_subject} (squash-merge ${BRANCH})"

# The Activity note names the branch tip the QA Verdict was read at, so a later reader re-resolves the
# table's pointers at that revision. An operator-supplied --note keeps its words and gets the clause
# appended (unless it already says it), here, so the plan below shows the note as it will be written.
_rev_clause=""
[ -z "$QA_READ_SHORT" ] || _rev_clause=" (verdict read at ${QA_READ_SHORT})"
if [ "$NOTE_GIVEN" = "true" ]; then
  case "$NOTE" in
    *"verdict read at"*) : ;;
    *) NOTE="${NOTE}${_rev_clause}" ;;
  esac
  NOTE="${NOTE}${_stub_clause}"
fi

echo "Plan:"
echo "  1. Squash-merge '${BRANCH}' → '${DEFAULT_BRANCH}' (in .kanban-wt), commit: \"${SQUASH_MSG}\""
echo "  2. Push HEAD → ${KWT_REMOTE}/${DEFAULT_BRANCH}"
echo "  3. Delete branch '${BRANCH}' (remote if present; local unless a worktree holds it)"
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
# THE TREE IT READS IS THE REVISION THAT LANDS, NEVER THE GATE CHECKOUT'S WORKING FILES: a fresh
# detached worktree at the branch tip, so an uncommitted edit or an untracked file in the checkout
# cannot green a red branch. The trunk's POST_MERGE_PREP, read as text, prepares it (empty = nothing runs).
_pre_tree="$GATE_WORKTREE"; _pre_fresh=""
_pre_cleanup() {
  if [ -n "$_pre_fresh" ]; then
    chmod -R u+w "$_pre_fresh" 2>/dev/null || true
    git -C "$MAIN_ROOT" worktree remove --force "$_pre_fresh/tree" >/dev/null 2>&1 || true
    rm -rf "${_pre_fresh:?}" 2>/dev/null || true
    _pre_fresh=""
  fi
}
if ! { [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_PREMERGE_CMD:-}" ]; }; then
  _pre_tip="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "${QA_READ_FULL}^{commit}" 2>/dev/null || true)"
  _pre_tmp="${TMPDIR:-/tmp}"; _pre_tmp="${_pre_tmp%/}"
  if [ -z "$_pre_tip" ] || ! _pre_fresh="$(mktemp -d "${_pre_tmp}/finish-pr-premerge.XXXXXX" 2>/dev/null)" \
     || ! git -C "$MAIN_ROOT" worktree add --detach --quiet "$_pre_fresh/tree" "$_pre_tip" >/dev/null 2>&1; then
    _pre_cleanup
    kit_refuse 1 premerge-tree-unavailable \
      "Error: could not make a fresh worktree at ${QA_READ_FULL:0:9}, the revision of '${BRANCH}' being landed, to run the pre-merge gate in." \
      "       No squash, no push, no branch deletion, no issue advance." \
      "Next: free disk space or the temporary directory (TMPDIR=${_pre_tmp}), check  git -C '$MAIN_ROOT' worktree list  for a broken entry (git worktree prune), then re-run finish-pr.sh."
  fi
  _pre_tree="$_pre_fresh/tree"
  _pre_prep="$(kit_declared_value "$KWT/scripts/config.sh" POST_MERGE_PREP 2>/dev/null || true)"
  if [ -n "$_pre_prep" ]; then
    echo "Preparing the pre-merge worktree with POST_MERGE_PREP: ${_pre_prep}"
    _pre_prep_rc=0
    ( cd "$_pre_tree" && sh -c "$_pre_prep" </dev/null ) || _pre_prep_rc=$?
    if [ "$_pre_prep_rc" -ne 0 ]; then
      _pre_cleanup
      kit_refuse 1 premerge-prep-failed \
        "Error: POST_MERGE_PREP exited ${_pre_prep_rc} in the fresh pre-merge worktree — the gate did not run; refusing to merge '${BRANCH}'." \
        "       No squash, no push, no branch deletion, no issue advance." \
        "Next: fix the POST_MERGE_PREP command in scripts/config.sh on ${DEFAULT_BRANCH} (it prepares every fresh tree the gate runs in), then re-run finish-pr.sh."
    fi
  fi
fi
if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_PREMERGE_CMD:-}" ]; then
  # shellcheck disable=SC2086  # intentional word-split of the test-only stub
  PREMERGE_CMD=(${FINISH_PR_PREMERGE_CMD})
elif git -C "$KWT" cat-file -e HEAD:scripts/verify.sh 2>/dev/null \
     && ! git -C "$KWT" diff --quiet HEAD "$QA_READ_FULL" -- scripts/verify.sh 2>/dev/null; then
  if ! { _trunk_gate="$(mktemp "$_pre_tree/scripts/.verify-trunk.XXXXXX")" \
         && git -C "$KWT" show HEAD:scripts/verify.sh > "$_trunk_gate" && chmod +x "$_trunk_gate"; }; then
    [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
    _pre_cleanup
    echo "Error: could not stage ${DEFAULT_BRANCH}'s scripts/verify.sh in '${_pre_tree}/scripts/' — refusing to merge '${BRANCH}'." >&2
    exit 1   # exit-class: internal
  fi
  PREMERGE_CMD=("$_trunk_gate" --quick)
else
  PREMERGE_CMD=("$_pre_tree/scripts/verify.sh" --quick)
fi
# The banner names the runner that actually runs.
if [ -n "$_trunk_gate" ]; then
  echo "Pre-merge gate (blocking): ${DEFAULT_BRANCH}'s scripts/verify.sh --quick, run in ${_pre_tree}"
  echo "  '${BRANCH}' changes scripts/verify.sh, so ${DEFAULT_BRANCH}'s copy judges it; the branch's governs from the next landing."
else
  echo "Pre-merge gate (blocking): ${PREMERGE_CMD[*]}"
fi
if "${PREMERGE_CMD[@]}"; then
  [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
  _pre_cleanup
  if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_PREMERGE_CMD:-}" ]; then
    echo "  pre-merge verify --quick: STUB — a test-only command ran in the gate's place; nothing was measured"
  else
    echo "  pre-merge verify --quick: PASS"
  fi
else
  _pre_rc=$?
  # A runner that refused on an EMPTY gates table is the one refusal with a route out: the table
  # has to be on the trunk before the trunk's runner can judge anything, and a branch that
  # declares the gates cannot get them there through this landing. `verify.sh --list` says so in
  # these words. Asked before the trunk's staged copy is removed; a stubbed gate is not asked.
  _pre_empty=""
  if [ "$_pre_rc" -eq 2 ] && [ -z "${FINISH_PR_PREMERGE_CMD:-}" ]; then
    _pre_list="$("${PREMERGE_CMD[0]}" --list 2>/dev/null || true)"
    case "$_pre_list" in *"the table is empty"*) _pre_empty=1 ;; esac
  fi
  [ -z "$_trunk_gate" ] || rm -f "$_trunk_gate"
  _pre_cleanup
  # All three reds refuse, named apart: verify.sh exits 2 when it never ran at all (a
  # configuration problem — nothing was measured, nothing was even attempted) and 3 when a gate
  # could not run (nothing was measured either, but the runner did start). Only a plain FAIL
  # (exit 1, or anything else) means the branch itself measured red.
  if [ "$_pre_rc" -eq 2 ] && [ -n "$_pre_empty" ]; then
    kit_refuse 1 premerge-gate-refused-to-run \
      "Error: pre-merge gate REFUSED TO RUN (verify.sh exit 2: the GATES table is empty) — refusing to merge '${BRANCH}'." \
      "       No squash, no push, no branch deletion, no issue advance." \
      "       ${DEFAULT_BRANCH}'s GATES table is empty, and a runner with no gate authorises no landing, so ${DEFAULT_BRANCH}'s runner has nothing to judge this branch by." \
      "Next: land the gate table on ${DEFAULT_BRANCH} first: declare the gates in scripts/verify.sh in this checkout, run  ./scripts/register-commit.sh --role $ROLE --message \"declare the gates\" scripts/verify.sh  (it commits to ${DEFAULT_BRANCH} and leaves this branch as it is), then re-run finish-pr.sh; if that then says the branch is stacked on a base that already landed (the table was its only change), follow the rebase it names."
  elif [ "$_pre_rc" -eq 2 ]; then
    kit_refuse 1 premerge-gate-refused-to-run \
      "Error: pre-merge gate REFUSED TO RUN (verify.sh exit 2: an empty or malformed GATES table, an unknown argument, a narrowed run's precondition, or --quick over a table whose every gate is class full) — refusing to merge '${BRANCH}'." \
      "       No squash, no push, no branch deletion, no issue advance." \
      "       Nothing about the branch was measured: this is the gate's own configuration, not the branch." \
      "Next: fix scripts/verify.sh (its own refusal names what it needs), then re-run finish-pr.sh."
  elif [ "$_pre_rc" -eq 3 ]; then
    kit_refuse 1 premerge-gate-could-not-run \
      "Error: pre-merge gate COULD NOT RUN (verify.sh exit 3: a gate never executed, and none failed) — refusing to merge '${BRANCH}'." \
      "       No squash, no push, no branch deletion, no issue advance." \
      "       Nothing about the branch was measured." \
      "Next: fix what the gate needs to start (its summary names it), then re-run finish-pr.sh."
  else
    kit_refuse 1 premerge-gate-failed \
      "Error: pre-merge gate FAILED — refusing to merge '${BRANCH}'." \
      "       No squash, no push, no branch deletion, no issue advance." \
      "Next: fix the branch so the quick gate is green (QA sends it back to Dev:  ./scripts/move-issue.sh ${ISSUE_ID} in_progress --role $ROLE --note \"<what failed>\"), then re-run finish-pr.sh."
  fi
fi

# ── THE BRANCH MUST STILL BE THE REVISION THAT WAS READ. The QA Verdict, the gate checkout and the
#    gate all used the tip resolved above; the gate can run long, and a commit that reached the branch
#    meanwhile would be squashed unread under an Activity note that names the earlier revision.
#    Merging the read sha alone would land what was read and strand the late commit, so it refuses.
_moved_tip="$(git -C "$MAIN_ROOT" rev-parse --verify --quiet "${BRANCH_REF}^{commit}" 2>/dev/null || true)"
if [ -z "$QA_READ_FULL" ] || [ "$_moved_tip" != "$QA_READ_FULL" ]; then
  kit_refuse 1 branch-moved-during-gate \
    "Error: '${BRANCH}' moved while the pre-merge gate ran: it was read and gated at ${QA_READ_FULL:0:9} and is now at ${_moved_tip:0:9}." \
    "       Refusing BEFORE any destructive step: no squash, no push, no branch deletion, no issue advance." \
    "       The commits that arrived were not read by QA and not gated." \
    "Next: re-run ./scripts/finish-pr.sh ${ISSUE_ID} to read and gate the branch as it now is; if those commits should not be on '${BRANCH}', move the branch back first."
fi

# ── Squash-merge inside the detached kanban worktree (already synced to trunk).
#    --squash stages the branch's net changes onto the trunk tip WITHOUT moving
#    HEAD or recording a merge; we then make one [Role]-prefixed commit.
#    It merges the sha that was read and gated, which the check above showed is the branch's tip.
echo ""
echo "Squash-merging '${BRANCH}' → ${DEFAULT_BRANCH}..."
if ! git -C "$KWT" merge --squash "$QA_READ_FULL" >/dev/null 2>&1; then
  # Name the issue file only when it IS a conflicted path, matched by basename (the mover may
  # already have moved it on the trunk).
  _fpr_conflicted="$(git -C "$KWT" diff --name-only --diff-filter=U 2>/dev/null)"
  _fpr_card_conflict=""
  case "$(printf '%s\n' "$_fpr_conflicted" | sed 's|.*/||')" in
    *"${ISSUE_ID}-"*.md*) _fpr_card_conflict=yes ;;
  esac
  _fpr_card_note=""
  if [ -n "$_fpr_card_conflict" ]; then
    _fpr_card_note="       The conflict includes the ISSUE FILE: the branch edits the card, and the card is the trunk's, never a work branch's.
       For the card: drop its edit from the branch (git fetch ${KWT_REMOTE} ${DEFAULT_BRANCH} && git checkout ${KWT_REMOTE}/${DEFAULT_BRANCH} -- <the card's path>, commit, push) and re-run;
       land the edit itself on the trunk with ./scripts/register-commit.sh --role <role> --message \"<what changed>\" <the card's path>."
  fi
  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null || true
  kit_refuse 1 squash-conflict \
    "Error: squash-merge of '${BRANCH}' hit conflicts (has ${DEFAULT_BRANCH} advanced?)." \
    ${_fpr_card_note:+"$_fpr_card_note"} \
    "       Nothing was pushed." \
    "Next: resolve by hand, then push + move:" \
    "         cd '$KWT' && git merge --squash ${QA_READ_FULL}   # '${BRANCH}' as it was read; resolve, then:" \
    "         git -C '$KWT' commit -m '${SQUASH_MSG}' && git -C '$KWT' push ${KWT_REMOTE} HEAD:${DEFAULT_BRANCH}"
fi

# ── Empty merge: the branch has no net change vs the trunk. Abort non-zero WITHOUT deleting the
#    branch or advancing the issue.
if git -C "$KWT" diff --cached --quiet 2>/dev/null; then
  git -C "$KWT" reset --hard "$KWT_REMOTE/$DEFAULT_BRANCH" --quiet 2>/dev/null || true
  kit_refuse 1 branch-no-net-change \
    "Error: '${BRANCH}' has no net changes vs ${DEFAULT_BRANCH} — nothing to merge." \
    "       Aborting: the branch is NOT deleted and ${ISSUE_ID} stays in dev_complete/." \
    "Next: if '${BRANCH}' was already merged, delete the stale branch by hand (git branch -D '${BRANCH}') and advance the card with ./scripts/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --note \"<what the review found>\"; if it should carry changes, send ${ISSUE_ID} back to Dev."
fi

kwt_commit "$SQUASH_MSG" "the squash" "the branch's own content is what was refused (a hook names the staged path, for example a hat file the branch committed): fix it on '${BRANCH}', push the branch, then run finish-pr.sh again. ${ISSUE_ID} stays in dev_complete/."
# Two lines, the second after the push: a push race rebases and remakes the commit, so the
# local sha is not yet the published one.
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Squash commit: ${SHA} — made locally in the kanban worktree; publishing to the trunk next."
# Push HEAD → trunk and keep the operator's checkout / local ref current.
# A push failure AFTER the local commit is fatal — kwt_finalize prints the loud
# recovery text; ABORT here rather than proceeding to branch deletion.
if ! kwt_finalize; then
  kit_refuse 1 landing-push-failed \
    "Error: push failed after the squash commit — aborting BEFORE branch deletion (${ISSUE_ID} NOT advanced)." \
    "       The squash commit is local in '$KWT'; every later board command refuses until it is published." \
    "Next: publish the squash commit as the Next: line above says, then finish the landing by hand (re-running finish-pr.sh would find nothing left to merge):" \
    "         git -C '$MAIN_ROOT' branch -D '${BRANCH}'; git -C '$MAIN_ROOT' push ${KWT_REMOTE} --delete '${BRANCH}'" \
    "         $SCRIPT_DIR/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --note '<what the review found>'"
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
  echo "     4. $SCRIPT_DIR/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --landed-at ${KWT_LANDED_SHA:-<the published sha>} --note '<what the review found>'"
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

# ── Delete the branch (local unless a worktree holds it, and remote). If the operator's main checkout is sitting
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
    echo "      This script removes no worktree (it could lose files the repository does not hold). Remove it first with"
    echo "      git -C '${MAIN_ROOT}' worktree remove '${_wt_holder:-<path>}'  (it refuses one holding changes); check-board.sh's [f] lists them."
  } >&2
elif ! kit_card_branch_rev "$MAIN_ROOT" "$BRANCH" - >/dev/null; then
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
#    deletion the run did not perform. An operator-supplied --note was completed before the plan.
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
  _squash_clause=""
  [ -z "${KWT_LANDED_SHA:-}" ] || _squash_clause=" as ${KWT_LANDED_SHA}"
  NOTE="Review — PASS. Squash-merged '${BRANCH}'${_rev_clause} into ${DEFAULT_BRANCH}${_squash_clause}; ${_local_clause}; ${_remote_clause}.${_stub_clause}"
fi

# ── Advance the issue dev_complete/ → qa_complete/. move-issue.sh inherits the
#    full worktree machinery: lock + bootstrap + sync + commit + push + board-view ff.
echo ""
echo "Advancing ${ISSUE_ID} → qa_complete/..."
MOVE_ARGS=("$ISSUE_ID" qa_complete --role "$ROLE" --note "$NOTE")
[ "$DISCARD_DIRTY" = "true" ] && MOVE_ARGS+=(--discard-dirty)
# The mover re-reads the QA Verdict table on the trunk; this landing checked the branch before the
# squash, so it passes the squash commit and the mover verifies it (an unset sha means no skip).
[ -z "${KWT_LANDED_SHA:-}" ] || MOVE_ARGS+=(--landed-at "$KWT_LANDED_SHA")
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
    echo "         nothing to do. Finish with just the move (the mover runs only as the trunk's copy, so"
    echo "         bring this checkout to the trunk first):"
    echo "           git switch ${DEFAULT_BRANCH} && git pull --ff-only && $SCRIPT_DIR/move-issue.sh ${ISSUE_ID} qa_complete --role $ROLE --landed-at ${KWT_LANDED_SHA:-<the published sha>} --note '<what the review found>'"
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
#         the landed commit, removed afterwards — without those dependencies, and it says so —
#         unless the landed tree's scripts/config.sh declares POST_MERGE_PREP, which runs in it first;
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
PM_TREE=""; PM_HOW=""; PM_FRESH_DIR=""; PM_UNRUNNABLE=""; _pm_sum=""; _pm_failed=""; _pm_hint=""; _pm_dirty=""; _pm_without="without your installed dependencies"
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
    _pm_hint="  Commit or stash the tracked changes in the gate checkout to read it in place (its installed dependencies are then part of the reading)."
    _pm_dirty="$( { git -C "$GATE_WORKTREE" diff --name-only; git -C "$GATE_WORKTREE" diff --cached --name-only; } 2>/dev/null | sort -u )"
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
    [ -z "$_pm_hint" ] || echo "$_pm_hint"
    if [ -n "$_pm_dirty" ]; then
      _pm_n=0
      while IFS= read -r _pm_p; do
        _pm_n=$((_pm_n + 1))
        [ "$_pm_n" -le 5 ] || continue
        echo "    changed: ${_pm_p}"
        case "$_pm_p" in
          progress/*) echo "      ${_pm_p} is a card copy: if its edit already landed through register-commit.sh, discard it here with"
                      echo "      git -C '${GATE_WORKTREE}' checkout -- '${_pm_p}'   (otherwise commit or stash it)" ;;
        esac
      done <<EOF_PM_DIRTY
$_pm_dirty
EOF_PM_DIRTY
      [ "$_pm_n" -le 5 ] || echo "    (+$((_pm_n - 5)) more)"
    fi
    _pm_tmp="${TMPDIR:-/tmp}"; _pm_tmp="${_pm_tmp%/}"
    if PM_FRESH_DIR="$(mktemp -d "${_pm_tmp}/finish-pr-postmerge.XXXXXX" 2>/dev/null)" \
       && git -C "$MAIN_ROOT" worktree add --detach --quiet "$PM_FRESH_DIR/tree" "$_pm_landed" >/dev/null 2>&1; then
      PM_TREE="$PM_FRESH_DIR/tree"
      PM_HOW="a FRESH worktree at the landed commit — it has none of your checkout's installed dependencies"
      # THE LANDED TREE'S OWN DECLARATION, read as text and never sourced or taken from the
      # environment: the reading must be reproducible from the commit it names. Empty = nothing runs.
      _pm_prep="$(kit_declared_value "$PM_TREE/scripts/config.sh" POST_MERGE_PREP 2>/dev/null || true)"
      if [ -n "$_pm_prep" ]; then
        echo "  Preparing the fresh worktree with the landed commit's POST_MERGE_PREP: ${_pm_prep}"
        if ( cd "$PM_TREE" && sh -c "$_pm_prep" </dev/null ); then
          PM_HOW="a FRESH worktree at the landed commit — prepared the fresh worktree with POST_MERGE_PREP and nothing else of your checkout's"
          _pm_without="prepared only by POST_MERGE_PREP, not with your installed dependencies"
        else
          _pm_prep_rc=$?
          PM_UNRUNNABLE="the declared POST_MERGE_PREP exited ${_pm_prep_rc} in the fresh worktree (the gate did not run)"
        fi
      fi
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
  if [ "$_pm_rc" -eq 2 ]; then
    PM_UNRUNNABLE="the gate at ${PM_READ:-?} in ${PM_TREE} refused to run (exit 2: an empty or malformed table, an unknown argument, or --quick over a table whose every gate is class full): nothing was measured"
  elif [ "$_pm_rc" -eq 3 ]; then
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
  if [ "$ALLOW_STUB" = "true" ] && [ -n "${FINISH_PR_VERIFY_CMD:-}" ]; then
    echo "  post-merge verify --quick: STUB — a test-only command ran in the gate's place; nothing was measured"
    echo "POST_MERGE_GATE: STUB"
  else
    echo "  post-merge verify --quick: PASS on ${DEFAULT_BRANCH} at ${PM_READ:-?} (post-merge, in ${PM_TREE} — ${PM_HOW})"
    # The machine-greppable line, always on stdout; this outcome never moves the exit code.
    echo "POST_MERGE_GATE: PASS"
  fi
else
  echo "  post-merge verify --quick: FAIL on ${DEFAULT_BRANCH} at ${PM_READ:-?} (in ${PM_TREE} — ${PM_HOW}) — ${DEFAULT_BRANCH} may be red; fix it ON ${DEFAULT_BRANCH}, do not park it." >&2
  if [ -n "$PM_FRESH_DIR" ] && [ -z "$_pm_sum" ]; then
    echo "  That reading was taken in a FRESH worktree ${_pm_without}, and the gate's" >&2
    echo "  output carried no summary that could separate a failure from a gate that could not run: re-run" >&2
    echo "  it on ${DEFAULT_BRANCH} at ${PM_READ:-?} in a prepared checkout before acting on it." >&2
  elif [ -n "$PM_FRESH_DIR" ]; then
    echo "  That reading was taken in a FRESH worktree ${_pm_without}. The gate counted" >&2
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
  exit 3   # exit-class: internal
fi
exit 0
