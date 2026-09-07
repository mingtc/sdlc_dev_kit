#!/usr/bin/env bash
# KIT-CLASS: KIT — Orchestrator decomposition into subtask issues. See process/EXTRACTION.md.
# Orchestrator subtask tooling — mirrors move-issue.sh semantics WITHIN the hidden
# subtask tree `progress/subtasks/<parent>/<status>/`. Built lazily, on the first
# decomposition that actually needed it. Subtasks do NOT consume the issue-id
# integer stream — ids are <PARENT>-sM — and they live OFF the main board so the
# PM's backlog stays pristine. The parent stays on the main board and advances to
# qa_complete only when every subtask reaches qa_complete. All commits are stamped
# per --role (default Orchestrator) on the trunk.
#
# This shares the SAME machinery as move-issue.sh / finish-pr.sh:
# scripts/lib/kanban-worktree.sh. Every git op (create / git mv / Activity append /
# commit / push) happens inside the standing detached `.kanban-wt/` worktree pinned
# to the trunk — the operator's checkout is NEVER switched and any working-tree
# state is irrelevant. An older model did `git switch <trunk>` + refuse-on-dirty in
# the operator's own checkout; that is RETIRED. The subtask tree is just a
# different path root under the same worktree, so the move logic is now identical.
#
# Usage:
#   ./scripts/subtask.sh new <PARENT-ID> <suffix> <slug> --title "..." [--prd PRD-NNN] [--stories a,b] [--plan path] [--size S]
#       → creates progress/subtasks/<PARENT-ID>/todo/<PARENT-ID>-<suffix>-<slug>.md
#         from .claude/templates/SUBTASK.template.md, fills frontmatter, commits [Orchestrator].
#   ./scripts/subtask.sh move <PARENT-ID>-<suffix> <target> [--role Orchestrator|Dev|QA] [--note "..."] [--discard-dirty]
#       → git mv within the subtask tree + append Activity + commit "[ROLE] <id> → <target>: NOTE".
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked
#
#   SUBTASK_ROLE   the seat this script commits as (default: Orchestrator). The tag
#                  is CHECKED against your declared role set before anything moves.
#                  Read by the `new` arm; the `move` arm takes an explicit `--role` instead
#                  and defaults to Orchestrator without consulting this variable.
#
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync. Read move-issue.sh's warning about it first:
#   the worktree is shared between lanes. (There is deliberately no --no-commit —
#   batching left the work uncommitted, which the next op's reset --hard then wiped.)
#
# Examples:
#   ./scripts/subtask.sh new <PREFIX>-014 s1 anchor-resolver --title "Floor: anchor resolution"
#   ./scripts/subtask.sh move <PREFIX>-014-s1 in_progress --role Dev --note "Pickup."
#   ./scripts/subtask.sh move <PREFIX>-014-s1 dev_complete --role Dev --note "Ready for review; gates green."
#
#   THE `--role` VALUE IN THE EXAMPLES ABOVE IS AN EXAMPLE VALUE, not a claim that your project
#   declares it. What this tree accepts is whatever ROLE_PREFIXES declares in
#   scripts/githooks/commit-msg; the `move` arm validates against that set before it moves
#   anything. If an example names a role you have withdrawn, it is still showing you the SHAPE of
#   the command — substitute one of your own. (.claude/roles/pm.md's Definition of Ready: an
#   example is read as the contract, not as decoration, so it says which it is.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"
# The mint-time re-head, in one place — scripts/lib/card-head.sh. The block that used to
# sit in the create arm carried its own comment saying it would move "when that lib exists".
. "$SCRIPT_DIR/lib/card-head.sh"

# shellcheck source=lib/role-set.sh
. "$SCRIPT_DIR/lib/role-set.sh"

# config.sh is loaded for its SHARED VALIDATORS, not for a prefix — this script consumes
# none. Unguarded, like the two libraries above: `set -e` aborts loudly on a missing file,
# and the six-script "THE PREFIX HAS ONE AUTHORITY" refusal block is deliberately NOT
# copied here, because pasting a guard for a value this script never reads would add a
# seventh copy of it while fixing a second-copy defect.
# shellcheck source=config.sh
. "$SCRIPT_DIR/config.sh"

# The subtask lifecycle. done/ is deliberately absent: a subtask tree reaches its
# terminal home under progress/done/subtasks/<parent>/ via archive.sh's sweep,
# once its PARENT lands — never by a direct move here.
STATUSES=(todo in_progress dev_complete qa_complete blocked)

# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() { kit_usage "${BASH_SOURCE[0]}"; }   # the path is an ARGUMENT — see lib/usage.sh

# A leading '-' is never a name (process/contracts/issue-creation.md § 3). Guard
# every POSITIONAL, not just the first — `subtask.sh new --help s1 slug` would
# otherwise mint a child whose parent is "--help", with a success message.
# --help exits 0; an unknown option refuses with rc=2.
no_dash() {  # <value> <what it should have been>
  case "$1" in
    -*) echo "Error: '$1' is not a <$2> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
  esac
}

[ $# -lt 1 ] && { usage >&2; exit 1; }
CMD="$1"; shift

# need_val <all remaining args> — refuse an option whose value was not given.
#
# THE SAME HELPER, THE SAME NAME, AND THE SAME SHAPE AS new-issue.sh / new-bug.sh /
# new-refactor.sh, which already had it. It is repeated per script rather than shared
# because several of these source nothing from scripts/lib/ (release.sh by standing
# ruling), and the self-test holds the copies identical.
#
# WHAT IT REPLACES WAS SILENT AND IT WAS EVERYWHERE ELSE. An arm written
# `--x) VAR="${2:-}"; shift 2 ;;` looks safe — `${2:-}` cannot be unbound. But `shift 2`
# with one argument left RETURNS NON-ZERO, and under `set -e` that aborts the script:
# **exit 1, no message, nothing done.** notify.sh was worse, exiting 0 in silence.
# process/contracts/issue-creation.md § 3 says an illegal invocation exits 2 and NAMES the
# option; a missing value is exactly that family, and it was the shape nobody applied it to.
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

case "$CMD" in
  new)
    [ $# -lt 3 ] && { usage >&2; exit 1; }
    no_dash "$1" "PARENT-ID"; no_dash "$2" "suffix"; no_dash "$3" "slug"
    PARENT="$1"; SUFFIX="$2"; SLUG="$3"; shift 3
    TITLE=""; PRD="n/a"; STORIES="[]"; PLAN=""; SIZE="S"
    while [ $# -gt 0 ]; do case "$1" in
      --title) need_val "$@"; TITLE="$2"; shift 2 ;;
      --prd) need_val "$@"; PRD="$2"; shift 2 ;;
      --stories) need_val "$@"; STORIES="[$2]"; shift 2 ;;
      --plan) need_val "$@"; PLAN="$2"; shift 2 ;;
      --size) need_val "$@"; SIZE="$2"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    [ -z "$TITLE" ] && { echo "Error: --title required." >&2; exit 1; }

    # THE SEAT THIS ARM ACTS AS. [Orchestrator] means the decomposer. A knob, never
    # derived: see the note beside the `move` arm's --role whitelist below — this arm
    # had the same exposure and none of the validation, committing an unvalidated
    # hardcoded tag in the same file that spends twelve lines explaining why that is
    # data loss rather than an error.
    ROLE="${SUBTASK_ROLE:-Orchestrator}"
    kit_require_role "$SCRIPT_DIR/.." "$ROLE" SUBTASK_ROLE || exit 1

    # THE SHORT NAME'S SHAPE, and here it is not a tidiness rule — it is a git ref.
    # This arm writes `branch: feature/<ID>-<SLUG>` into the published card, and the
    # role docs tell Dev and QA to `git switch` that value. Measured: a slug with a
    # space makes `git check-ref-format` refuse and `git switch -c` exit 128, so the
    # card is published to the trunk carrying a branch name nobody can check out, and
    # the id is burned. Declared in process/contracts/issue-creation.md § 5;
    # validate_slug (scripts/config.sh) implements it. No pattern here — one shape, one site.
    validate_slug "$SLUG" || exit 2
    # THE SUFFIX IS VALIDATED TOO, and shipping without it would be a false claim of
    # closure: it reaches the same filename and the same ref through the same
    # concatenation. Its shape is NARROWER than a slug's, and that is load-bearing —
    # the `move` arm recovers the parent with ${ID%-s*}, so a suffix that is not
    # s<digits> silently resolves to the wrong parent instead of failing.
    case "$SUFFIX" in
      s[0-9]*) case "${SUFFIX#s}" in *[!0-9]*) SUFFIX_BAD=1 ;; *) SUFFIX_BAD=0 ;; esac ;;
      *) SUFFIX_BAD=1 ;;
    esac
    if [ "$SUFFIX_BAD" -ne 0 ]; then
      {
        echo "Error: the subtask suffix must be s<digits> — got '$SUFFIX'."
        echo "       It becomes part of the card's filename AND of the git branch name, and the"
        echo "       move arm recovers the parent id from it, so a different shape resolves to the"
        echo "       wrong parent rather than failing. NOTHING WAS CHANGED."
      } >&2
      exit 2
    fi

    # Acquire the lock + bootstrap + sync the worktree BEFORE touching anything,
    # so the create lands on the current <remote>/<trunk> tip.
    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync

    TEMPLATE="$KWT/.claude/templates/SUBTASK.template.md"
    [ -f "$TEMPLATE" ] || { echo "Error: template not found at ${TEMPLATE#"$KWT"/}." >&2; exit 1; }

    # THE PARENT MUST EXIST. `issue-creation.md` § 3: "a decomposition names a parent
    # that does not exist ⇒ refuse", and § 2: a child naming an absent parent "is an
    # orphan the board cannot roll up". Without this, `subtask.sh new BOGUS-999 …`
    # created AND PUBLISHED a whole subtask tree under an id nothing owns — and
    # because creation here publishes, the orphan reached the trunk before anyone
    # could read it.
    #
    # SEARCHED ON THE PUBLISHED BOARD, not the operator's checkout: $KWT is pinned to
    # the trunk, which is the same surface the mover computes against, so "exists"
    # means the same thing to both tools. An issue that exists only in someone's
    # workspace is not yet a parent anything can be hung on.
    if ! find "$KWT/progress" -type f -name "${PARENT}-*.md" 2>/dev/null | grep -q .; then
      {
        echo "Error: parent '${PARENT}' does not exist on the published board — refusing to create an orphan."
        echo "  Looked for progress/**/${PARENT}-*.md in the trunk-pinned kanban worktree."
        echo "  If you have just created ${PARENT}, PUBLISH IT FIRST: the board mover and this"
        echo "  script both read the published board, so an unpushed card is invisible to both."
      } >&2
      exit 1
    fi

    ID="${PARENT}-${SUFFIX}"
    SLUGFILE="${ID}-${SLUG}.md"
    DEST_DIR="$KWT/progress/subtasks/${PARENT}/todo"
    mkdir -p "$DEST_DIR"
    DEST="$DEST_DIR/$SLUGFILE"
    [ -e "$DEST" ] && { echo "Error: ${DEST#"$KWT"/} already exists." >&2; exit 1; }
    TODAY=$(date +%Y-%m-%d)
    BRANCH="feature/${ID}-${SLUG}"

    # Fill the template (frontmatter + heading + Activity). Every substitution
    # keys on the frontmatter KEY, never on the template's placeholder VALUE, so
    # a template edit cannot make one a silent no-op. This `sed` has no -i, so it
    # is portable (reads TEMPLATE, writes DEST).
    # EVERY INTERPOLATED VALUE GOES THROUGH sed_repl (scripts/config.sh). This arm takes
    # more free text than any other creator and had none of the escaping the three
    # minting scripts carried. Measured: --title 'Fix A & B' published a card whose
    # frontmatter read "title: Fix A title: <one-line summary…> B" while its H1 was
    # correct — the two disagreed. --title 'a|b' aborted sed AFTER `> "$DEST"` had
    # created the file, and since `reset --hard` does not remove untracked files, the
    # zero-byte husk survived in the SHARED worktree and permanently blocked that id.
    sed -e "s|^id: .*|id: $(sed_repl "$ID")|" \
        -e "s|^type: .*|type: subtask|" \
        -e "s|^parent: .*|parent: $(sed_repl "$PARENT")|" \
        -e "s|^title: .*|title: $(sed_repl "$TITLE")|" \
        -e "s|^size: .*|size: $(sed_repl "$SIZE")|" \
        -e "s|^prd: .*|prd: $(sed_repl "$PRD")|" \
        -e "s|^stories: .*|stories: $(sed_repl "$STORIES")|" \
        -e "s|^branch: .*|branch: $(sed_repl "$BRANCH")|" \
        -e "s|^created_at: .*|created_at: ${TODAY}|" \
        -e "s|^created_by: .*|created_by: $(sed_repl "$ROLE")|" \
        "$TEMPLATE" > "$DEST"

    # The H1. Done as a FIRST-MATCH-ONLY pass rather than a sed pattern: a
    # `s|^# .* — .*|…|` would rewrite every em-dashed heading in the body, not
    # just the title. The H1 is the first `^# ` line after the frontmatter.
    H1_TMP="$(mktemp)"
    # ENVIRON, NOT `awk -v` — and this is a SECOND escaping bug in the same twelve lines,
    # which sed_repl above does NOT fix. `awk -v` performs escape-sequence processing on
    # the value it assigns: measured, a --title of `path C:\tmp\new` yields a real TAB
    # and a real NEWLINE, splitting the H1 across two lines. ENVIRON does no such
    # processing and is POSIX. (perl would also work — do NOT reach for it: that is a
    # dependency past the kit's declared git-plus-POSIX-shell floor. The --plan path below
    # used to use it and no longer does; this file is now perl-free.)
    H1="# ${ID} — ${TITLE}" awk 'BEGIN{done=0} done==0 && /^# /{print ENVIRON["H1"]; done=1; next} {print}' \
      "$DEST" > "$H1_TMP" && mv "$H1_TMP" "$DEST"

    # RE-HEAD THE CARD: the template's travel classification goes, its still-in-force instruction stays.
    # process/EXTRACTION.md § The marker and graduation: a minted card's class has become PROJECT at the
    # moment of minting, so the KIT-CLASS: marker is stripped. But that marker also carried a FILL
    # instruction still in force while the author fills the card, and the same manifest forbids an
    # instruction living inside a marker that will be removed — so this REPLACES the block rather than
    # deleting it. A blind delete would have taken the guidance with the classification, and nowhere
    # else in the kit states it.
    #
    # THE HEAD IS PREPENDED BY THE SHELL, NOT PASSED INTO awk. `awk -v x="$MULTILINE"` fails with
    # "newline in string" and awk then writes NOTHING — measured: the first version of this block
    # produced an EMPTY card. awk deletes the old block, printf writes the new head, cat appends the
    # rest; every step is POSIX and none of them carries a newline through an assignment.
    #
    # DUPLICATED ACROSS THE MINTING SCRIPTS ON PURPOSE, FOR NOW: they source no common file, and giving
    # them one is a structural change owned elsewhere. When that lib exists, this moves into it.
    kit_rehead_card "$DEST" || exit 1


    # Optional --plan. Every substitution is KEYED ON THE KEY, never on the
    # template's placeholder VALUE — that is the whole lesson: a pattern that
    # spells out the placeholder path silently no-ops the day the template's
    # example path changes, and the card then ships with the raw placeholder in
    # it. Three key shapes are handled because templates legitimately differ: the
    # kit template's `- Plan: …` bullet, a frontmatter `plan:` key, and a bare
    # `<plan-path>` token. An earlier version used
    # `sed -i '' … 2>/dev/null || true`, which was BSD-only (a no-op on GNU sed /
    # Linux) AND swallowed the error.
    #
    # awk + ENVIRON, NOT perl. This was `perl -i -pe` with `$ENV{PLAN}`, and perl is a
    # dependency past the kit's declared floor — git and a POSIX shell, with the two
    # optional extras carved out BY NAME so that "what else does this need" has an answer
    # a reader can trust. The floor's value is not that the list is short; it is that the
    # list is TRUE, and an undeclared dependency on an optional path is what an adopter
    # porting to a minimal container finds at the wrong moment. ENVIRON is the same answer
    # the H1 pass above reaches for, for the same reason: the value never passes through
    # a layer that interprets it.
    #
    # THE `<plan-path>` SUBSTITUTION IS DONE BY index/substr, NOT gsub. A path containing
    # `&` or a backslash is legal, and both are special in gsub's REPLACEMENT — `&` inserts
    # the matched text. index/substr has no replacement grammar at all, so there is nothing
    # to escape and nothing to get wrong.
    if [ -n "$PLAN" ]; then
      _PLAN_TMP="$(mktemp)"
      PLAN="$PLAN" awk '
        BEGIN { p = ENVIRON["PLAN"]; tok = "<plan-path>"; tl = length(tok) }
        /^[[:space:]]*[-*][[:space:]]*Plan:[[:space:]]*/ {
          match($0, /^[[:space:]]*[-*][[:space:]]*Plan:[[:space:]]*/)
          print substr($0, 1, RLENGTH) "`" p "`"; next
        }
        /^plan:/ { print "plan: " p; next }
        {
          while ((i = index($0, tok)) > 0)
            $0 = substr($0, 1, i - 1) p substr($0, i + tl)
          print
        }
      ' "$DEST" > "$_PLAN_TMP" && mv "$_PLAN_TMP" "$DEST"
    fi

    git -C "$KWT" add "$DEST"
    MSG="[$ROLE] ${ID} created under ${PARENT} — decomposition slice (via subtask.sh)"
    git -C "$KWT" commit -m "$MSG" --quiet
    echo "Created: ${DEST#"$KWT"/}  (branch: ${BRANCH})"
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit:  ${LOCAL_SHA} — made locally in the kanban worktree, NOT yet published."
    # THE RETURN IS CHECKED. It used to be called bare, so a failed push printed its
    # own recovery text and the script then exited 0 — a creation reported as done
    # whose file exists only in a worktree the next operation will `reset --hard`.
    # The conditional Published: line below was added first and was necessary but not
    # sufficient: it stopped the script ASSERTING a landing, and left it EXITING as
    # though one had happened. A caller reading $? still saw success.
    FINALIZE_RC=0
    kwt_finalize || FINALIZE_RC=$?
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH}"
    else
      {
        echo "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above."
        echo "  This subtask lives in the kanban worktree, which the NEXT board operation"
        echo "  resets --hard. An unpublished commit there is not a draft; it is about to"
        echo "  be destroyed. Re-run the push before running any other board command."
      } >&2
      exit 1
    fi
    [ "$FINALIZE_RC" -eq 0 ] || exit "$FINALIZE_RC"
    ;;

  move)
    [ $# -lt 2 ] && { usage >&2; exit 1; }
    no_dash "$1" "subtask id"; no_dash "$2" "target"
    ID="$1"; TARGET="$2"; shift 2
    ROLE="Orchestrator"; NOTE=""
    while [ $# -gt 0 ]; do case "$1" in
      --role) need_val "$@"; ROLE="$2"; shift 2 ;;
      --note) need_val "$@"; NOTE="$2"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    case "$TARGET" in todo|in_progress|dev_complete|qa_complete|blocked) ;; *) echo "Error: bad target '$TARGET' (one of: ${STATUSES[*]})." >&2; exit 1 ;; esac
    # THE ROLE IS VALIDATED HERE, BEFORE ANY MUTATION — the same whitelist
    # move-issue.sh carries, and for a sharper reason. An unvalidated role reaches
    # the commit subject, where the commit-msg hook rejects it MID-OPERATION: the
    # file has already been git-mv'd and the Activity entry appended inside the
    # shared kanban worktree, and the commit that would have carried them fails. The
    # result is uncommitted state in an area the next board operation `reset --hard`s
    # — so a typo'd role does not produce an error, it produces silent data loss in
    # somebody else's lane. Refusing here costs a re-run; refusing at the hook costs
    # the move.
    #
    # THE ROLE SET IS CARRIED IN SEVERAL FILES; the authoritative list is the TABLE
    # in process/EXTRACTION.md § 2.4 "The role set". This whitelist is one of its
    # rows — added there in the same change, so the index and its members move
    # together. Do not restate the count here: read the table.
    case "$ROLE" in
      PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect) ;;
      "") echo "Error: --role cannot be empty (PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect)." >&2; exit 1 ;;
      *)  echo "Error: --role must be PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect (got '$ROLE')." >&2; exit 1 ;;
    esac
    PARENT="${ID%-s*}"

    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync

    BASE="$KWT/progress/subtasks/${PARENT}"
    [ -d "$BASE" ] || { echo "Error: no subtask tree at progress/subtasks/${PARENT}/." >&2; exit 1; }

    # Locate the file across statuses.
    SRC=""; SRC_FOLDER=""
    for s in "${STATUSES[@]}"; do
      m=$(find "$BASE/$s" -name "${ID}-*.md" -type f 2>/dev/null | head -1 || true)
      [ -n "$m" ] && { SRC="$m"; SRC_FOLDER="$s"; break; }
    done
    [ -z "$SRC" ] && { echo "Error: no ${ID}-*.md under progress/subtasks/${PARENT}/." >&2; exit 1; }
    [ "$SRC_FOLDER" = "$TARGET" ] && { echo "Error: ${ID} already in ${TARGET}/." >&2; exit 1; }

    mkdir -p "$BASE/$TARGET"
    DEST="$BASE/$TARGET/$(basename "$SRC")"
    if git -C "$KWT" ls-files --error-unmatch "$SRC" >/dev/null 2>&1; then
      git -C "$KWT" mv "$SRC" "$DEST"
    else
      mv "$SRC" "$DEST"
    fi

    TODAY=$(date +%Y-%m-%d); [ -z "$NOTE" ] && NOTE="git mv to ${TARGET}/."
    ENTRY="- ${TODAY} [${ROLE}] ${NOTE}"
    [ -n "$(tail -c1 "$DEST" 2>/dev/null)" ] && printf '\n' >> "$DEST"
    printf '%s\n' "$ENTRY" >> "$DEST"
    echo "Moved: subtasks/${PARENT}/${SRC_FOLDER}/ → ${TARGET}/"
    echo "File:  ${DEST#"$KWT"/}"

    git -C "$KWT" add "$DEST"
    MSG="[${ROLE}] ${ID} → ${TARGET}: ${NOTE}"
    git -C "$KWT" commit -m "$MSG" --quiet
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit: ${LOCAL_SHA} — made locally in the kanban worktree, NOT yet published."
    # THE RETURN IS CHECKED — same reason as the `new` arm above: a move that did not
    # publish is a board change nobody else can see, sitting where the next op wipes it.
    FINALIZE_RC=0
    kwt_finalize || FINALIZE_RC=$?
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH} — \"${MSG}\""
    else
      echo "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above." >&2
      exit 1
    fi
    [ "$FINALIZE_RC" -eq 0 ] || exit "$FINALIZE_RC"
    ;;

  -h|--help) usage; exit 0 ;;
  -*) echo "Error: unknown option: $CMD (expected the command 'new' or 'move')" >&2; usage >&2; exit 2 ;;
  *) echo "Unknown command: $CMD" >&2; usage >&2; exit 1 ;;
esac
