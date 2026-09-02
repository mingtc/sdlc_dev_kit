#!/usr/bin/env bash
# KIT-CLASS: KIT — the board move — the one way status changes. See process/EXTRACTION.md.
# Move an issue file between progress/* folders, append an Activity log
# entry, and commit on the trunk — the atomic status transition.
#
# All kanban git ops happen inside a STANDING worktree pinned to the trunk
# (`.kanban-wt/`, gitignored, bootstrapped on first use). The operator's
# current checkout is NEVER switched. The script:
#   0. Probes the TRUNK REF for the named card BEFORE building anything — a
#      `git ls-tree` on <remote>/<trunk>, which needs no checkout — so a mistyped
#      id refuses without leaving a worktree behind. The probe may only REFUSE;
#      it never accepts, and it falls through whenever it cannot answer.
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
#   ./scripts/move-issue.sh <ID> <target> --role <R> [--note "..."] [--discard-dirty] [--set-pr <val>]
#   ./scripts/move-issue.sh <ID> --note-only --role <R> --note "..."   # record WITHOUT moving
#
#   <R> = PM | Dev | QA | Refactorer | UIDesigner | Orchestrator | Architect
#
# TWO OPERATIONS, and they are not a flag apart — they are different acts:
#   A MOVE changes the card's container, which IS its status, and records that it
#   did. A NOTE-ONLY APPEND records something on the card and changes no status.
#   Exactly one of them per invocation.
#
#   Why the second exists: doctrine repeatedly requires a card to carry a record
#   BEFORE the act it authorizes — a budget declared before the first spend, a
#   ruling cited before it is executed — on a card that is already in the right
#   column. The move refuses that ("already in progress/…/. Nothing to move"), so
#   the kit's own safety-critical declarations were being appended BY HAND, four
#   steps, every one of them skippable and none of them reported.
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked | done
#   (done/ is the permanent home for completed stories — normally populated by
#    archive.sh sweeping qa_complete/, but a valid manual target too.)
#
# Flags:
#   --note-only      Append an Activity entry and publish it WITHOUT moving the
#                    card. Takes no target; --note is REQUIRED (the note is the
#                    entire content). The entry is written so the drift report
#                    reads it as un-judgeable rather than as a status
#                    declaration, and a note that would read as one is refused.
#   --note "..."     Activity-log body. On a move it defaults to "git mv to
#                    <target>/." — except for blocked/, which requires a real one:
#                    a parked card whose blocker is not written down cannot be
#                    unparked by anyone but whoever parked it.
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
#                    the line is dropped.
#
#                    WHO CALLS IT: nothing shipped does. The forge-agnostic
#                    finish-pr.sh this kit ships uses no forge API and has no PR/MR
#                    reference to pass — a FORGE FLAVOUR would call it, and that is
#                    an optional extension (process/GIT-HOSTING.md), not the shipped
#                    path. This comment previously said finish-pr.sh "passes the
#                    merged PR/MR reference through this flag", in the present tense,
#                    about a call that does not exist: a claim a reader would have
#                    gone looking for and not found.
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

# --help ALWAYS SUCCEEDS, and has to be answered BEFORE the arity check. A bare
# `--help` is ONE argument, so the guard below swallowed it and exited 1 with usage
# on stderr — the opposite of the shape every other script here follows and that
# the issue-creation contract states: usage on stdout, exit 0. The option handler
# further down has always had the right arm; it was simply unreachable.
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

# A DASH-LEADING FIRST TOKEN IS AN OPTION, NEVER AN ID — and this must be checked BEFORE
# the arity test, not after. `move-issue.sh --typo` has one argument, so the arity test
# fired first and refused with the status a MISSING ARGUMENT gets, printing usage and
# never naming the flag. The contract's words are "never ignored, never treated as a
# positional value" (issue-creation.md § 3), and being swallowed by an arity check is a
# third way of not being named.
case "${1:-}" in
  -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

if [ $# -lt 2 ]; then usage >&2; exit 1; fi

ISSUE_ID="$1"; shift

# THE TARGET IS POSITIONAL AND OPTIONAL, because --note-only is a DIFFERENT
# OPERATION rather than a move with a missing argument: it records without
# moving, so there is no target to name (contracts/board-mover.md § 2). A leading
# `--` therefore means "no positional target"; anything else is the target.
TARGET=""
case "${1:-}" in
  -*) ;;                              # `-*`, not `--*`: a single-dash token is an option
                                      # too, and taking it as the target renamed a typo
                                      # into a board column that does not exist.
  *)   TARGET="$1"; shift ;;
esac
ROLE=""; NOTE=""; SET_PR=""; NOTE_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    --note-only) NOTE_ONLY=1; shift ;;
    --set-pr) SET_PR="${2:-}"; shift 2 ;;
    --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    # AN UNRECOGNISED OPTION EXITS 2; a surplus POSITIONAL exits 1. Two classes, and the
    # kit already told them apart in every script that has a `-*)` arm — these did not, so a
    # mistyped flag was reported with the status a surplus word gets. Named in
    # process/contracts/issue-creation.md § 3: ONE status across the shipped set.
    -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# EXACTLY ONE OF THE TWO OPERATIONS. Both, or neither, is a caller who does not
# know which one they wanted — and guessing between "move it" and "do not move
# it" is the one guess this tool must never make.
if [ "$NOTE_ONLY" -eq 1 ] && [ -n "$TARGET" ]; then
  echo "Error: --note-only records WITHOUT moving, so it takes no target (got '$TARGET')." >&2
  echo "  To move and record in one act:  $0 $ISSUE_ID $TARGET --role <R> --note \"…\"" >&2
  exit 1
fi
if [ "$NOTE_ONLY" -eq 0 ] && [ -z "$TARGET" ]; then
  echo "Error: no target given. Name a target folder to MOVE, or pass --note-only to RECORD without moving." >&2
  usage >&2; exit 1
fi

# A NOTE-ONLY APPEND WITHOUT A NOTE IS AN EMPTY RECORD. The move has a defensible
# default note ("git mv to <target>/.") because the move itself is the fact being
# recorded; a note-only append has no such fact — the note IS the whole content.
if [ "$NOTE_ONLY" -eq 1 ] && [ -z "$NOTE" ]; then
  echo "Error: --note-only requires --note \"…\" — the note is the entire content of the entry." >&2
  exit 1
fi

# A NOTE-ONLY ENTRY MAY NOT EMIT A STATUS DECLARATION, and this refusal is what
# makes that guarantee real rather than best-effort. check-board's folder-vs-
# Activity arm reads the LAST structured status token on the last Activity bullet
# — a transition arrow `→ <folder>` or a backticked `` `<folder>` `` — and treats
# a bullet with no such token as un-judgeable, which is exactly the behaviour a
# note-only entry needs. The formatter below emits no such token; this refuses
# the remaining way one could arrive, which is inside the caller's own note text.
# Without it the guarantee would hold for the tool and not for its output, and a
# note reading "unblocked by → in_progress work" would be read as a declaration
# that the card has moved when it has not.
if [ "$NOTE_ONLY" -eq 1 ]; then
  if printf '%s' "$NOTE" | grep -qE "(→[[:space:]]*(todo|in_progress|dev_complete|qa_complete|blocked|done))|(\`(todo|in_progress|dev_complete|qa_complete|blocked|done)/?\`)"; then
    echo "Error: this note would read as a STATUS DECLARATION, and a note-only entry declares no status." >&2
    echo "  It contains a transition arrow or a backticked status folder, which the drift report" >&2
    echo "  reads as 'this card's declared status is X' — on a card that has not moved." >&2
    echo "  Rephrase without '→ <folder>' and without \`<folder>\`, or make it a real move." >&2
    exit 1
  fi
fi

# The status folder set. It is a SEAM WITHOUT A VARIABLE: several files carry the
# column names as literals, and they do NOT all carry the same ones — this script
# and the drift report hold the full set, subtask.sh omits `done`, and setup.sh
# adds `history`. So adding or renaming a column means opening each carrier and
# deciding what it should hold, not applying one edit N times.
# process/EXTRACTION.md § "the status folder set" is the list and states the cost;
# read it there rather than trusting an enumeration written here. (This comment
# used to name four scripts and cost them as one edit each. Two of those four --
# archive.sh and finish-pr.sh -- do not carry the SET; each performs ONE transition
# and names its two ends, so a change to a column either of them names touches it.
# Two earlier attempts at this note were both wrong: the first said they held none
# of these values, on a grep scoped to in_progress, the one column neither uses;
# the second said a column added inside the Dev->QA flow touches them and one at
# either end does not, which is inverted for archive.sh -- it moves qa_complete to
# done and refuses a missing done/.)
if [ "$NOTE_ONLY" -eq 0 ]; then
  case "$TARGET" in
    todo|in_progress|dev_complete|qa_complete|blocked|done) ;;
    *) echo "Error: target must be one of todo|in_progress|dev_complete|qa_complete|blocked|done (got '$TARGET')" >&2; exit 1 ;;
  esac

  # A PARK WITH NO BLOCKER RECORDED IS NOT A PARK. The board's own legend reads
  # "parked, WITH THE BLOCKER WRITTEN DOWN", and the default note ("git mv to
  # blocked/.") satisfies the mover while recording nothing about WHY — so the
  # one column whose entire purpose is to carry a reason is the one that accepts
  # a move without one. Reproduced. The other columns' default note is honest
  # (the move IS the fact); blocked/'s is not.
  if [ "$TARGET" = "blocked" ] && [ -z "$NOTE" ]; then
    echo "Error: moving to blocked/ requires --note \"…\" naming the blocker." >&2
    echo "  A parked card whose blocker is not written down cannot be unparked by anyone" >&2
    echo "  but the person who parked it, and they will not remember either." >&2
    exit 1
  fi
fi

# THE ROLE SET IS CARRIED IN SEVERAL FILES — change one, change them all. The
# authoritative list is the TABLE in process/EXTRACTION.md § 2.4 "The role set";
# read it there rather than trusting a count written here, which is the sentence
# that rots (doctrine/staleness.md § C — this comment said "FOUR PLACES" and went
# false the first time a fifth reader was added).
# The reason is a measured incident: the commit-msg hook accepted a role this
# whitelist did not, so the standing seat COULD NOT MOVE A CARD and had to borrow
# another hat to do it.
case "$ROLE" in
  PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect) ;;
  "") echo "Error: --role is required (PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect)." >&2; usage >&2; exit 1 ;;
  *) echo "Error: --role must be PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect (got '$ROLE')" >&2; exit 1 ;;
esac

# ONE not-found refusal TEXT, TWO reads that can reach it: the pre-bootstrap probe
# below and the authoritative lookup after the sync. Factored so the two cannot
# drift — what an operator is told about a mistyped id must not depend on which
# read caught it, and the only honest difference is WHICH TREE was read, which is
# this function's argument.
#
# THE PUSH-BEFORE-YOU-MOVE TRAP, replicated three times independently: the message
# was TRUE and its cause was unfindable. Every board this tool reads is the TRUNK's
# — the tree object at <remote>/<trunk> for the probe, the reset-to-<remote>/<trunk>
# worktree for the lookup — so a freshly minted card that has not been committed AND
# PUSHED does not exist to it, however plainly it sits in the operator's own checkout.
issue_not_found() {   # <provenance — which tree was read>
  {
    echo "Error: no file matching ${ISSUE_ID}-*.md found under progress/."
    echo "       ($1)"
    echo "       Minted but not yet pushed? A new card is invisible here until it reaches the trunk:"
    echo "         git add progress/todo/${ISSUE_ID}-*.md && git commit -m \"[<Role>] ${ISSUE_ID}: mint\" && git push"
    echo "       Otherwise check the id — ls progress/*/ | grep ${ISSUE_ID}"
  } >&2
}

# Resolve repo root + trunk (works from any worktree).
kwt_resolve

# ── THE PRE-BOOTSTRAP EXISTENCE PROBE, AND WHY IT MAY ONLY EVER REFUSE ────────
# Every refusal above this line is decided from the invocation alone, so it costs
# nothing. The card lookup is not: the board this tool moves cards on is the
# TRUNK's, and reading it used to mean MATERIALIZING it — so a syntactically valid
# invocation naming a card that does not exist was GUARANTEED to bootstrap a
# registered .kanban-wt/ before it could refuse. Measured: a mistyped id left one
# behind in a checkout shared with other lanes, untracked and one blanket `git add`
# from being committed, and it had to be proven safe before it could be removed.
#
# So the existence question is asked FIRST, against the trunk's own TREE OBJECT —
# `git ls-tree` on <remote>/<trunk> — which needs no checkout, no worktree, not
# even the lock. THREE RULES MAKE THAT HONEST, and each closes a way such a probe
# lies:
#   1. IT READS THE TRUNK REF, NEVER THE OPERATOR'S WORKING TREE. The checkout is
#      a DIFFERENT BOARD — that is the entire push-before-you-move trap above — so
#      a probe answering from it would refuse cards that exist and pass cards that
#      do not, which is worse than the state it saves.
#   2. IT MAY ONLY REFUSE, NEVER ACCEPT. A hit here proves nothing and is not
#      relied on: the lookup after the sync is untouched and still decides every
#      acceptance, the multiple-match refusal and the already-in-target refusal.
#   3. A PROBE THAT CANNOT ANSWER FALLS THROUGH SILENTLY. An unreadable ref, a
#      trunk with no progress/ tree, an id carrying glob metacharacters (which the
#      `find` below expands and this literal prefix test does not) — each of those
#      is "I do not know", and "I do not know" is not a refusal.
# And a miss is CONFIRMED BY A FETCH before it is allowed to refuse.
# <remote>/<trunk> is a CACHED ref: a card another operator pushed a minute ago is
# absent from it and present on the trunk, and kwt_sync's own fetch is what would
# have found it. So a miss costs one single-branch fetch and re-reads; only a miss
# that survives a successful fetch refuses, and a failed fetch is rule 3 again.
PROBE_REF="refs/remotes/$KWT_REMOTE/$DEFAULT_BRANCH"
PROBE_SEEN=0   # tracked paths seen under progress/ — 0 means "no board here", which is
PROBE_HIT=0    #   not the same fact as "the card is not on the board"
probe_board() {   # <tree-ish> → sets PROBE_SEEN/PROBE_HIT; non-zero if the ref is unreadable
  local listing p b
  listing="$(git -C "$MAIN_ROOT" ls-tree -r --name-only "$1" -- progress 2>/dev/null)" || return 1
  PROBE_SEEN=0; PROBE_HIT=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    PROBE_SEEN=$(( PROBE_SEEN + 1 ))
    b="${p##*/}"
    case "$b" in *.md) ;; *) continue ;; esac
    # LITERAL prefix test, deliberately: the id is data, not a pattern, here.
    [ "${b#"${ISSUE_ID}"-}" != "$b" ] && PROBE_HIT=$(( PROBE_HIT + 1 ))
  done <<PROBE_LISTING
$listing
PROBE_LISTING
  return 0
}

PROBE_ID_IS_GLOB=0
case "$ISSUE_ID" in *'*'*|*'?'*|*'['*) PROBE_ID_IS_GLOB=1 ;; esac

# ONE CHAIN, NOT NESTED ifs, so the refusal is unreachable unless every link held
# in order — including the fetch, which is deliberately INSIDE the condition: it
# runs only on a miss (the happy path pays nothing) and its failure is a
# fall-through, not a refusal. Do not hoist it out.
if [ "$PROBE_ID_IS_GLOB" -eq 0 ] \
   && probe_board "$PROBE_REF" && [ "$PROBE_SEEN" -gt 0 ] && [ "$PROBE_HIT" -eq 0 ] \
   && git -C "$MAIN_ROOT" fetch "$KWT_REMOTE" "$DEFAULT_BRANCH" --quiet 2>/dev/null \
   && probe_board "$PROBE_REF" && [ "$PROBE_SEEN" -gt 0 ] && [ "$PROBE_HIT" -eq 0 ]; then
  issue_not_found "read the TRUNK's board straight out of $KWT_REMOTE/$DEFAULT_BRANCH, freshly fetched — not your checkout; no kanban worktree was created"
  exit 1
fi

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
  # THE AUTHORITATIVE READ, and the one the probe above never substitutes for: it
  # searches the trunk's copy inside .kanban-wt/, reset --hard to <remote>/<trunk>
  # on every op. Reaching here means the probe fell through (rule 3) or the board
  # changed under us between the two reads — either way this decides, not it.
  issue_not_found "searched the TRUNK's board inside the kanban worktree, not your checkout"
  exit 1
fi
if [ ${#MATCHES[@]} -gt 1 ]; then
  echo "Error: multiple files match ${ISSUE_ID}-*.md:" >&2
  printf '  %s\n' "${MATCHES[@]}" >&2
  exit 1
fi

SRC="${MATCHES[0]}"
SRC_FOLDER=$(basename "$(dirname "$SRC")")

if [ "$NOTE_ONLY" -eq 1 ]; then
  # THE CARD DOES NOT MOVE, so the destination IS the source. Nothing below
  # touches the container, which is what keeps "the container IS the status"
  # true: this operation adds a record and changes no status, so status still
  # lives in exactly one place (contracts/board-mover.md § 2).
  DEST="$SRC"
else
  DEST_DIR="$KWT/progress/$TARGET"
  DEST="$DEST_DIR/$(basename "$SRC")"

  # THE NO-OP REFUSAL IS SCOPED TO A MOVE, and must stay that way. It exists so a
  # move that changes nothing does not append a second meaningless entry — but a
  # note-only append is not a move that changed nothing, it is a record that was
  # never going to move anything. Applying this refusal to it is what made the
  # kit's own live-resource declaration unperformable by its named tool.
  if [ "$SRC_FOLDER" = "$TARGET" ]; then
    echo "Error: ${ISSUE_ID} is already in progress/${TARGET}/. Nothing to move." >&2
    echo "  To record something on this card WITHOUT moving it:" >&2
    echo "    $0 $ISSUE_ID --note-only --role $ROLE --note \"…\"" >&2
    exit 1
  fi

  # A missing target folder ABORTS rather than being created: git does not track an
  # empty directory, so a board whose columns exist only as .gitkeep-less dirs does
  # not survive a clone. kit-init.sh writes one .gitkeep per column for exactly this.
  [ -d "$DEST_DIR" ] || { echo "Error: progress/$TARGET/ does not exist in the worktree." >&2; exit 1; }

  # PLACEHOLDER LINT AT THE DEV_COMPLETE BOUNDARY. Unfilled `<angle-bracket>`
  # template text propagates silently from a minted card into squash subjects and
  # the archive index, where nobody re-reads it. dev_complete is the last moment
  # the card's author is still the person holding it. WARNS, never refuses: the
  # angle bracket is also legal prose ("<1s", "a <slug> is fine"), so a refusal
  # here would reject valid input for a reason unrelated to correctness — which
  # trains the operator to ignore it (process/doctrine/instruments.md § A.8).
  if [ "$TARGET" = "dev_complete" ]; then
    ph="$(grep -nE '<[a-z][a-z0-9 _|/-]*>' "$SRC" 2>/dev/null | head -5 || true)"
    if [ -n "$ph" ]; then
      {
        echo "Warning: ${ISSUE_ID} still carries unfilled <angle-bracket> template text:"
        printf '%s\n' "$ph" | sed 's/^/    /'
        echo "  These travel into the squash subject and the archive index. Fill them now if"
        echo "  they are placeholders; ignore this if they are prose. (Not a refusal.)"
      } >&2
    fi
  fi

  # Move: prefer `git mv` (tracks rename); fall back to `mv` if untracked.
  if git -C "$KWT" ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then
    git -C "$KWT" mv "$SRC" "$DEST"
  else
    mv "$SRC" "$DEST"
  fi
fi

# Append Activity entry at EOF (Activity must be the last section in the file).
#
# TWO SHAPES, AND THE DIFFERENCE IS LOAD-BEARING, not cosmetic.
#   move:      - <date> [<role>] → <target>: <note>
#   note-only: - <date> [<role>] NOTE: <note>
# A move CARRIES ITS TARGET in the entry, so the drift report can hold the card's
# folder against what its own log says it should be — previously the target lived
# only in the commit subject, so a custom-note move was un-judgeable and the
# detector was blind in exactly the workflow the manual mandates.
# A note-only entry DELIBERATELY CARRIES NO ARROW AND NO BACKTICKED FOLDER, so
# the same detector reads it as un-judgeable and skips it, instead of reading a
# note as a status declaration on a card that has not moved. The refusal above
# keeps the caller's own note text from reintroducing one.
TODAY=$(date +%Y-%m-%d)
if [ "$NOTE_ONLY" -eq 1 ]; then
  ENTRY="- ${TODAY} [${ROLE}] NOTE: ${NOTE}"
else
  [ -z "$NOTE" ] && NOTE="git mv to ${TARGET}/."
  ENTRY="- ${TODAY} [${ROLE}] → ${TARGET}: ${NOTE}"
fi

if [ -n "$(tail -c1 "$DEST" 2>/dev/null)" ]; then
  printf '\n' >> "$DEST"
fi
printf '%s\n' "$ENTRY" >> "$DEST"

if [ "$NOTE_ONLY" -eq 1 ]; then
  # NO from→to LINE, because nothing moved. Printing one would be the tool
  # asserting a transition it did not perform (contracts/board-mover.md § 4).
  echo "Recorded (no move): ${ISSUE_ID} stays in progress/${SRC_FOLDER}/"
else
  echo "Moved: progress/${SRC_FOLDER}/ → progress/${TARGET}/"
fi
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
# THE SUBJECT SAYS WHICH OPERATION THIS WAS. `→ <target>` is the log's shorthand
# for a transition, and a note-only commit performed none — a subject claiming one
# would make `git log --grep='→ qa_complete'` count landings that never happened.
if [ "$NOTE_ONLY" -eq 1 ]; then
  MSG="[${ROLE}] ${ISSUE_ID} NOTE: ${NOTE}"
else
  MSG="[${ROLE}] ${ISSUE_ID} → ${TARGET}: ${NOTE}"
fi
git -C "$KWT" commit -m "$MSG" --quiet
# Local first, published after the push — the one-line form claimed "on <trunk>"
# before anything was pushed, and named a sha the push's rebase can replace.
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree, NOT yet published."

# Push HEAD → <trunk> and keep the operator's view / local ref current.
# A push failure AFTER the local commit is FATAL — kwt_finalize prints the loud
# recovery text and returns nonzero; propagate it as a nonzero exit rather than
# reporting success on a commit that never reached the remote.
kwt_finalize || exit 1
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${MSG}\""
# AN `if`, NOT AN `&&` CHAIN. The chain form returns NON-ZERO whenever the shas
# match — the normal case — and under `set -e` that is an abort AFTER a successful
# landing, which is the precise hazard the ungated-landing review found. Caught by the
# control, not by reading: a green landing exited 1.
if [ -n "${KWT_LANDED_SHA:-}" ] && [ "${KWT_LANDED_SHA}" != "${SHA}" ]; then
  echo "  (the push rebased onto ${KWT_REMOTE}/${DEFAULT_BRANCH}; the landed commit is ${KWT_LANDED_SHA}, not ${SHA})"
fi
