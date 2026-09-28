#!/usr/bin/env bash
# KIT-CLASS: KIT — the board move — the one way status changes. See process/EXTRACTION.md.
# Move an issue file between progress/* folders, append an Activity log
# entry, and commit on the trunk — the atomic status transition.
#
# All kanban git ops happen inside a STANDING worktree pinned to the trunk
# (`.kanban-wt/`, gitignored, bootstrapped on first use). The operator's
# current checkout is NEVER switched. The script:
#   0. Probes the TRUNK REF for the named card first (`git ls-tree` on <remote>/<trunk>,
#      no checkout), so a mistyped id refuses without leaving a worktree behind. The
#      probe may only REFUSE; it falls through whenever it cannot answer.
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
#   <R> = @ROLE_SET@
#
# TWO OPERATIONS, and they are not a flag apart — they are different acts:
#   A MOVE changes the card's container, which IS its status, and records that it
#   did. A NOTE-ONLY APPEND records something on the card and changes no status.
#   Exactly one of them per invocation.
#
#   Use --note-only when a card must carry a record BEFORE the act it authorizes (a budget,
#   a ruling) while it already sits in the right column; the move refuses that as a no-op.
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked | done | declined
#   (done/ is the permanent home for completed stories — normally populated by
#    archive.sh sweeping qa_complete/, but a valid manual target too.)
#   (declined/ is for a card that was considered and REFUSED. Like blocked/, it
#    requires --note: the reason is the entire reason to keep the card. It is not
#    swept — its value is being browsable.)
#   (qa_complete/ and done/ refuse a PARENT while any card under progress/subtasks/<ID>/
#    is outside qa_complete/: a parent advances only when every subtask has.)
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
#                    never saw.
#   --set-pr <val>   Persist <val> into the moved file's `pr:` frontmatter, staged
#                    into the SAME commit as the rename + Activity append.
#                    Because the rewrite happens AFTER kwt_sync (in $KWT), it survives
#                    the sync's reset --hard. Idempotent: an already-correct `pr:` line
#                    is left byte-unchanged (no spurious diff). Any trailing comment on
#                    the line is dropped.
#
#                    WHO CALLS IT: nothing shipped does. A FORGE FLAVOUR would pass its
#                    PR/MR reference here (process/GIT-HOSTING.md); the shipped
#                    finish-pr.sh has none to pass.
#
# (There is deliberately no --no-commit: an uncommitted batch blocks every later board
#  operation. Each move commits + pushes.)
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
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   from ROLE_PREFIXES in scripts/githooks/commit-msg. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# --help renders this file's header block; scripts/lib/usage.sh states the window rule.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

# THE ROLE SET IN THE HEADER IS A TOKEN, expanded at print time from the hook through
# scripts/lib/role-set.sh (process/EXTRACTION.md § 2.4), so there is no literal copy for
# `kit-init --roles` to miss. GUARDED: under `set -e` a missing library would abort the
# usage path, which must always succeed (issue-creation.md § 3).
# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

# ── THE PROGRESS RECORD — OPTIONAL (process/contracts/progress-record.md). This script is the
#    role-side consumer: the caller's --role and id assign the `<role>:<issue-id>` actor, so no
#    role doc reports it. Guarded like role-set.sh; absent, every call is a no-op.
# shellcheck source=lib/progress-record.sh
if [ ! -r "$SCRIPT_DIR/lib/progress-record.sh" ] || ! . "$SCRIPT_DIR/lib/progress-record.sh" \
   || ! command -v kit_progress >/dev/null 2>&1; then
  kit_progress() { :; }
fi

usage() {   # the path is an ARGUMENT — see lib/usage.sh
  local roles tok='@ROLE_SET@'
  if command -v kit_role_display >/dev/null 2>&1; then
    roles="$(kit_role_display "$SCRIPT_DIR/.." || true)"
  fi
  # EVERY DEGRADATION NAMES THE SEAM, never the shipped set: a guess that is right about the kit
  # and wrong about this project is the defect being removed, not a fallback from it.
  [ -n "${roles:-}" ] \
    || roles='as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — scripts/lib/role-set.sh is absent, so not listed'
  # SUBSTITUTED BY POSITION, NOT BY PATTERN: `sed` would read a `|`-bearing replacement through
  # its delimiter rules and awk's gsub would read a `&` as the whole match.
  kit_usage "${BASH_SOURCE[0]}" | ROLE_SET_DISPLAY="$roles" awk -v t="$tok" '
    { i = index($0, t)
      if (i) print substr($0, 1, i-1) ENVIRON["ROLE_SET_DISPLAY"] substr($0, i + length(t))
      else   print }'
}

# --help ALWAYS SUCCEEDS, in any position, and is answered BEFORE any argument is interpreted:
# the arity check below would take a bare `--help`, and an option's value slot would publish it.
for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

# A DASH-LEADING FIRST TOKEN IS AN OPTION, NEVER AN ID, and is refused BEFORE the arity test,
# which would otherwise report it as a missing argument without naming it (issue-creation.md § 3).
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
# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}


while [ $# -gt 0 ]; do
  case "$1" in
    --role) need_val "$@"; ROLE="$2"; shift 2 ;;
    --note) need_val "$@"; NOTE="$2"; shift 2 ;;
    --note-only) NOTE_ONLY=1; shift ;;
    --set-pr) need_val "$@"; SET_PR="$2"; shift 2 ;;
    --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
    # An unrecognised option exits 2; a surplus positional exits 1 (issue-creation.md § 3).
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

# A NOTE-ONLY ENTRY MAY NOT EMIT A STATUS DECLARATION. check-board's folder-vs-Activity arm
# reads the LAST `→ <folder>` or backticked `<folder>` token on the last Activity bullet as the
# card's declared status. The formatter below emits none; this refuses one in the note itself.
if [ "$NOTE_ONLY" -eq 1 ]; then
  if printf '%s' "$NOTE" | grep -qE "(→[[:space:]]*(todo|in_progress|dev_complete|qa_complete|blocked|done|declined))|(\`(todo|in_progress|dev_complete|qa_complete|blocked|done|declined)/?\`)"; then
    echo "Error: this note would read as a STATUS DECLARATION, and a note-only entry declares no status." >&2
    echo "  It contains a transition arrow or a backticked status folder, which the drift report" >&2
    echo "  reads as 'this card's declared status is X' — on a card that has not moved." >&2
    echo "  Rephrase without '→ <folder>' and without \`<folder>\`, or make it a real move." >&2
    exit 1
  fi
fi

# The status folder set is a SEAM WITHOUT A VARIABLE: several files carry the column names as
# literals, and not all the same ones. Adding or renaming a column means opening each carrier;
# process/EXTRACTION.md § "the status folder set" is the list.
if [ "$NOTE_ONLY" -eq 0 ]; then
  case "$TARGET" in
    todo|in_progress|dev_complete|qa_complete|blocked|done|declined) ;;
    *) echo "Error: target must be one of todo|in_progress|dev_complete|qa_complete|blocked|done|declined (got '$TARGET')" >&2; exit 1 ;;
  esac

  # A PARK WITH NO BLOCKER RECORDED IS NOT A PARK: the default note ("git mv to blocked/.")
  # records nothing about why, in the one column whose purpose is the reason.
  if [ "$TARGET" = "blocked" ] && [ -z "$NOTE" ]; then
    echo "Error: moving to blocked/ requires --note \"…\" naming the blocker." >&2
    echo "  A parked card whose blocker is not written down cannot be unparked by anyone" >&2
    echo "  but the person who parked it, and they will not remember either." >&2
    exit 1
  fi

  # A DECLINE WITH NO RECORDED WHY IS A DELETION WITH EXTRA STEPS: the reasoning is all a
  # declined card still carries.
  if [ "$TARGET" = "declined" ] && [ -z "$NOTE" ]; then
    echo "Error: moving to declined/ requires --note \"…\" naming WHY it was refused." >&2
    echo "  The reason is the entire value of a declined card. Without it this is a" >&2
    echo "  deletion with extra steps, and the next person to propose the same thing" >&2
    echo "  starts from zero." >&2
    exit 1
  fi
fi

# Derived by lib/role-set.sh kit_role_resolve; this literal is only its stamped default (see there).
ROLE_SET_DEFAULT='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
if command -v kit_role_resolve >/dev/null 2>&1; then
  kit_role_resolve "$SCRIPT_DIR/.." "$ROLE_SET_DEFAULT"
else
  # The library is the guarded source above, so it can be absent. Same policy, stated the same way.
  KIT_ROLE_SET="$ROLE_SET_DEFAULT"
  KIT_ROLE_SRC="THE KIT'S FALLBACK SET — scripts/lib/role-set.sh is absent, so this project's declared set could not be read"
  KIT_ROLE_DEFAULTED=1
fi
# NAMED, NOT SILENT, AND BEFORE ANYTHING IS ENFORCED: otherwise an acceptance or a refusal
# reads as being about this project's declared set when it is not.
[ -z "${KIT_ROLE_DEFAULTED:-}" ] \
  || echo "Note: --role is being checked against $KIT_ROLE_SRC" >&2
if [ -z "$ROLE" ]; then
  echo "Error: --role is required ($KIT_ROLE_SET)." >&2; usage >&2; exit 1
fi
if ! kit_role_member "$KIT_ROLE_SET" "$ROLE"; then
  { echo "Error: --role must be $KIT_ROLE_SET (got '$ROLE')."
    echo "       That set is $KIT_ROLE_SRC."
  } >&2
  exit 1
fi

# ONE not-found refusal TEXT, TWO reads that can reach it (the probe below and the lookup
# after the sync); the argument names which tree was read. Every board this tool reads is
# the TRUNK's, so a card minted but not yet pushed does not exist to it.
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
# The lookup below materialises .kanban-wt/, so a mistyped id would leave a worktree behind
# before refusing. This asks first, against the trunk's TREE OBJECT (`git ls-tree` on
# <remote>/<trunk>: no checkout, no worktree, no lock). Three rules keep it honest:
#   1. IT READS THE TRUNK REF, NEVER THE OPERATOR'S WORKING TREE — that is a different board.
#   2. IT MAY ONLY REFUSE, NEVER ACCEPT. The lookup after the sync still decides every
#      acceptance, the multiple-match refusal and the already-in-target refusal.
#   3. A PROBE THAT CANNOT ANSWER FALLS THROUGH SILENTLY: an unreadable ref, a trunk with no
#      progress/ tree, an id carrying glob metacharacters (which `find` expands and this does not).
# And a miss is CONFIRMED BY A FETCH before it may refuse: <remote>/<trunk> is a cached ref.
# A failed fetch is rule 3 again.
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

# Find file by ID inside the kanban worktree. Depth 2 is progress/<column>/<card>: a
# parent's subtasks (<PARENT>-sM, under subtasks/ or done/subtasks/) share its prefix.
MATCHES=()
while IFS= read -r f; do
  MATCHES+=("$f")
done < <(find "$KWT/progress" -maxdepth 2 -name "${ISSUE_ID}-*.md" -type f 2>/dev/null | sort)

if [ ${#MATCHES[@]} -eq 0 ]; then
  # THE AUTHORITATIVE READ: reaching here means the probe fell through (rule 3) or the board
  # changed between the two reads.
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
  # THE CARD DOES NOT MOVE, so the destination IS the source, and status still lives in
  # exactly one place (contracts/board-mover.md § 2).
  DEST="$SRC"
else
  DEST_DIR="$KWT/progress/$TARGET"
  DEST="$DEST_DIR/$(basename "$SRC")"

  # THE NO-OP REFUSAL IS SCOPED TO A MOVE; a note-only append never moves anything.
  if [ "$SRC_FOLDER" = "$TARGET" ]; then
    echo "Error: ${ISSUE_ID} is already in progress/${TARGET}/. Nothing to move." >&2
    echo "  To record something on this card WITHOUT moving it:" >&2
    echo "    $0 $ISSUE_ID --note-only --role $ROLE --note \"…\"" >&2
    exit 1
  fi

  # A PARENT ADVANCES ONLY WHEN EVERY SUBTASK HAS: qa_complete and done both claim the whole
  # issue reviewed, and archive.sh would retire an open slice with it.
  if [ "$TARGET" = "qa_complete" ] || [ "$TARGET" = "done" ]; then
    _open="$(kwt_open_subtasks "$ISSUE_ID")"
    if [ -n "$_open" ]; then
      {
        echo "Error: ${ISSUE_ID} has subtask(s) not yet in qa_complete/, so it cannot move to ${TARGET}/:"
        printf '%s\n' "$_open" | sed 's/^/    /'
        echo "  A parent advances only when every subtask has. Finish each, or close one that will not"
        echo "  be done with  ./scripts/subtask.sh move <id> declined --note \"why\". NOTHING WAS CHANGED."
      } >&2
      exit 1
    fi
  fi

  # A missing target folder ABORTS rather than being created: git does not track an
  # empty directory, so a board whose columns exist only as .gitkeep-less dirs does
  # not survive a clone. kit-init.sh writes one .gitkeep per column for exactly this.
  [ -d "$DEST_DIR" ] || { echo "Error: progress/$TARGET/ does not exist in the worktree." >&2; exit 1; }

  # PLACEHOLDER LINT AT THE DEV_COMPLETE BOUNDARY: unfilled `<angle-bracket>` text travels into
  # squash subjects and the archive index. WARNS, never refuses: an angle bracket is also legal
  # prose, and a refusal on valid input trains the operator to ignore it (instruments.md § A.8).
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
# TWO SHAPES, AND THE DIFFERENCE IS LOAD-BEARING:
#   move:      - <date> [<role>] → <target>: <note>
#   note-only: - <date> [<role>] NOTE: <note>
# A move carries its target, so the drift report can hold the card's folder against its log.
# A note-only entry carries no arrow and no backticked folder, so the report skips it.
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

# --set-pr: persist the PR/MR reference into the moved file's `pr:` frontmatter, AFTER
# kwt_sync's reset --hard and inside $KWT, so it lands in the same commit. Idempotent; only
# the FIRST `^pr:` line is rewritten, and any trailing comment on it is dropped.
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
# Local first; published after the push, whose rebase can replace this sha.
SHA=$(git -C "$KWT" rev-parse --short HEAD)
echo "Commit: ${SHA} — made locally in the kanban worktree, NOT yet published."

# Push HEAD → <trunk> and keep the operator's view / local ref current.
# A push failure AFTER the local commit is FATAL — kwt_finalize prints the loud
# recovery text and returns nonzero; propagate it as a nonzero exit rather than
# reporting success on a commit that never reached the remote.
kwt_finalize || exit 1
echo "Published: ${KWT_LANDED_SHA:-<unknown>} on ${DEFAULT_BRANCH} — \"${MSG}\""

# THE RECORD, AFTER THE PUSH: it can only describe something that reached the trunk. The two
# operations differ in wording and `event`, not in shape.
if [ "$NOTE_ONLY" -eq 1 ]; then
  kit_progress "${ROLE}:${ISSUE_ID}" info "noted on ${ISSUE_ID}: ${NOTE}" \
    "event=note" "issue=${ISSUE_ID}" "role=${ROLE}" "sha=${KWT_LANDED_SHA:-$SHA}"
else
  kit_progress "${ROLE}:${ISSUE_ID}" status "${ISSUE_ID} → ${TARGET}: ${NOTE}" \
    "event=move" "issue=${ISSUE_ID}" "role=${ROLE}" "to=${TARGET}" "sha=${KWT_LANDED_SHA:-$SHA}"
fi
# AN `if`, NOT AN `&&` CHAIN: the chain returns non-zero when the shas match (the normal case),
# and under `set -e` that aborts after a successful landing.
if [ -n "${KWT_LANDED_SHA:-}" ] && [ "${KWT_LANDED_SHA}" != "${SHA}" ]; then
  echo "  (the push rebased onto ${KWT_REMOTE}/${DEFAULT_BRANCH}; the landed commit is ${KWT_LANDED_SHA}, not ${SHA})"
fi
