#!/usr/bin/env bash
# KIT-CLASS: KIT — Orchestrator decomposition into subtask issues. See process/EXTRACTION.md.
# Orchestrator subtask tooling — mirrors move-issue.sh semantics WITHIN the hidden
# subtask tree `progress/subtasks/<parent>/<status>/`. Subtasks do NOT consume the
# issue-id integer stream — ids are <PARENT>-sM — and they live OFF the main board so
# the PM's backlog stays pristine. The parent stays on the main board and advances to
# qa_complete only when every subtask reaches qa_complete or is declined with its reason:
# move-issue.sh and finish-pr.sh refuse it otherwise, and archive.sh refuses to retire an open slice. Commits carry the seat's tag:
# SUBTASK_ROLE for `new`, --role for `move` (both default Orchestrator).
#
# This shares the SAME machinery as move-issue.sh / finish-pr.sh:
# scripts/lib/kanban-worktree.sh. Every git op (create / git mv / Activity append /
# commit / push) happens inside the standing detached `.kanban-wt/` worktree pinned
# to the trunk — the operator's checkout is NEVER switched and any working-tree
# state is irrelevant.
#
# Usage:
#   ./scripts/subtask.sh new <PARENT-ID> <suffix> <slug> --title "..." [--prd @PRD_PREFIX@-NNN] [--stories a,b] [--plan path] [--size S]
#       → creates progress/subtasks/<PARENT-ID>/todo/<PARENT-ID>-<suffix>-<slug>.md
#         from .claude/templates/SUBTASK.template.md, fills frontmatter (prd: the parent's
#         unless --prd is given), commits as SUBTASK_ROLE.
#   ./scripts/subtask.sh move <PARENT-ID>-<suffix> <target> [--role <R>] [--note "..."] [--discard-dirty]
#       → git mv within the subtask tree + append Activity + commit "[ROLE] <id> → <target>: NOTE".
#
#   <R> = @ROLE_SET@
#
# Target folders: todo | in_progress | dev_complete | qa_complete | blocked | declined
# (declined closes a slice that will not be done; it needs --note, the reason being the record)
#
#   SUBTASK_ROLE   the seat this script commits as (default: Orchestrator). The tag
#                  is CHECKED against your declared role set before anything moves.
#                  Read by the `new` arm; the `move` arm takes an explicit `--role` instead
#                  and defaults to Orchestrator without consulting this variable.
#
# --discard-dirty: if the kanban worktree has uncommitted tracked changes, discard
#   them instead of aborting the sync. Read move-issue.sh's warning about it first:
#   the worktree is shared between lanes. (There is deliberately no --no-commit:
#   uncommitted work there blocks every later board operation.)
#
# Examples:
#   ./scripts/subtask.sh new <PREFIX>-014 s1 anchor-resolver --title "Floor: anchor resolution"
#   ./scripts/subtask.sh move <PREFIX>-014-s1 in_progress --role Dev --note "Pickup."
#   ./scripts/subtask.sh move <PREFIX>-014-s1 dev_complete --role Dev --note "Ready for review; gates green."
#
#   The `--role` value above IS AN EXAMPLE VALUE: this tree accepts the set rendered at `<R> =`,
#   from ROLE_PREFIXES in scripts/githooks/commit-msg. Substitute one of yours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/kanban-worktree.sh
. "$SCRIPT_DIR/lib/kanban-worktree.sh"

# GUARDED: usage() renders the role set through this library, and a usage request must
# succeed (issue-creation.md § 3). The operational path fails loudly without it.
# shellcheck source=lib/role-set.sh
[ -r "$SCRIPT_DIR/lib/role-set.sh" ] && . "$SCRIPT_DIR/lib/role-set.sh"

# ── A USAGE REQUEST IS ANSWERED BEFORE THE SEAM IS SOURCED ─────────────────────
# (process/contracts/issue-creation.md § 3: a usage request always succeeds), in any position,
# before any argument is interpreted. usage() reads the seam itself, guarded, to render the
# prefix: its absence must not turn a usage request into a refusal.
# shellcheck source=lib/usage.sh
. "$SCRIPT_DIR/lib/usage.sh"

usage() {   # the path is an ARGUMENT — see lib/usage.sh
  local roles prd
  if command -v kit_role_display >/dev/null 2>&1; then
    roles="$(kit_role_display "$SCRIPT_DIR/.." || true)"
  fi
  # EVERY DEGRADATION NAMES THE SEAM, never the shipped set: a guess that is right about the kit
  # and wrong about this project is the defect being removed, not a fallback from it.
  [ -n "${roles:-}" ] \
    || roles='as declared in scripts/githooks/commit-msg (ROLE_PREFIXES) — scripts/lib/role-set.sh is absent, so not listed'
  # The prefix is RENDERED, never typed: a literal in the help window is a second copy of the
  # seam value. With the seam absent, name it rather than print the kit's placeholder. `:-`
  # because `set -u` would otherwise turn a usage request into an abort.
  [ -f "$SCRIPT_DIR/config.sh" ] && . "$SCRIPT_DIR/config.sh" || true
  prd="${PRD_PREFIX:-}"
  [ -n "$prd" ] || prd='<PRD_PREFIX from scripts/config.sh>'
  # SUBSTITUTED BY POSITION, in ONE left-to-right pass: `sed` and gsub would interpret `|`, `&`
  # and backslashes in the values, and a pass per token would re-scan a value the previous pass
  # emitted. `out` is finished text; only `rest` is searched.
  # Never spell a role-set alternation in a comment: the self-test reads it as a stray seam copy.
  kit_usage "${BASH_SOURCE[0]}" \
    | ROLE_SET_DISPLAY="$roles" PRD_PREFIX_DISPLAY="$prd" awk '
    { out = ""; rest = $0
      while (1) {
        ir = index(rest, "@ROLE_SET@"); ip = index(rest, "@PRD_PREFIX@")
        if (ir == 0 && ip == 0) break
        if (ip == 0 || (ir != 0 && ir < ip)) { i = ir; t = "@ROLE_SET@";   v = ENVIRON["ROLE_SET_DISPLAY"] }
        else                                 { i = ip; t = "@PRD_PREFIX@"; v = ENVIRON["PRD_PREFIX_DISPLAY"] }
        out = out substr(rest, 1, i-1) v
        rest = substr(rest, i + length(t)) }
      print out rest }'
}

for _a in "$@"; do case "$_a" in -h|--help) usage; exit 0 ;; esac; done

# config.sh is loaded HERE for its SHARED VALIDATORS, not for a prefix — no OPERATION below
# mints one (`--prd` is carried through opaque), so the "THE PREFIX HAS ONE AUTHORITY" block
# is not copied here. It is the configuration SEAM, so a missing file still gets a named
# cause (process/contracts/config-seam.md), in the same shape as the other seam readers.
# The `|| ! . "$CONFIG"` half is kept for that consistency only: under `set -e` an
# unsourceable seam aborts inside the `.`, before this refusal can print.
# shellcheck source=config.sh
CONFIG="$SCRIPT_DIR/config.sh"
if [ ! -f "$CONFIG" ] || ! . "$CONFIG"; then
  {
    echo "Error: scripts/config.sh is missing."
    echo "       Looked for: $CONFIG"
    echo "       It is the configuration SEAM, and this script sources it for the shared"
    echo "       validators (process/contracts/config-seam.md). It reads no prefix from it,"
    echo "       so there is nothing to guess and nothing to fall back to."
    echo "       Restore it (git checkout -- scripts/config.sh) — the way back on a tree"
    echo "       that HAD it. ON A FRESH REPO, initialize the kit instead (it refuses one"
    echo "       that has already lived):"
    echo "         ./scripts/kit-init.sh --prefix <P> --trunk <trunk>"
    echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)"
  } >&2
  exit 1
fi

# Loaded below the usage arm: a usage request must not depend on it.
CARDLIB="$SCRIPT_DIR/lib/card-head.sh"
if [ ! -f "$CARDLIB" ] || ! . "$CARDLIB"; then
  echo "Error: scripts/lib/card-head.sh is missing — it strips the" >&2
  echo "       template's KIT-CLASS marker and writes the live-card head in its place." >&2
  echo "       Restore it (git checkout -- scripts/lib/card-head.sh)." >&2
  echo "       (This check sees ABSENCE only — an unsourceable file aborts before this message.)" >&2
  exit 1
fi

# The subtask lifecycle. done/ is deliberately absent: a subtask tree reaches its
# terminal home under progress/done/subtasks/<parent>/ via archive.sh's sweep,
# once its PARENT lands — never by a direct move here.
STATUSES=(todo in_progress dev_complete qa_complete blocked declined)

# A leading '-' is never a name (process/contracts/issue-creation.md § 3). Guard
# every POSITIONAL, not just the first — `subtask.sh new --bogus s1 slug` would
# otherwise mint a child whose parent is "--bogus".
no_dash() {  # <value> <what it should have been>
  case "$1" in
    -*) echo "Error: '$1' is not a <$2> — a leading '-' is never a name." >&2; usage >&2; exit 2 ;;
  esac
}

[ $# -lt 1 ] && { usage >&2; exit 1; }
CMD="$1"; shift

# need_val — refuse an option whose value is missing: exit 2, naming it (issue-creation.md § 3).
need_val() {
  [ "$#" -ge 2 ] || { echo "Error: $1 requires a value." >&2; exit 2; }
}

case "$CMD" in
  new)
    [ $# -lt 3 ] && { usage >&2; exit 1; }
    no_dash "$1" "PARENT-ID"; no_dash "$2" "suffix"; no_dash "$3" "slug"
    PARENT="$1"; SUFFIX="$2"; SLUG="$3"; shift 3
    TITLE=""; PRD=""; STORIES="[<the parent's story ids this slice covers>]"; PLAN=""; SIZE="S"
    while [ $# -gt 0 ]; do case "$1" in
      --title) need_val "$@"; TITLE="$2"; shift 2 ;;
      --prd) need_val "$@"; PRD="$2"; shift 2 ;;
      --stories) need_val "$@"; STORIES="[$2]"; shift 2 ;;
      --plan) need_val "$@"; PLAN="$2"; shift 2 ;;
      --size) need_val "$@"; SIZE="$2"; shift 2 ;;
      --discard-dirty) KWT_DISCARD_DIRTY=true; shift ;;
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    [ -z "$TITLE" ] && { echo "Error: --title required." >&2; exit 1; }

    # THE SEAT THIS ARM ACTS AS: [Orchestrator], the decomposer. A knob, never derived, and
    # validated before anything moves.
    ROLE="${SUBTASK_ROLE:-Orchestrator}"
    kit_require_role "$SCRIPT_DIR/.." "$ROLE" SUBTASK_ROLE || exit 1

    # THE SLUG IS A GIT REF: it becomes `branch: feature/<ID>-<SLUG>` in the published card,
    # and one git cannot check out burns the id (issue-creation.md § 5; validate_slug in
    # scripts/config.sh — one shape, one site).
    validate_slug "$SLUG" || exit 2
    # The suffix is validated too, and NARROWER than a slug: the `move` arm recovers the parent
    # with ${ID%-s*}, so a suffix that is not s<digits> resolves to the wrong parent.
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

    # THE PARENT IS AN ISSUE, NEVER A SUBTASK: the move arm recovers a parent with ${ID%-s*}.
    case "${PARENT##*-s}" in
      "$PARENT"|''|*[!0-9]*) ;;
      *) echo "Error: '$PARENT' is a subtask id — decompose its parent instead. NOTHING WAS CHANGED." >&2; exit 2 ;;
    esac

    # Acquire the lock + bootstrap + sync the worktree BEFORE touching anything,
    # so the create lands on the current <remote>/<trunk> tip.
    kwt_resolve
    kwt_lock
    kwt_bootstrap
    kwt_sync

    TEMPLATE="$KWT/.claude/templates/SUBTASK.template.md"
    [ -f "$TEMPLATE" ] || { echo "Error: template not found at ${TEMPLATE#"$KWT"/}." >&2; exit 1; }

    # THE PARENT MUST EXIST (issue-creation.md § 3): creation here publishes, so an orphan would
    # reach the trunk. Searched on the published board ($KWT), the surface the mover reads.
    # Depth 2 is progress/<column>/<card>: a subtask tree without its parent card is no parent.
    # Captured whole, then cut: `| head -1` would SIGPIPE the producer under `pipefail`.
    PARENT_CARD="$(find "$KWT/progress" -maxdepth 2 -type f -name "${PARENT}-*.md" 2>/dev/null || true)"
    PARENT_CARD="${PARENT_CARD%%$'\n'*}"
    if [ -z "$PARENT_CARD" ]; then
      {
        echo "Error: parent '${PARENT}' does not exist on the published board — refusing to create an orphan."
        echo "  Looked for progress/<column>/${PARENT}-*.md in the trunk-pinned kanban worktree."
        echo "  If you have just created ${PARENT}, PUBLISH IT FIRST: the board mover and this"
        echo "  script both read the published board, so an unpushed card is invisible to both."
      } >&2
      exit 1
    fi
    # A retired parent takes no new work: archive.sh sweeps a done/ parent's tree, todo cards and all.
    case "$(basename "$(dirname "$PARENT_CARD")")" in
      done|declined)
        echo "Error: parent '${PARENT}' is in progress/$(basename "$(dirname "$PARENT_CARD")")/ — a retired issue takes no new subtasks. Open a new issue." >&2
        exit 1 ;;
    esac

    # prd: INHERITED from the parent unless --prd was given; a parent with none, or with its
    # template placeholder, gives n/a.
    if [ -z "$PRD" ]; then
      PRD="$(awk '/^---$/{n++; next} n==1 && /^prd:/{sub(/^prd:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); print; exit}' "$PARENT_CARD")"
      case "$PRD" in ''|*-NNN) PRD="n/a" ;; esac
    fi

    ID="${PARENT}-${SUFFIX}"
    SLUGFILE="${ID}-${SLUG}.md"
    DEST_DIR="$KWT/progress/subtasks/${PARENT}/todo"
    mkdir -p "$DEST_DIR"
    DEST="$DEST_DIR/$SLUGFILE"
    [ -e "$DEST" ] && { echo "Error: ${DEST#"$KWT"/} already exists." >&2; exit 1; }
    TODAY=$(date +%Y-%m-%d)
    BRANCH="feature/${ID}-${SLUG}"

    # BUILT BESIDE THE DESTINATION, PUBLISHED BEFORE THE COMMIT (lib/card-head.sh): a failed step
    # leaves the shared worktree clean. The trap keeps kwt_lock's own EXIT action, kwt_unlock.
    WORK="$(kit_card_work "$DEST_DIR")"
    trap 'rm -f "$WORK" "$WORK.h1" "$WORK.plan" "$WORK.rehead" "$WORK.stamp" "$WORK.fill"; kwt_unlock' EXIT

    # Fill the template (frontmatter + heading + Activity). Every substitution
    # keys on the frontmatter KEY, never on the template's placeholder VALUE, so
    # a template edit cannot make one a silent no-op. This `sed` has no -i, so it
    # is portable (reads TEMPLATE, writes WORK).
    # EVERY INTERPOLATED VALUE GOES THROUGH sed_repl (scripts/config.sh): `&` and the
    # delimiter are live in a sed replacement.
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
        "$TEMPLATE" > "$WORK"

    # The H1. Done as a FIRST-MATCH-ONLY pass rather than a sed pattern: a
    # `s|^# .* — .*|…|` would rewrite every em-dashed heading in the body, not
    # just the title. The H1 is the first `^# ` line after the frontmatter.
    # ENVIRON, NOT `awk -v`: -v processes escape sequences, so a backslash in a title would
    # become a TAB or a NEWLINE. Not perl either: it is past the kit's git-plus-POSIX-shell floor.
    H1="# ${ID} — ${TITLE}" awk 'BEGIN{done=0} done==0 && /^# /{print ENVIRON["H1"]; done=1; next} {print}' \
      "$WORK" > "$WORK.h1" && mv "$WORK.h1" "$WORK" || exit 1

    # RE-HEAD THE CARD (process/EXTRACTION.md § The marker and graduation): the KIT-CLASS
    # marker goes, its still-in-force FILL instruction stays.
    kit_rehead_card "$WORK" || exit 1
    # The seed entry's date, and the parent and slice the body names (lib/card-head.sh).
    kit_stamp_card "$WORK" "$ID" "$TODAY" || exit 1
    kit_fill_card "$WORK" "<PREFIX>-NNN" "$PARENT" "${PARENT%-*}-NNN" "$PARENT" \
      "decomposition slice M." "decomposition slice ${SUFFIX}." \
      "<parent card>" "$(basename "$PARENT_CARD")" || exit 1


    # Optional --plan. Keyed on the KEY, never on the template's placeholder VALUE, which
    # would silently no-op when the template's example path changes. Three shapes: the
    # `- Plan: …` bullet, a frontmatter `plan:` key, and a bare `<plan-path>` token.
    # awk + ENVIRON (not perl: the floor). `<plan-path>` is replaced by index/substr, because
    # `&` and a backslash are live in gsub's replacement.
    if [ -n "$PLAN" ]; then
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
      ' "$WORK" > "$WORK.plan" && mv "$WORK.plan" "$WORK" || exit 1
    fi

    kit_publish_card "$WORK" "$DEST" || exit 1

    git -C "$KWT" add "$DEST"
    MSG="[$ROLE] ${ID} created under ${PARENT} — decomposition slice (via subtask.sh)"
    git -C "$KWT" commit -m "$MSG" --quiet
    echo "Created: ${DEST#"$KWT"/}  (branch: ${BRANCH})"
    LOCAL_SHA="$(git -C "$KWT" rev-parse --short HEAD)"
    echo "Commit:  ${LOCAL_SHA} — made locally in the kanban worktree, NOT yet published."
    # THE RETURN IS CHECKED: a failed push must not exit 0 while the card is only a local
    # commit in the kanban worktree.
    FINALIZE_RC=0
    kwt_finalize || FINALIZE_RC=$?
    if [ -n "${KWT_LANDED_SHA:-}" ]; then
      echo "Published: ${KWT_LANDED_SHA} on ${DEFAULT_BRANCH}"
    else
      {
        echo "NOT PUBLISHED: ${LOCAL_SHA} is local only — see the push error above."
        echo "  Every later board operation REFUSES until you publish it (commands above)."
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
      -*) echo "Error: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac; done
    case "$TARGET" in todo|in_progress|dev_complete|qa_complete|blocked|declined) ;; *) echo "Error: bad target '$TARGET' (one of: ${STATUSES[*]})." >&2; exit 1 ;; esac
    [ "$TARGET" != declined ] || [ -n "$NOTE" ] \
      || { echo "Error: declined needs --note \"why\" — the reason is the whole record of a slice that will not be done." >&2; exit 1; }
    # THE ROLE IS VALIDATED HERE, BEFORE ANY MUTATION: a role the commit-msg hook rejects
    # would fail mid-operation, leaving the git mv and the Activity entry uncommitted in the
    # shared kanban worktree. Refusing here costs a re-run; at the hook, a reconciliation.
    # Derived by lib/role-set.sh kit_role_resolve; this literal is only its stamped default (see there).
    ROLE_SET_DEFAULT='PM|Dev|QA|Refactorer|UIDesigner|Orchestrator|Architect'
    if command -v kit_role_resolve >/dev/null 2>&1; then
      kit_role_resolve "$SCRIPT_DIR/.." "$ROLE_SET_DEFAULT"
    else
      KIT_ROLE_SET="$ROLE_SET_DEFAULT"
      KIT_ROLE_SRC="THE KIT'S FALLBACK SET — scripts/lib/role-set.sh is absent, so this project's declared set could not be read"
      KIT_ROLE_DEFAULTED=1
    fi
    # NAMED, NOT SILENT, AND BEFORE ANYTHING IS ENFORCED: otherwise an acceptance or a refusal
    # reads as being about this project's declared set when it is not.
    [ -z "${KIT_ROLE_DEFAULTED:-}" ] \
      || echo "Note: --role is being checked against $KIT_ROLE_SRC" >&2
    if [ -z "$ROLE" ]; then
      echo "Error: --role cannot be empty ($KIT_ROLE_SET)." >&2; exit 1
    fi
    if ! kit_role_member "$KIT_ROLE_SET" "$ROLE"; then
      { echo "Error: --role must be $KIT_ROLE_SET (got '$ROLE')."
        echo "       That set is $KIT_ROLE_SRC."
      } >&2
      exit 1
    fi
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
    # THE RETURN IS CHECKED — same reason as the `new` arm above.
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

  -*) echo "Error: unknown option: $CMD (expected the command 'new' or 'move')" >&2; usage >&2; exit 2 ;;
  *) echo "Unknown command: $CMD" >&2; usage >&2; exit 1 ;;
esac
